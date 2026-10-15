extends Node
## Offline-first progression. Cloud counters are merged per installation by max,
## then summed, so repeated syncs never duplicate XP, gold, or run statistics.

signal changed
signal achievement_unlocked(achievement_id: String)
signal daily_completed(quest_id: String)
signal run_recorded(summary: Dictionary)

const SAVE_VERSION := 3
const PREVIOUS_SAVE_VERSION := 2
const SHIP_IDS := ["swiftfin", "ironclad", "redwake", "golden_gull"]
const SUM_METRICS := ["runs_started", "enemies_sunk", "cannon_shots", "coins_collected", "powerups_collected", "bosses_sunk", "perfect_victories", "both_sides_kills", "seconds_played", "campaign_wins"]
const MAX_METRICS := ["single_run_kills", "single_run_coins", "endless_best_seconds", "endless_best_score", "combo_max"]
const DEFAULT_SETTINGS := {"music": true, "sfx": true, "haptics": true, "auto_fire": false, "reduced_motion": false, "tutorial_seen": false}
const QUEST_POOL := [
	{"id": "sink", "name": "Sink 18 ships", "metric": "enemies_sunk", "target": 18, "coins": 90, "xp": 50},
	{"id": "gold", "name": "Plunder 100 gold", "metric": "coins_collected", "target": 100, "coins": 100, "xp": 50},
	{"id": "cannons", "name": "Fire 80 cannonballs", "metric": "cannon_shots", "target": 80, "coins": 80, "xp": 50},
	{"id": "voyages", "name": "Play 3 voyages", "metric": "runs_started", "target": 3, "coins": 90, "xp": 50},
	{"id": "supplies", "name": "Collect 5 powerups", "metric": "powerups_collected", "target": 5, "coins": 90, "xp": 50},
	{"id": "seafarer", "name": "Sail for 3 minutes", "metric": "seconds_played", "target": 180, "coins": 100, "xp": 50},
	{"id": "campaign", "name": "Win 2 campaign battles", "metric": "campaign_wins", "target": 2, "coins": 120, "xp": 70},
]

var save_path := "user://pirateplunder-save.json"
var data: Dictionary = {}
var ships: Array = []
var achievements: Array = []
var leaderboards: Array = []
var campaign: Array = []
var upgrades: Array = []
var settings: Dictionary = DEFAULT_SETTINGS.duplicate(true)
var last_save_error := OK
var last_load_recovered := false

func _ready() -> void:
	_load_definitions()
	load_data()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_data()

func _load_definitions() -> void:
	ships = _read_definitions("res://data/ships.json", "ships")
	achievements = _read_definitions("res://data/achievements.json", "achievements")
	leaderboards = _read_definitions("res://data/leaderboards.json", "leaderboards")
	campaign = _read_definitions("res://data/campaign.json", "levels")
	upgrades = _read_definitions("res://data/upgrades.json", "upgrades")

func _read_definitions(path: String, key: String) -> Array:
	if not FileAccess.file_exists(path):
		return []
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Dictionary and parsed.get(key) is Array:
		return parsed[key]
	return []

func reset_data(device_id: String = "") -> void:
	if device_id.is_empty():
		device_id = Crypto.new().generate_random_bytes(16).hex_encode()
	data = {"version": SAVE_VERSION, "device_id": device_id, "devices": {}, "levels": {}, "maxima": {}, "ships_played": {}, "achievements": {}, "reward_events": {}, "daily": {}, "purchases": {}, "settings": DEFAULT_SETTINGS.duplicate(true), "settings_at": 0, "recent_runs": [], "last_run": {}, "services": {"achievement_queue": {}, "score_queue": {}}}
	settings = data.settings
	_ensure_device()

func _ensure_device() -> void:
	var device: String = data.device_id
	if not data.devices.has(device):
		data.devices[device] = {"metrics": {}, "ship_xp": {}}

func save_data() -> Error:
	if data.is_empty():
		reset_data()
	data.settings = settings.duplicate(true)
	var payload := JSON.stringify(data)
	var envelope := JSON.stringify({"version": SAVE_VERSION, "payload": payload, "sha256": payload.sha256_text()})
	var temporary := save_path + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		last_save_error = FileAccess.get_open_error()
		return last_save_error
	file.store_string(envelope)
	file.flush()
	file.close()
	if not _read_save(temporary).is_empty():
		if FileAccess.file_exists(save_path) and not _read_save(save_path).is_empty():
			DirAccess.copy_absolute(save_path, save_path + ".bak")
		last_save_error = DirAccess.rename_absolute(temporary, save_path)
	else:
		last_save_error = ERR_FILE_CORRUPT
	return last_save_error

func _read_save(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path)) != OK:
		return {}
	var parsed: Variant = parser.data
	if not parsed is Dictionary:
		return {}
	if parsed.get("payload") is String:
		var payload: String = parsed.payload
		if payload.sha256_text() != str(parsed.get("sha256", "")):
			return {}
		if parser.parse(payload) != OK:
			return {}
		parsed = parser.data
	return _sanitize(parsed) if parsed is Dictionary else {}

func load_data() -> bool:
	var loaded := _read_save(save_path)
	last_load_recovered = false
	if loaded.is_empty():
		loaded = _read_save(save_path + ".bak")
		last_load_recovered = not loaded.is_empty()
	if loaded.is_empty():
		reset_data()
		return false
	data = loaded
	settings = data.settings
	_ensure_device()
	_recompute_achievements(false)
	changed.emit()
	return true

func _safe_number(value: Variant, maximum: float = 1000000000000.0) -> float:
	if value is int or value is float:
		return clampf(float(value), 0.0, maximum) if is_finite(float(value)) else 0.0
	return 0.0

func _safe_dictionary(value: Variant) -> Dictionary:
	return value if value is Dictionary else {}

func _sanitize(raw: Dictionary) -> Dictionary:
	var source_version := int(_safe_number(raw.get("version", 0)))
	if source_version not in [PREVIOUS_SAVE_VERSION, SAVE_VERSION]:
		return {}
	var identity := str(raw.get("device_id", ""))
	if identity.is_empty() or identity.length() > 128:
		return {}
	var clean := {"version": SAVE_VERSION, "device_id": identity, "devices": {}, "levels": {}, "maxima": {}, "ships_played": {}, "achievements": {}, "reward_events": {}, "daily": {}, "purchases": {}, "settings": DEFAULT_SETTINGS.duplicate(true), "settings_at": _safe_number(raw.get("settings_at", 0)), "recent_runs": [], "last_run": _safe_dictionary(raw.get("last_run", {})).duplicate(true), "services": {"achievement_queue": {}, "score_queue": {}}}
	for device in _safe_dictionary(raw.get("devices", {})):
		if str(device).length() > 128:
			continue
		var source := _safe_dictionary(raw.devices[device])
		var counters := {"metrics": {}, "ship_xp": {}}
		for metric_key in SUM_METRICS:
			counters.metrics[metric_key] = _safe_number(_safe_dictionary(source.get("metrics", {})).get(metric_key, 0))
		for ship_id in SHIP_IDS:
			counters.ship_xp[ship_id] = int(_safe_number(_safe_dictionary(source.get("ship_xp", {})).get(ship_id, 0)))
		clean.devices[str(device)] = counters
	for key in _safe_dictionary(raw.get("levels", {})):
		var level_id := int(str(key))
		if level_id < 1 or level_id > 50:
			continue
		var source := _safe_dictionary(raw.levels[key])
		clean.levels[str(level_id)] = {"stars": int(_safe_number(source.get("stars", 0), 3)), "score": int(_safe_number(source.get("score", 0))), "completed": source.get("completed", false) == true}
	for metric_key in MAX_METRICS:
		clean.maxima[metric_key] = _safe_number(_safe_dictionary(raw.get("maxima", {})).get(metric_key, 0))
	for key in ["ships_played", "achievements"]:
		for id in _safe_dictionary(raw.get(key, {})):
			if str(id).length() <= 128 and raw[key][id] == true:
				clean[key][str(id)] = true
	for key in _safe_dictionary(raw.get("reward_events", {})):
		if str(key).length() > 128:
			continue
		var event := _safe_dictionary(raw.reward_events[key])
		clean.reward_events[str(key)] = {"coins": int(_safe_number(event.get("coins", 0), 1000)), "xp": int(_safe_number(event.get("xp", 0), 1000)), "ship_id": str(event.get("ship_id", SHIP_IDS[0])) if event.get("ship_id") in SHIP_IDS else SHIP_IDS[0], "at": int(_safe_number(event.get("at", 0)))}
	for day in _safe_dictionary(raw.get("daily", {})):
		if str(day).length() != 10:
			continue
		clean.daily[str(day)] = {}
		for device in _safe_dictionary(raw.daily[day]):
			var counters := {}
			for metric_key in SUM_METRICS:
				counters[metric_key] = _safe_number(_safe_dictionary(raw.daily[day][device]).get(metric_key, 0))
			clean.daily[str(day)][str(device)] = counters
	for key in DEFAULT_SETTINGS:
		var setting: Variant = _safe_dictionary(raw.get("settings", {})).get(key)
		if setting is bool:
			clean.settings[key] = setting
	if source_version == PREVIOUS_SAVE_VERSION:
		# Legacy assisted fire was free. It cannot become a paid capability.
		clean.settings.auto_fire = false
	else:
		for ship_id in SHIP_IDS:
			var receipts := _safe_dictionary(_safe_dictionary(raw.get("purchases", {})).get(ship_id, {}))
			for upgrade_id in receipts:
				var definition := _upgrade_definition(str(upgrade_id))
				var receipt := _safe_dictionary(receipts[upgrade_id])
				if definition.is_empty() or not _valid_purchase_receipt(receipt, definition):
					continue
				if not clean.purchases.has(ship_id):
					clean.purchases[ship_id] = {}
				clean.purchases[ship_id][str(upgrade_id)] = {"cost": int(definition.cost), "at": int(_safe_number(receipt.get("at", 0))), "device_id": str(receipt.device_id)}
	for id in raw.get("recent_runs", []) if raw.get("recent_runs", []) is Array else []:
		if str(id).length() <= 128 and clean.recent_runs.size() < 256:
			clean.recent_runs.append(str(id))
	for key in ["achievement_queue", "score_queue"]:
		for id in _safe_dictionary(_safe_dictionary(raw.get("services", {})).get(key, {})):
			clean.services[key][str(id)] = int(_safe_number(raw.services[key][id]))
	return clean

func level_state(level_id: int) -> Dictionary:
	return data.get("levels", {}).get(str(level_id), {"stars": 0, "score": 0, "completed": false}).duplicate(true)

func is_level_unlocked(level_id: int) -> bool:
	return level_id == 1 or (level_id >= 2 and level_id <= 50 and level_state(level_id - 1).completed)

func next_level() -> int:
	for id in range(1, 51):
		if not level_state(id).completed:
			return id
	return 50

func ship_definition(ship_id: String) -> Dictionary:
	for ship in ships:
		if ship.id == ship_id:
			return ship
	return {}

func ship_xp(ship_id: String) -> int:
	var xp := 0
	for device in data.get("devices", {}).values():
		xp += int(device.get("ship_xp", {}).get(ship_id, 0))
	for event in data.get("reward_events", {}).values():
		if event.ship_id == ship_id:
			xp += int(event.xp)
	return xp

func ship_level(ship_id: String) -> int:
	var progression: Dictionary = ship_definition(ship_id).get("progression", {})
	var step := int(progression.get("xp_per_rank", 120))
	var rank := 1
	while rank < int(progression.get("max_rank", 20)) and ship_xp(ship_id) >= step * rank * (rank + 1) / 2:
		rank += 1
	return rank

func ship_rank_progress(ship_id: String) -> Dictionary:
	var rank := ship_level(ship_id)
	var step := int(ship_definition(ship_id).get("progression", {}).get("xp_per_rank", 120))
	var previous := step * (rank - 1) * rank / 2
	var required := step * rank * (rank + 1) / 2
	return {"rank": rank, "xp": ship_xp(ship_id), "current": ship_xp(ship_id) - previous, "needed": required - previous}

func ship_bonus(ship_id: String) -> Dictionary:
	var rank := ship_level(ship_id) - 1
	var progression: Dictionary = ship_definition(ship_id).get("progression", {})
	return {"hp": rank * float(progression.get("hp_per_rank", 3)), "damage": rank * float(progression.get("damage_per_rank", 0.7)), "cooldown_multiplier": maxf(0.65, 1.0 - rank * float(progression.get("cooldown_reduction_per_rank", 0.01))), "rank": rank + 1}

func _upgrade_definition(upgrade_id: String) -> Dictionary:
	for definition in upgrades:
		if definition.id == upgrade_id:
			return definition
	return {}

func _valid_purchase_receipt(receipt: Dictionary, definition: Dictionary) -> bool:
	if receipt.is_empty() or definition.is_empty():
		return false
	return _receipt_matches(receipt, definition)

func _receipt_matches(receipt: Dictionary, definition: Dictionary) -> bool:
	var paid: Variant = receipt.get("cost", -1)
	return (paid is int or paid is float) and is_finite(float(paid)) and float(paid) == float(definition.cost) and str(receipt.get("device_id", "")).length() > 0 and str(receipt.get("device_id", "")).length() <= 128

func owns_upgrade(ship_id: String, upgrade_id: String) -> bool:
	if ship_id not in SHIP_IDS:
		return false
	var definition := _upgrade_definition(upgrade_id)
	if definition.is_empty():
		return false
	var receipt := _safe_dictionary(_safe_dictionary(_safe_dictionary(data.get("purchases", {})).get(ship_id, {})).get(upgrade_id, {}))
	return _valid_purchase_receipt(receipt, definition)

func _upgrade_active(ship_id: String, upgrade_id: String, visiting: Array = []) -> bool:
	if upgrade_id in visiting or not owns_upgrade(ship_id, upgrade_id):
		return false
	var definition := _upgrade_definition(upgrade_id)
	if ship_level(ship_id) < int(definition.required_rank):
		return false
	var next_visiting := visiting.duplicate()
	next_visiting.append(upgrade_id)
	for prerequisite in definition.get("requires", []):
		if not _upgrade_active(ship_id, str(prerequisite), next_visiting):
			return false
	return true

func get_ship_upgrades(ship_id: String) -> Array:
	var result: Array = []
	if ship_id not in SHIP_IDS:
		return result
	for definition in upgrades:
		var option: Dictionary = definition.duplicate(true)
		option.owned = owns_upgrade(ship_id, str(definition.id))
		option.active = _upgrade_active(ship_id, str(definition.id))
		option.eligible = false
		option.reason = ""
		if option.owned:
			option.reason = "Owned"
		elif ship_level(ship_id) < int(definition.required_rank):
			option.reason = "Requires ship rank %d" % int(definition.required_rank)
		else:
			for prerequisite in definition.get("requires", []):
				if not _upgrade_active(ship_id, str(prerequisite)):
					option.reason = "Requires " + str(_upgrade_definition(str(prerequisite)).get("name", prerequisite))
					break
			if str(option.reason).is_empty():
				if gold() < int(definition.cost):
					option.reason = "Need %d more gold" % (int(definition.cost) - gold())
				else:
					option.eligible = true
					option.reason = "Ready to buy"
		result.append(option)
	return result

func purchase_upgrade(ship_id: String, upgrade_id: String) -> Dictionary:
	var result := {"success": false, "message": "Unknown ship or upgrade", "ship_id": ship_id, "upgrade_id": upgrade_id, "cost": 0, "gold": gold()}
	var choice: Dictionary = {}
	for option in get_ship_upgrades(ship_id):
		if option.id == upgrade_id:
			choice = option
			break
	if choice.is_empty():
		return result
	result.message = choice.reason
	if not choice.eligible:
		return result
	# One receipt per ship/upgrade is the spend ledger AND its ownership proof.
	# Merging the same purchase on two devices can therefore never charge twice.
	var previous_purchases := _safe_dictionary(data.get("purchases", {})).duplicate(true)
	var previous_settings := settings.duplicate(true)
	var previous_settings_at: Variant = data.get("settings_at", 0)
	if not data.has("purchases"):
		data.purchases = {}
	if not data.purchases.has(ship_id):
		data.purchases[ship_id] = {}
	data.purchases[ship_id][upgrade_id] = {"cost": int(choice.cost), "at": int(Time.get_unix_time_from_system()), "device_id": str(data.device_id)}
	if upgrade_id == "primary_auto":
		settings.auto_fire = true
		data.settings_at = int(Time.get_unix_time_from_system())
	if save_data() != OK:
		data.purchases = previous_purchases
		settings = previous_settings
		data.settings = settings.duplicate(true)
		data.settings_at = previous_settings_at
		result.message = "Could not save the upgrade. Your gold was kept."
		return result
	result.success = true
	result.message = str(choice.name) + " fitted!"
	result.cost = int(choice.cost)
	result.gold = gold()
	changed.emit()
	return result

func ship_loadout(ship_id: String) -> Dictionary:
	var loadout := ship_definition(ship_id).duplicate(true)
	if loadout.is_empty():
		return {}
	var bonus := ship_bonus(ship_id)
	loadout.rank = int(bonus.rank)
	loadout.hp = float(loadout.hp) + float(bonus.hp)
	loadout.damage = float(loadout.damage) + float(bonus.damage)
	loadout.cooldown = float(loadout.cooldown) * float(bonus.cooldown_multiplier)
	loadout.cannons_port = int(loadout.get("cannon_count", 2))
	loadout.cannons_starboard = int(loadout.get("cannon_count", 2))
	for key in ["secondary_port", "secondary_starboard", "secondary_auto_port", "secondary_auto_starboard", "primary_auto"]:
		loadout[key] = false
	for definition in upgrades:
		if not _upgrade_active(ship_id, str(definition.id)):
			continue
		var effects: Dictionary = definition.get("effects", {})
		for key in ["cannons_port", "cannons_starboard"]:
			loadout[key] += int(effects.get(key, 0))
		for key in ["secondary_port", "secondary_starboard", "secondary_auto_port", "secondary_auto_starboard", "primary_auto"]:
			loadout[key] = loadout[key] or effects.get(key, false) == true
	loadout.secondary_damage = float(loadout.damage) * 1.6
	loadout.secondary_cooldown = 3.8 * float(bonus.cooldown_multiplier)
	loadout.secondary_speed = 245.0
	loadout.secondary_spread = 0.24
	loadout.secondary_count = 3
	loadout.secondary_radius = 7.0
	loadout.effective_primary_auto = loadout.primary_auto and settings.get("auto_fire", false) == true
	return loadout

func metric(id: String) -> float:
	if id in MAX_METRICS:
		return float(data.get("maxima", {}).get(id, 0))
	if id == "campaign_levels_completed":
		var count := 0
		for state in data.get("levels", {}).values():
			count += 1 if state.completed else 0
		return count
	if id == "campaign_stars":
		var total := 0
		for state in data.get("levels", {}).values():
			total += int(state.stars)
		return total
	if id == "biomes_cleared":
		var count := 0
		for biome in range(5):
			var complete := true
			for level in range(biome * 10 + 1, biome * 10 + 11):
				complete = complete and level_state(level).completed
			count += 1 if complete else 0
		return count
	if id == "ships_played":
		return data.get("ships_played", {}).size()
	if id == "ship_rank_max" or id == "total_ship_ranks":
		var total := 0
		for ship in SHIP_IDS:
			total = maxi(total, ship_level(ship)) if id == "ship_rank_max" else total + ship_level(ship)
		return total
	if id == "quests_completed" or id == "daily_rewards_claimed":
		var count := 0
		for key in data.get("reward_events", {}):
			count += 1 if str(key).begins_with("quest:" if id == "quests_completed" else "login:") else 0
		return count
	var total := 0.0
	for device in data.get("devices", {}).values():
		total += float(device.get("metrics", {}).get(id, 0))
	return total

func gold() -> int:
	var value := int(metric("coins_collected"))
	for event in data.get("reward_events", {}).values():
		value += int(event.coins)
	return maxi(0, value - gold_spent())

func gold_spent() -> int:
	var spent := 0
	for ship_id in SHIP_IDS:
		for definition in upgrades:
			if owns_upgrade(ship_id, str(definition.id)):
				spent += int(definition.cost)
	return spent

func record_run(summary: Dictionary) -> Dictionary:
	if data.is_empty():
		reset_data()
	var run_id := str(summary.get("run_id", Crypto.new().generate_random_bytes(12).hex_encode()))
	if run_id in data.recent_runs:
		return {"duplicate": true, "xp": 0, "coins": 0, "new_achievements": []}
	data.recent_runs.append(run_id)
	if data.recent_runs.size() > 256:
		data.recent_runs.pop_front()
	var ship_id := str(summary.get("ship_id", SHIP_IDS[0]))
	if not ship_id in SHIP_IDS:
		ship_id = SHIP_IDS[0]
	var won: bool = summary.get("won", false) == true
	var mode := str(summary.get("mode", "campaign"))
	var kills := int(_safe_number(summary.get("kills", 0), 100000))
	var multiplier := float(ship_definition(ship_id).get("perk", {}).get("coin_multiplier", 1.0))
	var coins := roundi(_safe_number(summary.get("treasure", summary.get("coins", 0)), 100000) * multiplier)
	var seconds := _safe_number(summary.get("seconds", 0), 86400)
	var level_id := int(_safe_number(summary.get("level_id", 1), 50))
	var stars := int(_safe_number(summary.get("stars", 1), 3)) if won else 0
	var score := int(_safe_number(summary.get("score", 0)))
	var old_rank := ship_level(ship_id)
	var xp := 15 + kills * 5 + int(seconds / 5.0)
	var first_clear_reward := {"coins": 0, "xp": 0}
	if won and mode == "campaign" and level_id >= 1 and not data.reward_events.has("campaign:" + str(level_id)):
		var level_reward: Dictionary = summary.get("reward", {}) if summary.get("reward", {}) is Dictionary else {}
		if level_reward.is_empty():
			for definition in campaign:
				if int(definition.id) == level_id:
					level_reward = definition.get("reward", {})
					break
		first_clear_reward = _reward("campaign:" + str(level_id), roundi(_safe_number(level_reward.get("coins", 0), 1000) * multiplier), int(_safe_number(level_reward.get("xp", 40 + level_id * 2), 1000)), ship_id)
	var additions := {"runs_started": 1, "enemies_sunk": kills, "coins_collected": coins, "cannon_shots": _safe_number(summary.get("shots", 0)), "powerups_collected": _safe_number(summary.get("powerups", 0)), "bosses_sunk": _safe_number(summary.get("bosses", 0)), "seconds_played": seconds, "campaign_wins": 1 if won and mode == "campaign" else 0, "perfect_victories": 1 if won and _safe_number(summary.get("damage_taken", 0)) == 0 else 0, "both_sides_kills": _safe_number(summary.get("both_sides_kills", 0))}
	_ensure_device()
	var device: Dictionary = data.devices[data.device_id]
	var date := today()
	if not data.daily.has(date):
		data.daily[date] = {}
	if not data.daily[date].has(data.device_id):
		data.daily[date][data.device_id] = {}
	for key in additions:
		device.metrics[key] = float(device.metrics.get(key, 0)) + float(additions[key])
		data.daily[date][data.device_id][key] = float(data.daily[date][data.device_id].get(key, 0)) + float(additions[key])
	device.ship_xp[ship_id] = int(device.ship_xp.get(ship_id, 0)) + xp
	data.ships_played[ship_id] = true
	data.maxima.single_run_kills = maxf(float(data.maxima.get("single_run_kills", 0)), kills)
	data.maxima.single_run_coins = maxf(float(data.maxima.get("single_run_coins", 0)), coins)
	data.maxima.combo_max = maxf(float(data.maxima.get("combo_max", 0)), _safe_number(summary.get("combo_max", summary.get("max_combo", 0))))
	if mode == "endless":
		data.maxima.endless_best_score = maxf(float(data.maxima.get("endless_best_score", 0)), score)
		data.maxima.endless_best_seconds = maxf(float(data.maxima.get("endless_best_seconds", 0)), seconds)
	elif won and mode == "campaign" and level_id >= 1:
		var old := level_state(level_id)
		data.levels[str(level_id)] = {"stars": maxi(int(old.stars), maxi(1, stars)), "score": maxi(int(old.score), score), "completed": true}
	data.last_run = summary.duplicate(true)
	var unlocked := _recompute_achievements()
	for quest in get_daily_quests():
		if quest.complete and not quest.claimed:
			daily_completed.emit(quest.id)
	_prune_daily()
	save_data()
	changed.emit()
	run_recorded.emit(summary)
	return {"duplicate": false, "xp": xp + int(first_clear_reward.xp), "coins": coins + int(first_clear_reward.coins), "rank_before": old_rank, "rank_after": ship_level(ship_id), "new_achievements": unlocked}

func _recompute_achievements(emit_signals: bool = true) -> Array:
	var unlocked: Array = []
	for definition in achievements:
		if metric(str(definition.get("metric", ""))) >= float(definition.get("target", 1)) and not data.achievements.has(definition.id):
			data.achievements[definition.id] = true
			unlocked.append(definition.id)
			if emit_signals:
				achievement_unlocked.emit(definition.id)
	return unlocked

func achievement_progress(id: String) -> Dictionary:
	for definition in achievements:
		if definition.id == id:
			return {"unlocked": data.achievements.get(id, false), "current": minf(metric(definition.metric), float(definition.target)), "target": definition.target}
	return {"unlocked": false, "current": 0, "target": 1}

func today(unix_time: int = -1) -> String:
	return Time.get_date_string_from_unix_time(int(Time.get_unix_time_from_system()) if unix_time < 0 else unix_time)

func get_daily_quests(date: String = "") -> Array:
	if date.is_empty():
		date = today()
	var start := absi(date.hash()) % QUEST_POOL.size()
	var result: Array = []
	for offset in range(3):
		var quest: Dictionary = QUEST_POOL[(start + offset * 2) % QUEST_POOL.size()].duplicate(true)
		var current := 0.0
		for counters in data.get("daily", {}).get(date, {}).values():
			current += float(counters.get(quest.metric, 0))
		quest.current = minf(current, float(quest.target))
		quest.complete = current >= float(quest.target)
		quest.claimed = data.get("reward_events", {}).has("quest:%s:%s" % [date, quest.id])
		result.append(quest)
	return result

func claim_daily(id: String, ship_id: String = "swiftfin") -> Dictionary:
	for quest in get_daily_quests():
		if quest.id == id and quest.complete and not quest.claimed:
			var reward := _reward("quest:%s:%s" % [today(), id], int(quest.coins), int(quest.xp), ship_id)
			_recompute_achievements()
			save_data()
			changed.emit()
			return reward
	return {}

func login_reward_available() -> bool:
	return not data.get("reward_events", {}).has("login:" + today())

func login_streak() -> int:
	var now := int(Time.get_unix_time_from_system())
	var streak := 0
	if not data.get("reward_events", {}).has("login:" + today(now)):
		now -= 86400
	for offset in range(7):
		if not data.get("reward_events", {}).has("login:" + today(now - offset * 86400)):
			break
		streak += 1
	return streak

func claim_login_reward(ship_id: String = "swiftfin") -> Dictionary:
	if not login_reward_available():
		return {}
	var streak := mini(7, login_streak() + 1)
	var reward := _reward("login:" + today(), 40 + streak * 15, 25 + streak * 5, ship_id)
	_recompute_achievements()
	save_data()
	changed.emit()
	return reward

func _reward(key: String, coins: int, xp: int, ship_id: String) -> Dictionary:
	var event := {"coins": coins, "xp": xp, "ship_id": ship_id if ship_id in SHIP_IDS else SHIP_IDS[0], "at": int(Time.get_unix_time_from_system())}
	data.reward_events[key] = event
	return event.duplicate(true)

func _prune_daily() -> void:
	var oldest := today(int(Time.get_unix_time_from_system()) - 14 * 86400)
	for date in data.daily.keys():
		if str(date) < oldest:
			data.daily.erase(date)

func set_setting(key: String, value: bool) -> void:
	if not DEFAULT_SETTINGS.has(key):
		return
	settings[key] = value
	data.settings_at = int(Time.get_unix_time_from_system())
	save_data()
	changed.emit()

func export_cloud() -> Dictionary:
	var cloud := data.duplicate(true)
	cloud.erase("services")
	cloud.erase("recent_runs")
	cloud.erase("last_run")
	return cloud

func merge_cloud(remote: Dictionary) -> bool:
	var clean := _sanitize(remote)
	if clean.is_empty():
		return false
	# Device identity and sync queues belong to this installation.
	for device_id in clean.devices:
		if not data.devices.has(device_id):
			data.devices[device_id] = clean.devices[device_id].duplicate(true)
		else:
			for key in ["metrics", "ship_xp"]:
				_merge_max_map(data.devices[device_id][key], clean.devices[device_id][key])
	for level_id in clean.levels:
		var old := level_state(int(level_id))
		var incoming: Dictionary = clean.levels[level_id]
		data.levels[level_id] = {"stars": maxi(int(old.stars), int(incoming.stars)), "score": maxi(int(old.score), int(incoming.score)), "completed": old.completed or incoming.completed}
	_merge_max_map(data.maxima, clean.maxima)
	for key in ["ships_played", "achievements"]:
		for id in clean[key]:
			data[key][id] = true
	for key in clean.reward_events:
		var incoming: Dictionary = clean.reward_events[key]
		if not data.reward_events.has(key) or _event_precedes(incoming, data.reward_events[key]):
			data.reward_events[key] = incoming.duplicate(true)
	if not data.has("purchases"):
		data.purchases = {}
	for ship_id in clean.purchases:
		if not data.purchases.has(ship_id):
			data.purchases[ship_id] = {}
		for upgrade_id in clean.purchases[ship_id]:
			var incoming: Dictionary = clean.purchases[ship_id][upgrade_id]
			var existing: Dictionary = data.purchases[ship_id].get(upgrade_id, {})
			if existing.is_empty() or _purchase_precedes(incoming, existing):
				data.purchases[ship_id][upgrade_id] = incoming.duplicate(true)
	for date in clean.daily:
		if not data.daily.has(date):
			data.daily[date] = {}
		for device_id in clean.daily[date]:
			if not data.daily[date].has(device_id):
				data.daily[date][device_id] = {}
			_merge_max_map(data.daily[date][device_id], clean.daily[date][device_id])
	if float(clean.settings_at) > float(data.settings_at):
		settings = clean.settings.duplicate(true)
		data.settings_at = clean.settings_at
	_ensure_device()
	_recompute_achievements()
	_prune_daily()
	save_data()
	changed.emit()
	return true

func _merge_max_map(destination: Dictionary, source: Dictionary) -> void:
	for key in source:
		destination[key] = maxf(float(destination.get(key, 0)), float(source[key]))

func _event_precedes(first: Dictionary, second: Dictionary) -> bool:
	if first.at != second.at:
		return first.at < second.at
	if first.ship_id != second.ship_id:
		return str(first.ship_id) < str(second.ship_id)
	if first.coins != second.coins:
		return first.coins < second.coins
	return first.xp < second.xp

func _purchase_precedes(first: Dictionary, second: Dictionary) -> bool:
	return int(first.at) < int(second.at) or (int(first.at) == int(second.at) and str(first.device_id) < str(second.device_id))
