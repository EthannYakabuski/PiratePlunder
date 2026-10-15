extends Node
## Adapter for upstream GodotPlayGameServices 3.4.0, with a complete offline mode.
## Every remote mutation is idempotent: total achievement steps, best scores, and
## a monotonic merged snapshot. Public backend IDs are configured separately.

signal status_changed(message: String)
signal signed_in_changed(is_signed_in: bool)
signal cloud_synced

const SignInClient = preload("res://addons/GodotPlayGameServices/scripts/sign_in/sign_in_client.gd")
const AchievementsClient = preload("res://addons/GodotPlayGameServices/scripts/achievements/achievements_client.gd")
const LeaderboardsClient = preload("res://addons/GodotPlayGameServices/scripts/leaderboards/leaderboards_client.gd")
const SnapshotsClient = preload("res://addons/GodotPlayGameServices/scripts/snapshots/snapshots_client.gd")
const CLOUD_TIMEOUT := 25.0

var config: Dictionary = {}
var status := "Offline voyages — progress saved on this device"
var available := false
var signed_in := false
var _sign_in: Node
var _achievements: Node
var _leaderboards: Node
var _snapshots: Node
var _cloud_loaded := false
var _cloud_busy := false
var _cloud_conflict := false
var _cloud_timeout := 0.0
var _sync_delay := -1.0
var _retry_timer := 60.0
var _score_in_flight: Dictionary = {}
var _applying_cloud := false

func _ready() -> void:
	if FileAccess.file_exists("res://config/play_games.json"):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://config/play_games.json"))
		if parsed is Dictionary:
			config = parsed
	Progression.changed.connect(_on_progress_changed)
	if OS.get_name() != "Android" or not config.get("enabled", true) or not Engine.has_singleton("GodotPlayGameServices"):
		return
	var plugin: Node = get_node_or_null("/root/GodotPlayGameServices")
	if plugin == null or plugin.initialize() != 0:
		_set_status("Play Games unavailable — local progress is safe")
		return
	available = true
	_sign_in = SignInClient.new()
	_achievements = AchievementsClient.new()
	_leaderboards = LeaderboardsClient.new()
	_snapshots = SnapshotsClient.new()
	_sign_in.user_authenticated.connect(_on_authenticated)
	_achievements.achievement_unlocked.connect(_on_achievement_acknowledged)
	_leaderboards.score_submitted.connect(_on_score_acknowledged)
	_snapshots.game_loaded.connect(_on_game_loaded)
	_snapshots.game_saved.connect(_on_game_saved)
	_snapshots.conflict_emitted.connect(_on_cloud_conflict)
	for client in [_sign_in, _achievements, _leaderboards, _snapshots]:
		add_child(client)
	_set_status("Connect Play Games to sync your voyages")
	if config.get("auto_sign_in", false):
		_sign_in.is_authenticated()

func _process(delta: float) -> void:
	if _sync_delay >= 0.0:
		_sync_delay -= delta
		if _sync_delay < 0.0 and signed_in:
			sync_cloud()
	if _cloud_busy:
		_cloud_timeout -= delta
		if _cloud_timeout <= 0.0:
			_cloud_busy = false
			_set_status("Cloud connection timed out — local progress is safe")
	if signed_in:
		_retry_timer -= delta
		if _retry_timer <= 0.0:
			_retry_timer = 60.0
			_score_in_flight.clear()
			flush_queues()
			if not _cloud_busy and not _cloud_conflict:
				sync_cloud()

func _set_status(message: String) -> void:
	status = message
	status_changed.emit(status)

func sign_in() -> void:
	if not available:
		_set_status("Play Games works in the Android build; your local voyage is saved")
		return
	_set_status("Connecting to Play Games…")
	_sign_in.sign_in()

func _on_authenticated(authenticated: bool) -> void:
	signed_in = authenticated
	signed_in_changed.emit(authenticated)
	if not authenticated:
		_cloud_loaded = false
		_set_status("Play Games could not connect — continue sailing offline")
		return
	_set_status("Play Games connected")
	_cloud_conflict = false
	_rebuild_queues()
	flush_queues()
	sync_cloud()

func _on_progress_changed() -> void:
	_rebuild_queues()
	if signed_in and not _applying_cloud:
		_sync_delay = 3.0

func _backend_id(kind: String, definition: Dictionary) -> String:
	var mappings: Dictionary = config.get(kind + "_ids", {})
	return str(mappings.get(definition.id, definition.get("google_play_id", "")))

func _rebuild_queues() -> void:
	if Progression.data.is_empty():
		return
	var queue: Dictionary = Progression.data.services.achievement_queue
	for definition in Progression.achievements:
		var current := int(minf(Progression.metric(str(definition.metric)), float(definition.target)))
		if current > 0 and (definition.get("incremental", false) or current >= int(definition.target)):
			queue[definition.id] = maxi(current, int(queue.get(definition.id, 0)))
	var scores: Dictionary = Progression.data.services.score_queue
	for definition in Progression.leaderboards:
		var score := int(Progression.metric(str(definition.metric)) * float(definition.get("value_multiplier", 1)))
		if score > 0:
			scores[definition.id] = maxi(score, int(scores.get(definition.id, 0)))
	Progression.save_data()

func flush_queues() -> void:
	if not available or not signed_in:
		return
	var queue: Dictionary = Progression.data.services.achievement_queue
	for definition in Progression.achievements:
		var id := _backend_id("achievement", definition)
		if id.is_empty() or not queue.has(definition.id):
			continue
		if definition.get("incremental", false):
			# Total steps are safe to resend after disconnects; increments are not.
			_achievements.set_achievement_steps(id, int(queue[definition.id]))
		else:
			_achievements.unlock_achievement(id)
	var scores: Dictionary = Progression.data.services.score_queue
	for definition in Progression.leaderboards:
		var id := _backend_id("leaderboard", definition)
		if id.is_empty() or not scores.has(definition.id) or _score_in_flight.has(id):
			continue
		_score_in_flight[id] = {"key": definition.id, "score": int(scores[definition.id])}
		_leaderboards.submit_score(id, int(scores[definition.id]))

func _on_achievement_acknowledged(unlocked: bool, backend_id: String) -> void:
	# Upstream reports false for both partial incremental progress and errors.
	# Retain those totals and safely resend at the next reconnect.
	if not unlocked:
		return
	for definition in Progression.achievements:
		if _backend_id("achievement", definition) == backend_id:
			Progression.data.services.achievement_queue.erase(definition.id)
	Progression.save_data()

func _on_score_acknowledged(submitted: bool, backend_id: String) -> void:
	var flight: Dictionary = _score_in_flight.get(backend_id, {})
	_score_in_flight.erase(backend_id)
	if not submitted or flight.is_empty():
		return
	var queue: Dictionary = Progression.data.services.score_queue
	if int(queue.get(flight.key, 0)) <= int(flight.score):
		queue.erase(flight.key)
	Progression.save_data()

func show_achievements() -> bool:
	if not signed_in:
		_set_status("Local achievements are ready; connect Play Games for your profile")
		return false
	_achievements.show_achievements()
	return true

func show_leaderboards(id: String = "") -> bool:
	if not signed_in:
		_set_status("Personal records are saved; connect Play Games for global boards")
		return false
	if id.is_empty():
		_leaderboards.show_all_leaderboards()
		return true
	for definition in Progression.leaderboards:
		if definition.id == id:
			var backend_id := _backend_id("leaderboard", definition)
			if not backend_id.is_empty():
				_leaderboards.show_leaderboard(backend_id)
				return true
	_set_status("This leaderboard needs its Play Console ID")
	return false

func sync_cloud() -> void:
	if not signed_in or not config.get("saved_games_enabled", true) or _cloud_busy or _cloud_conflict:
		return
	flush_queues()
	_cloud_busy = true
	_cloud_timeout = CLOUD_TIMEOUT
	_set_status("Syncing your voyage…")
	# Fetch before EVERY upload so another device's latest progress is preserved.
	_snapshots.load_game(str(config.get("snapshot_name", "pirateplunder_progress_v2")), false)

func _upload_cloud() -> void:
	var payload := JSON.stringify(Progression.export_cloud()).to_utf8_buffer()
	_snapshots.save_game(str(config.get("snapshot_name", "pirateplunder_progress_v2")), "PiratePlunder: %d stars, %d gold" % [int(Progression.metric("campaign_stars")), Progression.gold()], payload, int(Progression.metric("seconds_played") * 1000.0), int(Progression.metric("campaign_stars")))

func _on_game_loaded(snapshot: Variant) -> void:
	if snapshot != null:
		var decoded: Variant = JSON.parse_string(snapshot.content.get_string_from_utf8())
		_applying_cloud = true
		var merged: bool = decoded is Dictionary and Progression.merge_cloud(decoded)
		_applying_cloud = false
		if not merged:
			_cloud_busy = false
			_set_status("Cloud save needs a compatible version — local progress is safe")
			return
	_cloud_loaded = true
	_cloud_timeout = CLOUD_TIMEOUT
	_upload_cloud()

func _on_game_saved(saved: bool, _name: String, _description: String) -> void:
	_cloud_busy = false
	if saved:
		_set_status("Voyage synced with Play Games")
		cloud_synced.emit()
	else:
		_set_status("Cloud save will retry — local progress is safe")

func _on_cloud_conflict(conflict: Variant) -> void:
	# v3.4.0 exposes conflict data but does not expose resolveConflict in its
	# native bridge. Preserve BOTH snapshots locally and stop retry loops. See docs.
	for snapshot in [conflict.server_snapshot, conflict.conflicting_snapshot]:
		if snapshot != null:
			var decoded: Variant = JSON.parse_string(snapshot.content.get_string_from_utf8())
			if decoded is Dictionary:
				_applying_cloud = true
				Progression.merge_cloud(decoded)
				_applying_cloud = false
	_cloud_conflict = true
	_cloud_busy = false
	_set_status("Cloud conflict: both voyages preserved locally; reconnect later")
