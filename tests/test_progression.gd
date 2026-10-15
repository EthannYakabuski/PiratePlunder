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
	_test_upgrade_tree()
	_test_upgrade_migration()
	_test_upgrade_cloud_merge()

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

func _grant_rank(progress: Node, ship_id: String, rank: int, coins: int = -1) -> void:
	var step: int = int(progress.ship_definition(ship_id).progression.xp_per_rank)
	progress.data.devices[progress.data.device_id].ship_xp[ship_id] = step * (rank - 1) * rank / 2
	if coins >= 0:
		progress.data.devices[progress.data.device_id].metrics.coins_collected = coins

func _upgrade_option(progress: Node, ship_id: String, upgrade_id: String) -> Dictionary:
	for option in progress.get_ship_upgrades(ship_id):
		if option.id == upgrade_id:
			return option
	return {}

func _test_upgrade_tree() -> void:
	var tree = _make_progression("upgrade-tree")
	var base: Dictionary = tree.ship_definition("swiftfin")
	var initial: Dictionary = tree.ship_loadout("swiftfin")
	_check(not tree.settings.auto_fire and not initial.primary_auto and not initial.secondary_port and not initial.secondary_starboard, "fresh ships start with manual primary controls and locked secondary controls")
	_check(initial.cannons_port == base.cannon_count and initial.cannons_starboard == base.cannon_count, "loadout starts with base cannon count on both sides")
	tree.settings.auto_fire = true
	_check(not tree.ship_loadout("swiftfin").effective_primary_auto, "manual auto-fire setting cannot grant locked primary automation")
	_check(tree.get_ship_upgrades("swiftfin").size() == 9, "shipyard contains nine staged upgrades")
	_check(tree.ship_loadout("unknown").is_empty() and tree.get_ship_upgrades("unknown").is_empty(), "unknown ships cannot obtain a loadout or upgrade tree")
	_check(not tree.purchase_upgrade("swiftfin", "unknown").success and not tree.purchase_upgrade("unknown", "port_cannon_1").success, "unknown purchase IDs cannot spend gold")
	_grant_rank(tree, "swiftfin", 20, 20000)
	_check(not tree.purchase_upgrade("swiftfin", "primary_auto").success, "rank twenty alone cannot bypass capstone prerequisites")
	_check(not tree.purchase_upgrade("swiftfin", "secondary_auto_port").success, "auxiliary automation requires the matching paid weapon and cannons")
	var cumulative_cost := 0
	var expected_port: int = base.cannon_count
	var expected_starboard: int = base.cannon_count
	for definition in tree.upgrades:
		_grant_rank(tree, "swiftfin", int(definition.required_rank) - 1)
		var gated: Dictionary = _upgrade_option(tree, "swiftfin", definition.id)
		_check(not gated.eligible and not tree.purchase_upgrade("swiftfin", definition.id).success, "%s is denied below its exact ship rank" % definition.id)
		_grant_rank(tree, "swiftfin", int(definition.required_rank))
		_check(_upgrade_option(tree, "swiftfin", definition.id).eligible, "%s becomes eligible at its rank threshold" % definition.id)
		var purchase: Dictionary = tree.purchase_upgrade("swiftfin", definition.id)
		_check(purchase.success and purchase.cost == definition.cost, "%s purchases successfully for the catalog price" % definition.id)
		cumulative_cost += int(definition.cost)
		var loadout: Dictionary = tree.ship_loadout("swiftfin")
		if definition.effects.has("cannons_port"):
			expected_port += 1
		if definition.effects.has("cannons_starboard"):
			expected_starboard += 1
		_check(loadout.cannons_port == expected_port and loadout.cannons_starboard == expected_starboard, "%s adds only its own single cannon, if any" % definition.id)
		_check(tree.gold() == 20000 - cumulative_cost and tree.gold_spent() == cumulative_cost, "%s charges exactly once without changing gross earnings" % definition.id)
		var before_repeat: int = tree.gold()
		_check(not tree.purchase_upgrade("swiftfin", definition.id).success and tree.gold() == before_repeat, "%s repeat taps never pay twice" % definition.id)
		_check(tree.load_data() and tree.owns_upgrade("swiftfin", definition.id), "%s ownership persists immediately across reload" % definition.id)
		if int(definition.required_rank) < 17:
			_check(not loadout.secondary_auto_port and not loadout.secondary_auto_starboard and not loadout.primary_auto, "early and middle purchases do not unlock automation")
	var full: Dictionary = tree.ship_loadout("swiftfin")
	_check(full.cannons_port == int(base.cannon_count) + 2 and full.cannons_starboard == int(base.cannon_count) + 2, "complete cannon branch adds two cannons per side incrementally")
	_check(full.secondary_port and full.secondary_starboard and full.secondary_auto_port and full.secondary_auto_starboard, "both paid scattershot and late crew branches become active")
	_check(full.primary_auto and full.effective_primary_auto and tree.settings.auto_fire, "paid final capstone immediately enables primary automation preference")
	_check(full.secondary_count == 3 and full.secondary_speed == 245.0 and full.secondary_spread == 0.24 and full.secondary_cooldown > full.cooldown, "secondary loadout supplies a distinct slower fan volley")
	_check(is_equal_approx(full.hp, base.hp + tree.ship_bonus("swiftfin").hp) and is_equal_approx(full.damage, base.damage + tree.ship_bonus("swiftfin").damage), "loadout preserves existing per-rank hull and damage bonuses exactly once")
	_check(tree.metric("coins_collected") == 20000 and tree.gold() == 20000 - cumulative_cost, "spending changes wallet without rewriting lifetime gold earned")
	_check(not tree.ship_loadout("ironclad").primary_auto and not tree.owns_upgrade("ironclad", "port_cannon_1"), "all weapon purchases and automation belong only to their ship")
	tree.set_setting("auto_fire", false)
	_check(tree.ship_loadout("swiftfin").primary_auto and not tree.ship_loadout("swiftfin").effective_primary_auto, "capstone owners can still disable automatic primary fire")
	tree.set_setting("auto_fire", true)
	_check(tree.ship_loadout("swiftfin").effective_primary_auto, "capstone owners can enable their purchased primary automation again")
	var poor = _make_progression("poor")
	_grant_rank(poor, "swiftfin", 4, 179)
	_check(not poor.purchase_upgrade("swiftfin", "port_cannon_1").success and poor.gold() == 179 and poor.gold_spent() == 0, "insufficient funds never overspend or grant ownership")
	_grant_rank(poor, "swiftfin", 4, 1000)
	var good_path: String = poor.save_path
	poor.save_path = "res://tests/.missing-upgrade-directory/save.json"
	_check(not poor.purchase_upgrade("swiftfin", "port_cannon_1").success and poor.gold() == 1000 and not poor.owns_upgrade("swiftfin", "port_cannon_1"), "failed persistence rolls back the entire purchase and keeps gold")
	poor.save_path = good_path
	var forged = _make_progression("forged")
	_grant_rank(forged, "swiftfin", 20, 20000)
	forged.settings.auto_fire = true
	forged.data.primary_auto = true
	forged.data.purchases = {"swiftfin": {"primary_auto": true, "secondary_auto_port": true}}
	_check(not forged.ship_loadout("swiftfin").primary_auto and not forged.ship_loadout("swiftfin").secondary_auto_port, "forged boolean ownership and manual automation flags are rejected")
	forged.data.purchases.swiftfin.primary_auto = {"cost": 2800, "device_id": "forged", "at": 1}
	_check(not forged.ship_loadout("swiftfin").primary_auto, "even a capstone receipt cannot activate without every prerequisite")

func _test_upgrade_migration() -> void:
	var migrated = _make_progression("migration")
	_grant_rank(migrated, "redwake", 8, 1234)
	migrated.data.levels["1"] = {"stars": 3, "score": 777, "completed": true}
	migrated.data.achievements.sea_legs = true
	var legacy: Dictionary = migrated.data.duplicate(true)
	legacy.version = 2
	legacy.settings.auto_fire = true
	legacy.settings.music = false
	legacy.services.score_queue.endless_score = 9876
	legacy.erase("purchases")
	var prior_xp: int = migrated.ship_xp("redwake")
	var payload := JSON.stringify(legacy)
	var file := FileAccess.open(migrated.save_path, FileAccess.WRITE)
	file.store_string(JSON.stringify({"version": 2, "payload": payload, "sha256": payload.sha256_text()}))
	file.close()
	_check(migrated.load_data() and migrated.data.version == 3, "existing checksum-wrapped version-two save migrates to version three")
	_check(migrated.ship_xp("redwake") == prior_xp and migrated.gold() == 1234 and migrated.level_state(1).stars == 3 and migrated.is_level_unlocked(2), "migration preserves all existing XP, gold, stars, and shared level unlocks")
	_check(not migrated.settings.music and migrated.data.achievements.sea_legs and migrated.data.services.score_queue.endless_score == 9876, "migration preserves preferences, achievements, and pending service deliveries")
	_check(not migrated.settings.auto_fire and migrated.data.purchases.is_empty() and not migrated.ship_loadout("redwake").primary_auto, "legacy free assisted-fire preference is disabled without granting any upgrades")
	_check(migrated.save_data() == OK and migrated.load_data() and migrated.ship_xp("redwake") == prior_xp, "migrated progress persists without resetting existing users")
	legacy.device_id = "legacy-cloud"
	_check(migrated.merge_cloud(legacy) and migrated.ship_xp("redwake") == prior_xp and not migrated.ship_loadout("redwake").primary_auto, "legacy cloud progress merges idempotently and cannot restore free automation")

func _test_upgrade_cloud_merge() -> void:
	var origin = _make_progression("upgrade-origin")
	_grant_rank(origin, "swiftfin", 20, 1000)
	_grant_rank(origin, "ironclad", 20)
	var first = _make_progression("purchase-a")
	var second = _make_progression("purchase-b")
	first.merge_cloud(origin.export_cloud())
	second.merge_cloud(origin.export_cloud())
	_check(first.purchase_upgrade("swiftfin", "port_cannon_1").success and second.purchase_upgrade("swiftfin", "port_cannon_1").success, "two offline devices can each purchase an affordable upgrade locally")
	var second_cloud: Dictionary = second.export_cloud()
	first.merge_cloud(second_cloud)
	first.merge_cloud(second_cloud)
	second.merge_cloud(first.export_cloud())
	_check(first.gold_spent() == 180 and first.gold() == 820 and second.gold() == 820, "same per-ship purchase on two devices converges with a single charge")
	_check(first.owns_upgrade("swiftfin", "port_cannon_1") and second.owns_upgrade("swiftfin", "port_cannon_1"), "ownership merges by union without disappearing on either device")
	_check(first.purchase_upgrade("swiftfin", "starboard_cannon_1").success and second.purchase_upgrade("ironclad", "port_cannon_1").success, "independent eligible ship purchases can be made after syncing")
	first.merge_cloud(second.export_cloud())
	second.merge_cloud(first.export_cloud())
	_check(first.gold() == 380 and second.gold() == 380 and first.gold_spent() == 620, "different upgrade receipts union and charge each unique ship item once")
	_check(first.ship_loadout("swiftfin").cannons_starboard == 3 and first.ship_loadout("ironclad").cannons_port == 4, "merged weapon purchases affect their correct ship and side")
	var gross_xp: int = first.ship_xp("swiftfin")
	first.merge_cloud(first.export_cloud())
	_check(first.gold() == 380 and first.ship_xp("swiftfin") == gross_xp and first.metric("coins_collected") == 1000, "repeated purchase sync never duplicates spending or rewrites earned XP/gold")
	var old: Dictionary = origin.export_cloud()
	old.version = 2
	old.erase("purchases")
	first.merge_cloud(old)
	_check(first.gold() == 380 and first.owns_upgrade("ironclad", "port_cannon_1"), "stale pre-upgrade cloud saves cannot erase purchases or refund spent gold")
	var scarce_origin = _make_progression("scarce-origin")
	_grant_rank(scarce_origin, "swiftfin", 4, 200)
	_grant_rank(scarce_origin, "ironclad", 4)
	var scarce_a = _make_progression("scarce-a")
	var scarce_b = _make_progression("scarce-b")
	scarce_a.merge_cloud(scarce_origin.export_cloud())
	scarce_b.merge_cloud(scarce_origin.export_cloud())
	_check(scarce_a.purchase_upgrade("swiftfin", "port_cannon_1").success and scarce_b.purchase_upgrade("ironclad", "port_cannon_1").success, "offline purchases each respect their own known balance")
	scarce_a.merge_cloud(scarce_b.export_cloud())
	scarce_b.merge_cloud(scarce_a.export_cloud())
	_check(scarce_a.gold() == 0 and scarce_b.gold() == 0 and scarce_a.gold_spent() == 360, "concurrent different-device spending preserves both purchases with no negative displayed wallet")
	_check(not scarce_a.purchase_upgrade("ironclad", "port_cannon_1").success, "concurrent ownership cannot be bought twice even while the wallet settles")
	scarce_a.data.devices[scarce_a.data.device_id].metrics.coins_collected = 100
	_check(scarce_a.gold() == 0, "future earnings repay outstanding concurrent spend before becoming available")
	scarce_a.data.devices[scarce_a.data.device_id].metrics.coins_collected = 200
	_check(scarce_a.gold() == 40, "settled concurrent spend leaves the exact remaining earned gold")
