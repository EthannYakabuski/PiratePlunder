extends SceneTree
## Headless integration/balance suite. Run with --headless --path . --script res://tests/test_game.gd --log-file tests/game-test.log.
## It redirects progression writes to an explicit test-only path and never records a voyage into the player's save.
var ArenaScript: GDScript
const STEP := 0.05
var campaign: Dictionary = {}
var ships: Array = []
var checks := 0
var failures := 0
var contract_failures: Array[String] = []
var matrix: Array[Dictionary] = []
var normal_runs: Array[Dictionary] = []
var navigation_runs: Array[Dictionary] = []
var started_usec := 0
var peak_endless := {}
var quick := false
var normal_only := false
var navigation_only := false

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		contract_failures.append(label)
		printerr("FAIL: " + label)

func _biome(id: String) -> Dictionary:
	for item in campaign.biomes:
		if item.id == id:
			return item
	return campaign.biomes[0]

func _arena(ship_index: int = 0, level_id: int = 1, mode: String = "campaign"):
	var a = ArenaScript.new()
	root.add_child(a)
	var definition: Dictionary = ships[ship_index].duplicate(true)
	var stage: Dictionary = campaign.levels[level_id - 1].duplicate(true)
	if mode == "endless":
		var rules: Dictionary = campaign.endless
		stage = {"id":0,"name":"Test Endless","biome":rules.starting_biome,"objective":{"type":"survive","target":999999},"max_enemies":rules.max_enemies_start,"spawn_interval":rules.spawn_interval_start,"enemy_pool":rules.enemy_pool,"enemy_strength":1.0,"treasure_count":8,"hazards":[],"boss":null,"waves":[],"endless":rules}
	a.start_run(definition, stage, _biome(str(stage.biome)), mode)
	a.set_process(false)
	a.muted = true
	a.reduced_motion = true
	return a

func _dispose(a) -> void:
	root.remove_child(a)
	a.free()

func _empty(a) -> void:
	a.enemies.clear()
	a.bullets.clear()
	a.pickups.clear()
	a.hazards.clear()
	a.particles.clear()
	a.assisted = false
	a.automated = false
	a.ship.speed = 0.0
	a.spawn_clock = 999999.0
	a.level.waves = []
	a.level.boss = null
	a.level.objective = {"type":"kills","target":999999}
	a.level.duration_limit = 999999.0

func _controls() -> void:
	var a = _arena()
	_empty(a)
	_check(a.fire_side(0), "left broadside can fire")
	_check(a.cooldowns[0] > 0 and a.cooldowns[1] == 0, "left broadside does not consume right cooldown")
	_check(not a.fire_side(0), "left broadside enforces its cooldown")
	_check(a.fire_side(1), "right broadside can fire during left cooldown")
	_check(a.shots == int(a.ship.cannon_count) * 2 and a.bullets.size() == int(a.ship.cannon_count) * 2, "both broadside projectile counts match ship")
	a.paused = true
	var old_time: float = a.elapsed
	a.step(STEP)
	_check(a.elapsed == old_time and not a.fire_side(1), "pause suspends simulation and firing")
	a.paused = false
	a.cooldowns = [0.0, 0.0]
	a._pointer(1, a.wheel_center() + Vector2.RIGHT * 55, true)
	a._pointer(2, a.fire_center(0), true)
	a._pointer(3, a.fire_center(1), true)
	_check(a.wheel_pointer == 1 and a.fire_pointers.size() == 2, "wheel and two cannon touches coexist")
	_check(absf(a.desired_heading) < 0.01, "wheel points ship toward drag direction")
	a._pointer(1, Vector2.ZERO, false)
	a._pointer(2, Vector2.ZERO, false)
	a._pointer(3, Vector2.ZERO, false)
	_check(a.wheel_pointer == -1 and a.fire_pointers.is_empty(), "released fingers clear controls")
	a.enemies.clear()
	a.bullets.clear()
	a.cooldowns = [0.0,0.0]
	a.heading = -PI/2
	a.desired_heading = a.heading
	var target: Dictionary = a.spawn_enemy("chaser")
	target.pos = Vector2(-160,0)
	target.speed = 0.0
	target.cooldown = 99.0
	a.assisted = true
	var previous_shots: int = a.shots
	a.step(STEP)
	_check(a.shots > previous_shots, "one-hand assistance fires a nearby broadside without a fire touch")
	_dispose(a)

func _combat() -> void:
	var a = _arena()
	_empty(a)
	var target: Dictionary = a.spawn_enemy("chaser")
	target.pos = Vector2.ZERO
	target.hp = 100.0
	target.max_hp = 100.0
	a._bullet(Vector2(-100,0), Vector2(1000,0), 35.0, true)
	a._update_bullets(0.2)
	_check(target.hp == 65.0, "swept cannon collision hits a ship crossed between frames")
	target.hp = 10.0
	a._bullet(Vector2(-100,0), Vector2(1000,0), 35.0, true)
	a._update_bullets(0.2)
	_check(a.kills == 1 and a.enemies.is_empty(), "lethal cannon hit counts and removes enemy once")
	_check(a.pickups.size() >= 1, "sunken enemy leaves loot")
	a.invincible_time = 0
	a._bullet(Vector2(-100,0), Vector2(1000,0), 10.0, false)
	a._update_bullets(0.2)
	_check(a.hp == a.max_hp - 10.0, "hostile cannonball damages player")
	var hurt_hp: float = a.hp
	a._damage_player(100)
	_check(a.hp == hurt_hp, "hit grace period prevents instant stacked damage")
	a.invincible_time = 0
	a.shield_time = 2
	a._damage_player(10)
	_check(a.hp == hurt_hp, "bubble shield absorbs hostile damage")
	a.shield_time = 0
	a.invincible_time = 0
	a.enemies.clear()
	a.bullets.clear()
	var left: Dictionary = a.spawn_enemy("chaser")
	left.pos = Vector2(-180,-65)
	left.speed = 0.0
	a.heading = -PI / 2
	a.cooldowns = [0.0,0.0]
	_check(a._side_target(0) != null and a._side_target(1) == null, "assisted targeting respects the selected broadside")
	a.fire_side(0)
	var direction: Vector2 = (left.pos - a.player).normalized()
	_check(a.bullets[0].vel.normalized().dot(direction) > 0.99, "assisted cannon aims toward its nearby side target")
	_dispose(a)

func _pickups_and_hazards() -> void:
	var a = _arena(3)
	_empty(a)
	a._drop(a.player, "coin")
	a._update_pickups(0.01)
	_check(a.treasure >= 1, "treasure pickup contributes to objective")
	a.hp = a.max_hp * 0.4
	a._drop(a.player, "repair")
	a._update_pickups(0.01)
	_check(is_equal_approx(a.hp, a.max_hp * 0.7), "repair restores 30 percent hull")
	a._drop(a.player, "shield")
	a._drop(a.player, "rapid")
	a._update_pickups(0.01)
	_check(a.shield_time > 0 and a.rapid_time > 0 and a.powerups == 3, "shield and rapid-fire pickups activate")
	a.pickups.clear()
	a._drop(a.player + Vector2(500,0), "coin")
	a._drop(a.player, "magnet")
	a._update_pickups(0.01)
	_check(a.pickups.is_empty(), "treasure magnet collects distant nearby loot")
	a._drop(a.player + Vector2(120,0), "coin")
	a._update_pickups(0.05)
	_check(a.pickups[0].pos.distance_to(a.player) < 120, "Golden Gull attracts treasure at its authored extended radius")
	a.pickups.clear()
	a.shield_time = 0
	a.invincible_time = 0
	a.hazards.clear()
	a.hazards.append({"pos":a.player,"type":"mine","radius":25.0,"damage":20.0,"tick":0.0})
	var before_hp: float = a.hp
	a._update_hazards(0.05)
	_check(a.hp == before_hp - 20.0, "mine hazard deals a timed hit")
	a.invincible_time = 0
	a.hazards.clear()
	a.hazards.append({"pos":a.player,"type":"current","radius":88.0,"damage":0.0,"tick":0.0,"force":28.0})
	var before: Vector2 = a.player
	before_hp = a.hp
	a._update_hazards(0.05)
	_check(a.player != before and a.hp == before_hp, "current moves the ship without damage")
	a.invincible_time = 0
	a.hazards.clear()
	a.hazards.append({"pos":a.player + Vector2(20,0),"type":"maelstrom","radius":86.0,"damage":8.0,"tick":1.0,"force":38.0})
	before = a.player
	a._update_hazards(0.05)
	_check(a.player.x > before.x, "whirlpool pulls toward its center")
	a.hazards.clear()
	a.hazards.append({"pos":a.player,"type":"storm","radius":70.0,"damage":12.0,"tick":0.0,"period":9.0,"duration":2.0})
	a.elapsed = 4.0
	a.invincible_time = 0
	before_hp = a.hp
	a._update_hazards(0.05)
	_check(a.hp == before_hp, "storm safe phase causes no damage between active windows")
	a.elapsed = 9.1
	a._update_hazards(0.05)
	_check(a.hp < before_hp, "storm active phase delivers its telegraphed danger")
	_dispose(a)

func _objectives_and_summary() -> void:
	for objective_type in ["kills","coins","survive","boss"]:
		var a = _arena()
		_empty(a)
		var output: Array = []
		a.finished.connect(func(summary: Dictionary): output.append(summary))
		a.level.objective = {"type":objective_type,"target":1}
		match objective_type:
			"kills": a.kills = 1
			"coins": a.treasure = 1
			"survive": a.elapsed = 1
			"boss": a.bosses = 1
		a.step(0.01)
		_check(output.size() == 1 and output[0].won, objective_type + " objective ends in victory")
		if not output.is_empty():
			_check(output[0].has("combo_max") or output[0].has("max_combo"), "result exposes sink combo for achievement progression")
		_dispose(a)
	var a = _arena()
	_empty(a)
	a.level.star_targets = {"time":1.0,"health":0.6,"score":0}
	a.elapsed = 10
	a.hp = a.max_hp * 0.2
	var output: Dictionary = a.finish(true)
	_check(output.stars == 1, "slow low-health victory earns only its completion star")
	_dispose(a)

func _boss_contract() -> void:
	for id in [10,20,30,40,50]:
		var a = _arena(0,id)
		_empty(a)
		a.level.boss = campaign.levels[id-1].boss.duplicate(true)
		var boss: Dictionary = a.spawn_enemy("boss")
		_check(is_equal_approx(boss.hp, float(a.level.boss.hp)), "boss %d uses authored hull" % id)
		_check(is_equal_approx(boss.speed, float(a.level.boss.speed)), "boss %d uses authored speed" % id)
		_check(is_equal_approx(boss.damage, float(a.level.boss.damage)), "boss %d uses authored damage" % id)
		boss.pos = Vector2(200,0)
		boss.cooldown = 0.0
		a._update_enemies(0.01)
		var expected_count := int(a.level.boss.cannon_count) + (2 if a.level.boss.pattern == "fan" else 0)
		_check(a.bullets.size() == expected_count, "boss %d uses authored volley size plus pattern spread" % id)
		_check(boss.pattern == a.level.boss.pattern, "boss %d has its authored attack behavior" % id)
		_dispose(a)

func _navigate_bot(a) -> void:
	# This bot uses the same steering and cannon inputs as a player. It adds
	# short look-ahead obstacle avoidance to the deliberately blind baseline bot.
	var preferred := Vector2.from_angle(a.heading)
	var objective_type: String = a.level.objective.type
	var closest: Variant = null
	var closest_distance := INF
	for enemy in a.enemies:
		var distance: float = enemy.pos.distance_to(a.player)
		if objective_type == "boss" and enemy.kind == "boss":
			closest = enemy
			closest_distance = distance
			break
		if distance < closest_distance:
			closest = enemy
			closest_distance = distance
	if closest != null:
		var offset: Vector2 = closest.pos - a.player
		if objective_type == "survive":
			preferred = -offset.normalized()
		else:
			preferred = offset.normalized().rotated(PI/2 if closest_distance < 330 else 0.65)
	if a.hp < a.max_hp * 0.65:
		for pickup in a.pickups:
			if pickup.type in ["repair","shield"] and pickup.pos.distance_to(a.player) < 280:
				preferred = (pickup.pos-a.player).normalized()
				break
	var obstacles: Array = []
	for hazard in a.hazards:
		if hazard.type != "current":
			obstacles.append({"pos":hazard.pos,"radius":float(hazard.radius)+42})
	var chunk: int = a.chunk_size
	var coord := Vector2i(floori(a.player.x/chunk),floori(a.player.y/chunk))
	for x in range(coord.x-1,coord.x+2):
		for y in range(coord.y-1,coord.y+2):
			var island: Dictionary = a._island(Vector2i(x,y))
			if not island.is_empty():
				obstacles.append({"pos":island.pos,"radius":float(island.radius)+42})
	for enemy in a.enemies:
		var future: Vector2 = enemy.pos + Vector2.from_angle(enemy.heading)*float(enemy.speed)*0.7
		obstacles.append({"pos":future,"radius":float(enemy.radius)+45})
	var best_angle: float = preferred.angle()
	var best_value := -INF
	for option in 20:
		var angle := preferred.angle() + (float(option)-10.0)*PI/10.0
		var effective := rotate_toward(float(a.heading),angle,float(a.ship.turn_speed)*0.6)
		var destination: Vector2 = a.player + Vector2.from_angle(effective)*float(a.ship.speed)*1.3
		var value: float = Vector2.from_angle(angle).dot(preferred)*8.0
		for obstacle in obstacles:
			var near := Geometry2D.get_closest_point_to_segment(obstacle.pos,a.player,destination)
			var clearance: float = near.distance_to(obstacle.pos)-float(obstacle.radius)
			if clearance < 0:
				value -= 100.0-clearance
			elif clearance < 85:
				value -= (85.0-clearance)*0.12
		if value > best_value:
			best_value = value
			best_angle = angle
	a.desired_heading = best_angle
	a.fire_side(0)
	a.fire_side(1)

func _voyage(ship_index: int, level_id: int, invulnerable: bool, navigate: bool = false) -> Dictionary:
	var a = _arena(ship_index, level_id)
	a.automated = not navigate
	a.debug_invulnerable = invulnerable
	var output: Array = []
	a.finished.connect(func(summary: Dictionary): output.append(summary))
	var frame_limit := ceili(float(a.level.duration_limit) / STEP) + 2
	for frame in frame_limit:
		if not a.running:
			break
		if navigate:
			_navigate_bot(a)
		a.step(STEP)
	var result: Dictionary = output[0].duplicate(true) if not output.is_empty() else {"won":false,"seconds":a.elapsed,"kills":a.kills,"treasure":a.treasure}
	result["invulnerable"] = invulnerable
	result["navigation_bot"] = navigate
	result["max_entities"] = a.peak_entities
	result["ship_id"] = ships[ship_index].id
	result["level_id"] = level_id
	_dispose(a)
	return result

func _campaign_matrix() -> void:
	var ids: Array = [1,3,4,5,10,20,30,40,50] if quick else range(1,51)
	for ship_index in ships.size():
		var victories := 0
		var times: Array[float] = []
		for id in ids:
			var result := _voyage(ship_index, id, true)
			matrix.append(result)
			times.append(float(result.seconds))
			victories += 1 if result.won else 0
			if not result.won:
				printerr("BOT_TIMEOUT ship=%s level=%d seconds=%.1f kills=%d treasure=%d" % [result.ship_id,id,result.seconds,result.kills,result.treasure])
		times.sort()
		print("BOT_MATRIX ship=%s victories=%d/%d min=%.1fs median=%.1fs max=%.1fs" % [ships[ship_index].id,victories,ids.size(),times[0],times[times.size()/2],times[-1]])
		_check(victories == ids.size(), "invulnerable bot can finish all tested objectives with " + str(ships[ship_index].id))
func _normal_matrix() -> void:
	for ship_index in ships.size():
		for id in [1,3,4,5,10,19,20,29,30,39,40,47,50]:
			var result := _voyage(ship_index,id,false)
			normal_runs.append(result)
	var normal_summary: Array = []
	for result in normal_runs:
		normal_summary.append({"ship":result.ship_id,"level":result.level_id,"won":result.won,"seconds":snappedf(float(result.seconds),0.1),"hull":snappedf(float(result.health_ratio),0.01)})
	print("NORMAL_RUNS " + JSON.stringify(normal_summary))

func _navigation_observations() -> void:
	var results: Array = []
	for ship_index in ships.size():
		for id in [40,47]:
			var result := _voyage(ship_index,id,false,true)
			navigation_runs.append(result)
			_check(result.won, "navigation bot can clear level %d with %s using normal controls" % [id,result.ship_id])
			results.append({"ship":result.ship_id,"level":id,"won":result.won,"seconds":snappedf(float(result.seconds),0.1),"hull":snappedf(float(result.health_ratio),0.01)})
	print("NAVIGATION_RUNS " + JSON.stringify(results))

func _endless() -> void:
	var a = _arena(0,1,"endless")
	a.automated = true
	a.debug_invulnerable = true
	a.rng.seed = 557901
	var maxima := {"enemies":0,"bullets":0,"particles":0,"pickups":0,"islands":0}
	var began := Time.get_ticks_usec()
	for frame in ceili(1200.0 / STEP):
		a.step(STEP)
		for key in ["enemies","bullets","particles","pickups"]:
			maxima[key] = maxi(int(maxima[key]), a.get(key).size())
		maxima.islands = maxi(int(maxima.islands), a.island_cache.size())
	_check(a.running and a.elapsed >= 1199.9, "endless remains playable after a simulated 20 minutes")
	_check(int(maxima.enemies) <= int(campaign.endless.max_enemies_cap) + 1, "endless enemy population stays within configured cap plus one boss")
	_check(int(maxima.bullets) <= a.MAX_BULLETS, "endless bullets remain bounded")
	_check(int(maxima.particles) <= a.MAX_PARTICLES, "endless particles remain bounded")
	_check(int(maxima.pickups) <= a.MAX_PICKUPS, "endless pickups remain bounded")
	_check(int(maxima.islands) <= 110, "infinite island cache remains bounded")
	var coord := Vector2i(8,9)
	var first: Dictionary = a._island(coord).duplicate(true)
	a.island_cache.erase(coord)
	_check(a._island(coord) == first, "unloaded island chunks regenerate deterministically")
	peak_endless = {"maxima":maxima,"seconds":a.elapsed,"simulation_wall_ms":(Time.get_ticks_usec()-began)/1000.0,"score":a.score,"kills":a.kills}
	print("ENDLESS_RESULT " + JSON.stringify(peak_endless))
	_dispose(a)

func _run() -> void:
	started_usec = Time.get_ticks_usec()
	ArenaScript = load("res://scripts/arena.gd")
	if ArenaScript == null or not ArenaScript.can_instantiate():
		printerr("FAIL: Arena script must compile before gameplay QA")
		quit(1)
		return
	quick = "--quick" in OS.get_cmdline_user_args()
	normal_only = "--normal-only" in OS.get_cmdline_user_args()
	navigation_only = "--navigation-only" in OS.get_cmdline_user_args()
	var progress = root.get_node("Progression")
	progress.save_path = "res://tests/.game-suite-save.json"
	progress.reset_data("game-suite")
	progress.settings.sfx = false
	progress.settings.music = false
	campaign = JSON.parse_string(FileAccess.get_file_as_string("res://data/campaign.json"))
	ships = JSON.parse_string(FileAccess.get_file_as_string("res://data/ships.json")).ships
	_controls()
	_combat()
	_pickups_and_hazards()
	_objectives_and_summary()
	_boss_contract()
	if not normal_only and not navigation_only:
		_campaign_matrix()
	if not navigation_only:
		_normal_matrix()
	_navigation_observations()
	if not normal_only and not navigation_only:
		_endless()
	var won := 0
	var normal_won := 0
	var navigation_won := 0
	for result in matrix:
		won += 1 if result.won else 0
	for result in normal_runs:
		normal_won += 1 if result.won else 0
	for result in navigation_runs:
		navigation_won += 1 if result.won else 0
	print("GAME_TEST_SUMMARY " + JSON.stringify({"checks":checks,"failures":failures,"contract_failures":contract_failures,"campaign_passes":won,"campaign_runs":matrix.size(),"normal_passes":normal_won,"normal_runs":normal_runs.size(),"navigation_passes":navigation_won,"navigation_runs":navigation_runs.size(),"endless":peak_endless,"wall_seconds":(Time.get_ticks_usec()-started_usec)/1000000.0}))
	for suffix in ["",".tmp",".bak"]:
		var path: String = "res://tests/.game-suite-save.json" + str(suffix)
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	quit(1 if failures > 0 else 0)

