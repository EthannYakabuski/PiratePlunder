extends SceneTree
## Run: godot --headless --path . --script res://tests/test_progression.gd

const ProgressionScript = preload("res://scripts/progression.gd")
var failures := 0
var checks := 0
var test_nodes: Array = []

class MockAchievements extends Node:
	var steps: Dictionary = {}
	var unlocks: Array = []
	func set_achievement_steps(id: String, value: int) -> void:
		steps[id] = value
	func unlock_achievement(id: String) -> void:
		unlocks.append(id)

class MockLeaderboards extends Node:
	var scores: Dictionary = {}
	func submit_score(id: String, value: int) -> void:
		scores[id] = value

func _initialize() -> void:
	call_deferred("_run")

func _make_progression(device_id: String):
	var progress = ProgressionScript.new()
	progress.save_path = "res://tests/.test-progress-%s.json" % device_id
	progress._load_definitions()
	progress.reset_data(device_id)
	test_nodes.append(progress)
	return progress

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + label)

func _run() -> void:
	var first = _make_progression("persistence")
	_check(first.is_level_unlocked(1), "first campaign level unlocked")
	_check(not first.is_level_unlocked(2), "second level initially locked")
	var summary := {"run_id": "voyage-one", "mode": "campaign", "level_id": 1, "ship_id": "swiftfin", "won": true, "stars": 3, "score": 400, "kills": 20, "treasure": 70, "seconds": 90, "damage_taken": 0, "shots": 84, "powerups": 5, "combo_max": 5}
	var result: Dictionary = first.record_run(summary)
	_check(first.is_level_unlocked(2), "campaign win unlocks next level")
	_check(first.ship_xp("swiftfin") > 0 and first.ship_xp("ironclad") == 0, "XP belongs to chosen ship")
	_check(first.ship_level("swiftfin") == 2, "rank threshold at 120 XP")
	_check(first.ship_bonus("swiftfin").hp > 0, "rank creates tangible hull perk")
	_check(result.new_achievements.size() > 0, "metric achievements unlock")
	_check(first.metric("perfect_victories") == 1, "undamaged victory counted")
	_check(first.record_run(summary).duplicate, "run IDs reject accidental double completion")
	_check(first.metric("enemies_sunk") == 20, "duplicate result does not duplicate kills")
	_check(first.save_data() == OK, "atomic local save writes")
	var original := first.export_cloud()
	first.reset_data("persistence")
	_check(first.load_data(), "saved progress reloads")
	_check(first.metric("campaign_stars") == 3 and first.gold() == 100, "stars, plunder, and first-clear reward survive restart")
	first.set_setting("music", false)
	_check(first.load_data() and not first.settings.music, "audio preferences survive restart")
	# Second save keeps a good backup. Damage the primary and recover that backup.
	first.save_data()
	var damaged := FileAccess.open(first.save_path, FileAccess.WRITE)
	damaged.store_string("{corrupt-save")
	damaged.close()
	_check(first.load_data() and first.last_load_recovered, "corrupt primary recovers verified backup")
	_check(first.level_state(1).stars == 3, "recovery retains earned stars")

	var local = _make_progression("local")
	var remote = _make_progression("remote")
	local.record_run({"run_id": "local-one", "mode": "campaign", "level_id": 1, "ship_id": "swiftfin", "won": true, "stars": 3, "score": 600, "kills": 4, "treasure": 20, "seconds": 30, "damage_taken": 4})
	remote.record_run({"run_id": "remote-one", "mode": "campaign", "level_id": 1, "ship_id": "ironclad", "won": true, "stars": 1, "score": 300, "kills": 7, "treasure": 30, "seconds": 60, "damage_taken": 3})
	var remote_cloud: Dictionary = remote.export_cloud()
	_check(local.merge_cloud(remote_cloud), "compatible cloud merges")
	_check(local.metric("enemies_sunk") == 11 and local.gold() == 80, "independent counters sum and shared first-clear reward pays once")
	_check(local.level_state(1).stars == 3 and local.level_state(1).score == 600, "weaker remote run cannot lower stars or records")
	_check(local.data.device_id == "local", "cloud does not replace installation identity")
	var merged_xp: int = local.ship_xp("ironclad")
	local.merge_cloud(remote_cloud)
	local.merge_cloud(local.export_cloud())
	_check(local.metric("enemies_sunk") == 11 and local.ship_xp("ironclad") == merged_xp, "cloud merge idempotent")
	remote.merge_cloud(local.export_cloud())
	_check(remote.metric("enemies_sunk") == local.metric("enemies_sunk"), "merge converges across installations")
	local.record_run({"run_id": "local-two", "mode": "endless", "ship_id": "swiftfin", "kills": 3, "treasure": 10, "seconds": 300, "score": 5000})
	remote.merge_cloud(local.export_cloud())
	_check(remote.metric("enemies_sunk") == 14, "post-merge run advances only its local device counter")
	_check(remote.metric("endless_best_score") == 5000 and remote.metric("endless_best_seconds") == 300, "endless bests merge")
	_check(remote.metric("campaign_levels_completed") == 1, "same campaign level on two ships counts once")
	for level_id in range(2, 51):
		local.record_run({"run_id": "complete-%d" % level_id, "mode": "campaign", "level_id": level_id, "ship_id": "redwake", "won": true, "stars": 3, "score": 1000})
	_check(local.metric("campaign_stars") == 150 and local.metric("campaign_levels_completed") == 50, "all fifty campaign levels persist with 150 stars")
	_check(local.metric("biomes_cleared") == 5 and local.next_level() == 50, "full campaign closes all five biomes")
	_check(local.is_level_unlocked(50) and not local.is_level_unlocked(51), "campaign final unlock stays within fifty levels")
	var first_clear_total: int = local.data.reward_events.size()
	local.record_run({"run_id": "replay-one", "mode": "campaign", "level_id": 1, "ship_id": "redwake", "won": true, "stars": 1, "score": 200})
	_check(local.data.reward_events.size() == first_clear_total and local.metric("campaign_stars") == 150, "replay retains best stars and cannot farm first-clear rewards")
	var challenger = _make_progression("challenger")
	var bonus_reward: Dictionary = challenger.record_run({"run_id": "daily-bonus", "mode": "daily", "level_id": 1, "ship_id": "golden_gull", "won": true, "stars": 3, "treasure": 40, "max_combo": 9})
	_check(not challenger.is_level_unlocked(2) and challenger.metric("campaign_stars") == 0, "daily victories cannot unlock campaign levels")
	_check(bonus_reward.coins == 48 and challenger.metric("coins_collected") == 48, "Golden Gull perk applies twenty percent bonus to earned gold")
	_check(challenger.metric("combo_max") == 9, "arena max_combo summary advances achievement metric")

	var reward_a = _make_progression("reward-a")
	var reward_b = _make_progression("reward-b")
	var login: Dictionary = reward_a.claim_login_reward("swiftfin")
	reward_b.claim_login_reward("ironclad")
	_check(login.coins > 0 and reward_a.claim_login_reward().is_empty(), "login reward pays once per day")
	reward_a.merge_cloud(reward_b.export_cloud())
	reward_b.merge_cloud(reward_a.export_cloud())
	_check(reward_a.metric("daily_rewards_claimed") == 1 and reward_a.gold() == login.coins, "two-device same-day rewards do not duplicate gold")
	_check(reward_a.ship_xp("swiftfin") + reward_a.ship_xp("ironclad") == int(login.xp), "same reward does not duplicate ship XP")
	_check(reward_a.get_daily_quests("2026-10-14") == reward_b.get_daily_quests("2026-10-14"), "daily quests deterministic across installations")
	_check(reward_a.get_daily_quests("2026-10-14").size() == 3, "three distinct daily quests")
	_check(reward_a.claim_daily("unknown").is_empty(), "unearned quests cannot be claimed")
	var reward_date: String = reward_a.today()
	reward_a.data.daily[reward_date] = {"reward-a": {"enemies_sunk": 100, "coins_collected": 1000, "cannon_shots": 1000, "runs_started": 10, "powerups_collected": 20, "seconds_played": 1000, "campaign_wins": 5}}
	var daily_id: String = reward_a.get_daily_quests()[0].id
	_check(not reward_a.claim_daily(daily_id, "redwake").is_empty(), "completed quest grants coin and ship XP rewards")
	_check(reward_a.claim_daily(daily_id).is_empty(), "daily quest cannot pay twice")
	_check(reward_a.metric("quests_completed") == 1, "claimed daily quest advances achievement metric")

	var malformed := original.duplicate(true)
	malformed.version = 999
	_check(not first.merge_cloud(malformed), "future incompatible cloud version rejected")
	_check(not first.merge_cloud({"version": 2}), "cloud without identity rejected")
	var unsafe := original.duplicate(true)
	unsafe.devices.persistence.metrics.enemies_sunk = -500
	unsafe.devices.persistence.metrics.coins_collected = "not-a-number"
	unsafe.levels["51"] = {"stars": 3, "completed": true}
	var sanitized: Dictionary = first._sanitize(unsafe)
	_check(sanitized.devices.persistence.metrics.enemies_sunk == 0 and sanitized.devices.persistence.metrics.coins_collected == 0, "invalid counters sanitized")
	_check(not sanitized.levels.has("51"), "cloud cannot add levels outside campaign")
	_test_service_queues()

	for progress in test_nodes:
		for suffix in ["", ".bak", ".tmp"]:
			var path: String = progress.save_path + suffix
			if FileAccess.file_exists(path):
				DirAccess.remove_absolute(path)
		progress.free()
	print("Progression verification: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _test_service_queues() -> void:
	var game_progress: Node = root.get_node("Progression")
	# The adapter accesses the real autoload. Isolate it in an explicitly temporary
	# save and restore the pre-test state before freeing the mock clients.
	var previous: Dictionary = game_progress.data.duplicate(true)
	var previous_settings: Dictionary = game_progress.settings.duplicate(true)
	var previous_path: String = game_progress.save_path
	game_progress.save_path = "res://tests/.test-services.json"
	game_progress.reset_data("service-test")
	game_progress.record_run({"run_id": "queued-run", "mode": "endless", "ship_id": "swiftfin", "kills": 12, "treasure": 10, "seconds": 300, "score": 12345, "shots": 20})
	var services_script: Script = root.get_node("PlayServices").get_script()
	var adapter = services_script.new()
	var achievements_client := MockAchievements.new()
	var boards_client := MockLeaderboards.new()
	adapter._achievements = achievements_client
	adapter._leaderboards = boards_client
	adapter._rebuild_queues()
	_check(game_progress.data.services.achievement_queue.size() > 0 and game_progress.data.services.score_queue.size() > 0, "offline achievement and leaderboard totals queue durably")
	adapter.available = true
	adapter.signed_in = true
	adapter.flush_queues()
	_check(achievements_client.steps.is_empty() and boards_client.scores.is_empty(), "blank backend IDs never send fabricated remote requests")
	adapter.config = {"achievement_ids": {"first_plunder": "real-incremental-id", "sea_legs": "real-standard-id"}, "leaderboard_ids": {"endless_survival": "real-time-id", "endless_score": "real-score-id"}}
	adapter.flush_queues()
	_check(achievements_client.steps.get("real-incremental-id", 0) == 10, "incremental upload uses absolute accumulated steps")
	_check("real-standard-id" in achievements_client.unlocks, "earned standard achievement unlocks using mapped ID")
	_check(boards_client.scores.get("real-time-id", 0) == 300000, "survival leaderboard converts seconds to milliseconds")
	_check(boards_client.scores.get("real-score-id", 0) == 12345, "score leaderboard uses unmodified score")
	adapter._on_achievement_acknowledged(false, "real-incremental-id")
	_check(game_progress.data.services.achievement_queue.has("first_plunder"), "partial/error acknowledgement retains safely repeatable total")
	adapter._on_achievement_acknowledged(true, "real-standard-id")
	_check(not game_progress.data.services.achievement_queue.has("sea_legs"), "successful unlock acknowledges queued standard achievement")
	game_progress.data.services.score_queue.endless_score = 20000
	adapter._on_score_acknowledged(true, "real-score-id")
	_check(game_progress.data.services.score_queue.endless_score == 20000, "old submission acknowledgement cannot drop newer score")
	adapter.flush_queues()
	adapter._on_score_acknowledged(true, "real-score-id")
	_check(not game_progress.data.services.score_queue.has("endless_score"), "successful latest score clears its pending queue")
	_check(not adapter.show_leaderboards("unknown-local-board"), "unknown leaderboard never sends a fabricated request")
	for suffix in ["", ".bak", ".tmp"]:
		var path: String = game_progress.save_path + suffix
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	game_progress.save_path = previous_path
	game_progress.data = previous
	game_progress.settings = previous_settings
	achievements_client.free()
	boards_client.free()
	adapter.free()
