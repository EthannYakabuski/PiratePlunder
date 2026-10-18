extends SceneTree
## Offline integration coverage for death interruption, opt-in rewarded rescue,
## exactly-once progression/cadence, home banners and application lifecycle.
## Run after vendor imports: godot --headless --path . --script res://tests/test_ad_flow.gd --log-file <absolute tests/ad-flow.log>.
## All presentations use MockAds. Player saves and real advertising SDKs are not used.

class MockAds extends Node:
	signal availability_changed
	signal banner_space_changed(height: float)
	signal fullscreen_started(kind: String)
	signal fullscreen_finished(kind: String)

	var rewarded_ready := true
	var reward_show_accept := true
	var interstitial_ready := true
	var interstitial_show_accept := true
	var privacy_required := false
	var home_banner_visible := false
	var logical_banner_height := 60.0
	var consent_requests := 0
	var privacy_requests := 0
	var reward_requests := 0
	var completed_runs := 0
	var interstitial_requests := 0
	var interstitial_shows := 0
	var due := false
	var reward_callback: Callable
	var interstitial_callback: Callable
	var banner_history: Array[bool] = []

	func request_consent() -> void:
		consent_requests += 1

	func set_home_banner_visible(value: bool) -> void:
		home_banner_visible = value
		banner_history.append(value)

	func banner_reserved_height() -> float:
		return logical_banner_height if home_banner_visible else 0.0

	func is_rewarded_ready() -> bool:
		return rewarded_ready

	func show_rewarded_continue(completion: Callable) -> bool:
		reward_requests += 1
		if not rewarded_ready or not reward_show_accept:
			return false
		reward_callback = completion
		fullscreen_started.emit("rewarded")
		return true

	func record_completed_run() -> bool:
		# The real Ads service owns cadence policy tests. Here the counter exposes
		# how many finalized-run events the actual main scene forwards.
		completed_runs += 1
		due = completed_runs % 3 == 0
		return due

	func show_interstitial_if_due(completion: Callable) -> bool:
		interstitial_requests += 1
		if not due or not interstitial_ready or not interstitial_show_accept:
			return false
		due = false
		interstitial_shows += 1
		interstitial_callback = completion
		fullscreen_started.emit("interstitial")
		return true

	func privacy_options_required() -> bool:
		return privacy_required

	func show_privacy_options() -> bool:
		privacy_requests += 1
		return privacy_required

	func close_reward_surface() -> void:
		# Services emits this before the terminal callback. It must not resume a
		# still-pending voyage during that gap.
		fullscreen_finished.emit("rewarded")

	func deliver_reward(granted: bool) -> void:
		var callback := reward_callback
		reward_callback = Callable()
		if callback.is_valid():
			callback.call(granted)

	func close_interstitial() -> void:
		fullscreen_finished.emit("interstitial")
		var callback := interstitial_callback
		interstitial_callback = Callable()
		if callback.is_valid():
			callback.call()

var MainScript: GDScript
var ArenaScript: GDScript
var campaign: Dictionary = {}
var checks := 0
var failures: Array[String] = []
var fixture_number := 0
const SAVE_PATH := "res://tests/output/.ad-flow-save.json"

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		printerr("FAIL: " + label)

func _profile():
	return root.get_node("Progression")

func _reset_profile() -> void:
	fixture_number += 1
	var profile = _profile()
	profile.save_path = SAVE_PATH
	profile.reset_data("ad-flow-%d" % fixture_number)
	profile.settings.music = false
	profile.settings.sfx = false
	profile.settings.auto_fire = false
	profile.settings.haptics = false

func _main_fixture(ready: bool = true, capture: bool = false) -> Dictionary:
	_reset_profile()
	var mock := MockAds.new()
	mock.rewarded_ready = ready
	root.add_child(mock)
	var game = MainScript.new()
	game.ads_service = mock
	if capture:
		game.capture_mode = "test_preview"
	root.add_child(game)
	game.set_process(false)
	return {"game":game,"ads":mock}

func _dispose_fixture(fixture: Dictionary) -> void:
	var game = fixture.game
	root.remove_child(game)
	game.free()
	var mock = fixture.ads
	root.remove_child(mock)
	mock.free()

func _start(game, level_id: int = 13) -> void:
	game.selected_mode = "campaign"
	game.selected_level = level_id
	game.selected_ship = 2
	game.start_run()
	game.arena.set_process(false)
	game.arena.muted = true
	game.arena.reduced_motion = true

func _arena(level_id: int = 13):
	var a = ArenaScript.new()
	root.add_child(a)
	var profile = _profile()
	var stage: Dictionary = campaign.levels[level_id-1]
	var biome: Dictionary = campaign.biomes[0]
	for definition in campaign.biomes:
		if definition.id == stage.biome:
			biome = definition
	a.start_run(profile.ship_loadout("redwake"),stage,biome,"campaign")
	a.set_process(false)
	a.muted = true
	return a

func _dispose_arena(a) -> void:
	root.remove_child(a)
	a.free()

func _state(a) -> Dictionary:
	var state := {}
	for key in ["player","heading","desired_heading","elapsed","score","kills","bosses","treasure","shots","powerups","damage_taken","combo","best_combo","combo_time","cooldowns","secondary_cooldowns","shield_time","rapid_time","spawn_clock","boss_clock","boss_spawned","wave_index","supply_clock","peak_entities","enemies","bullets","pickups","particles","hazards","authored_islands","island_cache","campaign_encounters","campaign_bounds","campaign_total_ships","campaign_deployed_count","encounter_index","encounter_wait","current_encounter_name","ship","level","biome","voyage_seed","chunk_size","biome_index"]:
		var value: Variant = a.get(key)
		state[key] = value.duplicate(true) if value is Dictionary or value is Array else value
	state.rng_state = a.rng.state
	state.navigation_identity = a.navigation.get_instance_id()
	return state

func _seed_progress(a) -> void:
	a.elapsed = 37.25
	a.score = 1630
	a.treasure = 7
	a.shots = 23
	a.powerups = 2
	a.damage_taken = 83.0
	a.best_combo = 6
	a.combo = 3
	a.combo_time = 2.4
	a.cooldowns = [0.35,0.7]
	a.secondary_cooldowns = [1.2,0.8]
	a.rapid_time = 4.5
	a.shield_time = 0.0
	a.enemies[0].hp -= 11.0
	a._bullet(a.player + Vector2(100,0),Vector2(80,10),7.0,false)
	a.fire_pointers[11] = 0
	a.secondary_pointers[12] = 1
	a.wheel_pointer = 10

func _die(a) -> void:
	a.hp = 0.0
	a.invincible_time = 0.0
	a._request_defeat()

func _buttons(node: Node) -> Array[Button]:
	var result: Array[Button] = []
	if node is Button:
		result.append(node)
	for child in node.get_children():
		result.append_array(_buttons(child))
	return result

func _find_button(game, text_fragment: String) -> Button:
	for button in _buttons(game.ui):
		if text_fragment.to_lower() in button.text.to_lower():
			return button
	return null

func _standalone_contract() -> void:
	_reset_profile()
	var a = _arena()
	var outputs: Array = []
	var interruptions: Array = []
	a.finished.connect(func(summary: Dictionary): outputs.append(summary))
	a.defeated.connect(func(): interruptions.append(true))
	_check(not a.allow_rewarded_continue,"standalone arena defaults to ordinary defeat without Ads")
	_die(a)
	_check(outputs.size() == 1 and not outputs[0].won and interruptions.is_empty(),"unavailable standalone death finalizes normally")
	_dispose_arena(a)

	a = _arena()
	outputs.clear()
	interruptions.clear()
	a.finished.connect(func(summary: Dictionary): outputs.append(summary))
	a.defeated.connect(func(): interruptions.append(true))
	a.allow_rewarded_continue = true
	_seed_progress(a)
	_die(a)
	_check(a.running and a.paused and a.defeat_pending,"eligible death interrupts and freezes the current voyage")
	_check(outputs.is_empty() and interruptions.size() == 1,"pending death emits defeated once without finalizing a result")
	_check(a.fire_pointers.is_empty() and a.secondary_pointers.is_empty() and a.wheel_pointer == -1,"death interruption releases every held input")
	var before := _state(a)
	a.step(2.0)
	_check(_state(a) == before,"pending rewarded decision freezes simulation and all voyage state")
	_check(a.resume_after_reward(),"one earned reward resumes the pending voyage")
	_check(a.hp == a.max_hp and a.invincible_time >= 3.0 and not a.paused and not a.defeat_pending,"rescue restores full hull and a three-second grace window")
	_check(_state(a) == before,"rescue preserves the full score, timers, geometry, enemies, loot, RNG and encounter state")
	_check(a.revives_used == 1,"rescue consumes exactly one per-voyage revive")
	a._damage_player(30.0)
	_check(a.hp == a.max_hp,"revive grace prevents immediate damage from preserved threats")
	a.hp = 17.0
	_check(not a.resume_after_reward() and a.hp == 17.0,"duplicate earned callbacks cannot heal or consume another revive")
	_die(a)
	_check(outputs.size() == 1 and not a.running and interruptions.size() == 1,"second death finalizes once without offering another rescue")
	_check(a.finalize_defeat().is_empty() and outputs.size() == 1,"duplicate defeat finalization is idempotent")
	_dispose_arena(a)

	# Defeat wins the same-frame race against a just-cleared campaign objective.
	a = _arena()
	outputs.clear()
	a.finished.connect(func(summary: Dictionary): outputs.append(summary))
	a.allow_rewarded_continue = true
	a.enemies.clear()
	a.encounter_index = a.campaign_encounters.size()
	a.kills = a.campaign_total_ships
	a.hp = 0
	a.step(0.0)
	_check(a.defeat_pending and outputs.is_empty(),"zero hull cannot fall through into victory on the same simulation frame")
	_dispose_arena(a)

func _success_and_no_double_record() -> void:
	var fixture := _main_fixture()
	var game = fixture.game
	var mock: MockAds = fixture.ads
	_start(game)
	var a = game.arena
	_seed_progress(a)
	var profile_before: Dictionary = _profile().export_cloud()
	_die(a)
	_check(game.screen == "revive" and _find_button(game,"Watch ad") != null,"ready rewarded ad produces a clear opt-in rescue choice")
	_check(mock.reward_requests == 0 and mock.completed_runs == 0 and _profile().metric("runs_started") == 0,"offering rescue neither starts an ad nor records a game")
	var before := _state(a)
	game._resize()
	_check(game.screen == "revive" and a.defeat_pending and mock.reward_requests == 0,"resizing an offer preserves the pending decision")
	game._watch_revive()
	_check(mock.reward_requests == 1 and game.screen == "revive_ad" and a.paused,"only the opt-in starts rewarded presentation with the voyage paused")
	var duplicate := mock.reward_callback
	mock.close_reward_surface()
	_check(a.paused and a.defeat_pending and game.screen == "revive_ad","fullscreen-close signal alone does not resume a still-unresolved reward")
	mock.deliver_reward(true)
	_check(game.screen == "run" and a.running and not a.paused and a.hp == a.max_hp,"earned terminal callback resumes the same full-hull voyage")
	_check(_state(a) == before,"main rescue path preserves full voyage state")
	_check(_profile().export_cloud() == profile_before and mock.completed_runs == 0,"successful rescue grants no duplicate XP, coins, achievements or cadence count")
	a.hp = 23.0
	duplicate.call(true)
	_check(a.hp == 23.0 and a.revives_used == 1,"duplicate terminal callback is ignored by the main scene")
	_die(a)
	_check(game.screen == "result" and not a.running and mock.reward_requests == 1,"second death uses a normal result instead of another rewarded offer")
	_check(_profile().metric("runs_started") == 1 and mock.completed_runs == 1,"the revived voyage is recorded and counted exactly once at its final end")
	var summary: Dictionary = game.last_summary.duplicate(true)
	game._run_finished(summary)
	duplicate.call(false)
	_check(_profile().metric("runs_started") == 1 and mock.completed_runs == 1,"replayed result and late terminal callbacks cannot duplicate progression or cadence")
	_dispose_fixture(fixture)

func _unavailable_and_decline() -> void:
	var fixture := _main_fixture(false)
	var game = fixture.game
	var mock: MockAds = fixture.ads
	_start(game)
	_die(game.arena)
	_check(game.screen == "result" and mock.reward_requests == 0,"no-fill deaths take the ordinary result path without an offer")
	_check(_profile().metric("runs_started") == 1 and mock.completed_runs == 1,"unavailable ad still preserves one ordinary result")
	_dispose_fixture(fixture)

	fixture = _main_fixture(true)
	game = fixture.game
	mock = fixture.ads
	_start(game)
	_die(game.arena)
	game._decline_revive()
	_check(game.screen == "chart" and not game.arena.running and mock.reward_requests == 0,"declining the opt-in returns to the main chart")
	_check(_profile().metric("runs_started") == 1 and mock.completed_runs == 1,"declining records the failed voyage once")
	game._decline_revive()
	game._complete_revive(false)
	_check(_profile().metric("runs_started") == 1 and mock.completed_runs == 1,"repeat decline does not count or pay a second result")
	_dispose_fixture(fixture)

func _reward_failure_and_stale_callbacks() -> void:
	for rejected_before_show in [false,true]:
		var fixture := _main_fixture()
		var game = fixture.game
		var mock: MockAds = fixture.ads
		# A failed reward attempt at the third-game boundary must not immediately
		# stack an interstitial on top of the failed/closed rewarded presentation.
		mock.completed_runs = 2
		_start(game)
		_die(game.arena)
		mock.reward_show_accept = not rejected_before_show
		game._watch_revive()
		if not rejected_before_show:
			mock.close_reward_surface()
			mock.deliver_reward(false)
		await process_frame
		_check(game.screen == "chart" and not game.arena.running,"failed or early-closed reward returns to chart (%s)" % rejected_before_show)
		_check(_profile().metric("runs_started") == 1 and mock.completed_runs == 3,"failed reward counts exactly one finalized voyage (%s)" % rejected_before_show)
		_check(mock.interstitial_shows == 0,"failed reward never stacks another fullscreen immediately (%s)" % rejected_before_show)
		_dispose_fixture(fixture)

	var fixture := _main_fixture()
	var game = fixture.game
	var mock: MockAds = fixture.ads
	_start(game)
	_die(game.arena)
	game._watch_revive()
	var stale := mock.reward_callback
	mock.close_reward_surface()
	_start(game)
	var new_arena = game.arena
	var new_id: String = game._run_id
	stale.call(true)
	stale.call(false)
	_check(game.arena == new_arena and game._run_id == new_id and game.screen == "run","an old ad callback cannot hijack a replacement run")
	_check(new_arena.revives_used == 0 and new_arena.hp == new_arena.max_hp and _profile().metric("runs_started") == 0,"stale callbacks neither grant a free rescue nor finalize the new run")
	_dispose_fixture(fixture)

func _cadence() -> void:
	var fixture := _main_fixture(false)
	var game = fixture.game
	var mock: MockAds = fixture.ads
	# A stopped AudioStreamPlayer reports no paused playback. Start a muted
	# stream so this checks a real playback pause and restoration.
	game.music.volume_db = -80
	game.music.play()
	await process_frame
	for index in 3:
		_start(game)
		_die(game.arena)
		await process_frame
		_check(mock.completed_runs == index+1 and _profile().metric("runs_started") == index+1,"cadence receives one event for finalized game %d" % (index+1))
		_check(mock.interstitial_shows == (1 if index==2 else 0),"interstitial is gated until the third finalized game")
		if index==2:
			_check(game._ads_fullscreen_active and game.music.stream_paused,"third-game fullscreen pauses game audio")
			mock.close_interstitial()
			_check(not game._ads_fullscreen_active and not game.music.stream_paused,"terminal interstitial close restores prior audio pause state")
	_dispose_fixture(fixture)

	# A player declining a ready reward still reaches the normal cadence boundary.
	fixture = _main_fixture(true)
	game = fixture.game
	mock = fixture.ads
	mock.completed_runs = 2
	_start(game)
	_die(game.arena)
	game._decline_revive()
	await process_frame
	_check(game.screen == "chart" and mock.completed_runs == 3 and mock.interstitial_shows == 1,"declining before watch permits the third-game chart-boundary interstitial")
	mock.close_interstitial()
	_dispose_fixture(fixture)

func _lifecycle() -> void:
	var fixture := _main_fixture()
	var game = fixture.game
	var mock: MockAds = fixture.ads
	_start(game)
	mock.fullscreen_started.emit("consent")
	game._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	mock.fullscreen_finished.emit("consent")
	var resume_found := false
	for child in game.ui.get_children():
		if child is Button and child.text == "Keep sailing": resume_found = true
	_check(game.arena.paused and resume_found,"a consent close while backgrounded leaves an explicit resume control rather than a frozen HUD")
	game._notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	_check(game.arena.paused,"returning after backgrounded consent preserves the visible pause decision")
	_dispose_fixture(fixture)

	fixture = _main_fixture()
	game = fixture.game
	mock = fixture.ads
	_start(game)
	_seed_progress(game.arena)
	_die(game.arena)
	game._watch_revive()
	var before := _state(game.arena)
	game._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	_check(game.screen == "revive_ad" and game.arena.defeat_pending,"Android Back cannot orphan a fullscreen rewarded decision")
	game._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	mock.close_reward_surface()
	mock.deliver_reward(true)
	_check(game.arena.hp == game.arena.max_hp and game.arena.paused and game._application_backgrounded,"earned callback cannot unpause gameplay while the application is backgrounded")
	game.arena.step(1.0)
	_check(_state(game.arena) == before,"backgrounded rewarded return preserves frozen voyage progress")
	game._notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	_check(game.arena.paused,"application resume keeps the existing pause until the player is ready")
	game.arena.paused = false
	var elapsed: float = game.arena.elapsed
	game.arena.step(0.05)
	_check(game.arena.elapsed > elapsed,"explicitly resumed gameplay advances after a successful rescue")
	_dispose_fixture(fixture)

	fixture = _main_fixture()
	game = fixture.game
	mock = fixture.ads
	_start(game)
	game._pause()
	mock.fullscreen_started.emit("interstitial")
	mock.fullscreen_finished.emit("interstitial")
	_check(game.arena.paused,"fullscreen lifecycle never clears an existing player pause")
	_dispose_fixture(fixture)

func _home_banner_and_privacy() -> void:
	var fixture := _main_fixture()
	var game = fixture.game
	var mock: MockAds = fixture.ads
	mock.logical_banner_height = 120.0
	game.show_chart()
	await process_frame
	_check(mock.home_banner_visible,"home chart requests its banner")
	var banner_top: float = game.size().y - 120.0
	var levels: Array[Button] = []
	var feet: Array[Button] = []
	for button in _buttons(game.ui):
		var label := button.text.replace(" ★","")
		if label.is_valid_int():
			levels.append(button)
		else:
			feet.append(button)
		_check(button.position.y + button.size.y <= banner_top,"home control stays above the reserved banner: " + button.text)
	_check(levels.size() == 10,"large banner still leaves all ten campaign nodes present")
	for first in levels.size():
		for second in range(first+1,levels.size()):
			_check(not levels[first].get_rect().intersects(levels[second].get_rect()),"large-banner campaign node hit boxes stay distinct")
	for node in levels:
		for button in feet:
			_check(not node.get_rect().intersects(button.get_rect()),"campaign node does not cover a home footer control")
	var old_screen: String = game.screen
	game._resize()
	_check(game.screen == old_screen and mock.home_banner_visible,"home resize preserves the banner state without navigation")
	game.show_ships()
	_check(not mock.home_banner_visible,"ship selection hides the home-only banner")
	_start(game)
	_check(not mock.home_banner_visible,"active gameplay has no home banner")
	_die(game.arena)
	_check(not mock.home_banner_visible,"rewarded decision has no home banner")
	game._decline_revive()
	_check(mock.home_banner_visible,"returning to the chart restores the home banner")

	mock.privacy_required = false
	game.show_settings()
	_check(not mock.home_banner_visible and _find_button(game,"Ad privacy") == null,"settings hides the home banner and omits an unnecessary privacy action")
	mock.privacy_required = true
	game.show_settings()
	var privacy_button := _find_button(game,"Ad privacy")
	_check(privacy_button != null,"required privacy options are available from settings")
	if privacy_button != null:
		privacy_button.pressed.emit()
	_check(mock.privacy_requests == 1,"privacy settings action uses the injected service")
	_dispose_fixture(fixture)

func _capture_is_read_only() -> void:
	var fixture := _main_fixture(true,true)
	var game = fixture.game
	var mock: MockAds = fixture.ads
	await process_frame
	_check(mock.consent_requests == 0 and not mock.home_banner_visible,"capture previews request neither consent nor banners")
	_start(game)
	_check(not game.arena.allow_rewarded_continue,"capture previews cannot enter a rewarded rescue")
	_die(game.arena)
	_check(_profile().metric("runs_started") == 0 and mock.completed_runs == 0 and mock.reward_requests == 0,"capture results neither persist progression nor advance ad cadence")
	_dispose_fixture(fixture)

func _run() -> void:
	DirAccess.make_dir_recursive_absolute("res://tests/output")
	_reset_profile()
	MainScript = load("res://scripts/main.gd")
	ArenaScript = load("res://scripts/arena.gd")
	if MainScript == null or ArenaScript == null or not MainScript.can_instantiate() or not ArenaScript.can_instantiate():
		printerr("FAIL: Main and arena must compile before the ad-flow integration suite")
		quit(1)
		return
	campaign = JSON.parse_string(FileAccess.get_file_as_string("res://data/campaign.json"))
	_standalone_contract()
	_success_and_no_double_record()
	_unavailable_and_decline()
	await _reward_failure_and_stale_callbacks()
	await _cadence()
	_lifecycle()
	await _home_banner_and_privacy()
	await _capture_is_read_only()
	var report := {"checks":checks,"failures":failures.size(),"details":failures,"actual_ads_requested":false,"save_path":SAVE_PATH}
	var file := FileAccess.open("res://tests/output/ad-flow-tests.json",FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report,"  "))
		file.close()
	print("AD_FLOW_TEST_SUMMARY " + JSON.stringify(report))
	for suffix in ["",".tmp",".bak"]:
		var path: String = SAVE_PATH + str(suffix)
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	quit(1 if not failures.is_empty() else 0)

