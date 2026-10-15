extends Node2D
## Bounded, deterministic ocean simulation; all world positions remain independent of UI.
signal finished(summary: Dictionary)
signal hud_changed
signal toast(message: String)

const SHIP_DIR := "res://Assets/PirateStuff/PNG/Retina/Ships/"
const TILE_DIR := "res://Assets/PirateStuff/PNG/Retina/Tiles/"
const MAX_BULLETS := 220
const MAX_PARTICLES := 320
const MAX_PICKUPS := 70
var rng := RandomNumberGenerator.new()
var ship: Dictionary
var level: Dictionary
var biome: Dictionary
var mode := "campaign"
var player := Vector2.ZERO
var heading := -PI / 2.0
var desired_heading := -PI / 2.0
var hp := 100.0
var max_hp := 100.0
var elapsed := 0.0
var score := 0
var kills := 0
var bosses := 0
var treasure := 0
var shots := 0
var powerups := 0
var damage_taken := 0.0
var combo := 0
var best_combo := 0
var combo_time := 0.0
var cooldowns := [0.0, 0.0]
var spawn_clock := 1.0
var boss_spawned := false
var boss_clock := 60.0
var wave_index := 0
var enemies: Array[Dictionary] = []
var bullets: Array[Dictionary] = []
var particles: Array[Dictionary] = []
var pickups: Array[Dictionary] = []
var hazards: Array[Dictionary] = []
var island_cache: Dictionary = {}
var textures: Dictionary = {}
var running := false
var paused := false
var shield_time := 0.0
var rapid_time := 0.0
var invincible_time := 0.0
var flash := 0.0
var shake := 0.0
var tutorial := false
var tutorial_step := 0
var wheel_pointer := -1
var wheel_vector := Vector2.UP
var fire_pointers: Dictionary = {}
var assisted := true
var reduced_motion := false
var muted := false
var audio_pool: Array[AudioStreamPlayer] = []
var audio_cursor := 0
var sfx: Dictionary = {}
var automated := false
var debug_invulnerable := false
var peak_entities := 0
var definitions: Dictionary = {}
var voyage_seed := 0
var supply_clock := 18.0
var kills_by_side := [0,0]
var biome_index := 0
var chunk_size := 420

func _ready() -> void:
	definitions = JSON.parse_string(FileAccess.get_file_as_string("res://data/campaign.json"))
	for i in range(1, 25):
		textures["ship%d" % i] = load(SHIP_DIR + "ship (%d).png" % i)
	textures["cannon"] = load("res://Assets/PirateStuff/PNG/Retina/Ship parts/cannon.png")
	textures["waves"] = load("res://assets_generated/ui/ocean_waves.svg")
	textures["particle"] = load("res://assets_generated/ui/particle.svg")
	for i in [1,2,3,17,18,19,33,34,35,49,50,51,65,66,67,70,71,72]:
		var path := TILE_DIR + "tile_%02d.png" % i
		if ResourceLoader.exists(path): textures["tile%d" % i] = load(path)
	for i in range(8):
		var voice := AudioStreamPlayer.new()
		voice.volume_db = -14
		add_child(voice)
		audio_pool.append(voice)
	for key in {"cannon":"res://assets_generated/audio/cannon.wav", "hit":"res://Assets/ImpactSounds/Audio/impactWood_heavy_000.ogg", "coin":"res://Assets/RPGAudio/Audio/handleCoins.ogg", "power":"res://Assets/InterfaceAudio/Audio/confirmation_001.ogg"}:
		var paths := {"cannon":"res://assets_generated/audio/cannon.wav", "hit":"res://Assets/ImpactSounds/Audio/impactWood_heavy_000.ogg", "coin":"res://Assets/RPGAudio/Audio/handleCoins.ogg", "power":"res://Assets/InterfaceAudio/Audio/confirmation_001.ogg"}
		if ResourceLoader.exists(paths[key]): sfx[key] = load(paths[key])
	set_process(false)

func start_run(ship_data: Dictionary, level_data: Dictionary, biome_data: Dictionary, run_mode: String, is_tutorial := false) -> void:
	ship = ship_data.duplicate(true)
	level = level_data.duplicate(true)
	biome = biome_data.duplicate(true)
	mode = run_mode
	rng.seed = 83917 + int(level.get("id", 1)) * 731 + (int(Time.get_unix_time_from_system()) if mode == "endless" else 0)
	voyage_seed = rng.seed
	if mode == "endless":
		level.endless = level.get("endless",definitions.get("endless",{}))
		boss_clock = float(level.endless.get("boss_every_seconds",90))
		chunk_size = int(level.endless.get("chunk_size",512))
	max_hp = float(ship.get("hp", 100))
	hp = max_hp
	assisted = bool(Progression.settings.get("auto_fire", true))
	reduced_motion = bool(Progression.settings.get("reduced_motion", false))
	muted = not bool(Progression.settings.get("sfx", true))
	tutorial = is_tutorial
	running = true
	for h in level.get("hazards", []):
		for n in int(h.get("count", 1)):
			var pos := Vector2.from_angle(rng.randf_range(-PI, PI)) * rng.randf_range(240, 900)
			hazards.append({"pos":pos,"type":h.type,"radius":float(h.get("radius", 42)),"damage":float(h.get("damage", 8)),"tick":0.0,"force":float(h.get("force",45)),"period":float(h.get("period",0)),"duration":float(h.get("duration",0)),"phase":rng.randf_range(0,5)})
	for i in int(level.get("treasure_count", 5)):
		pickups.append({"pos":Vector2.from_angle(rng.randf_range(-PI, PI)) * rng.randf_range(130, 600),"type":"coin","life":200.0})
	_drop(Vector2(0,-150),"repair")
	supply_clock = float(level.get("powerup_interval",23))
	for i in 2: spawn_enemy("chaser")
	set_process(true)
	queue_redraw()

func screen_size() -> Vector2:
	return get_viewport_rect().size

func camera_center() -> Vector2:
	return Vector2(screen_size().x * 0.5, screen_size().y * 0.435)

func world_screen(pos: Vector2) -> Vector2:
	return pos - player + camera_center()

func wheel_center() -> Vector2:
	return Vector2(screen_size().x * 0.5, screen_size().y - 124)

func fire_center(side: int) -> Vector2:
	return Vector2(72 if side == 0 else screen_size().x - 72, screen_size().y - 92)

func _unhandled_input(event: InputEvent) -> void:
	if not running or paused: return
	if event is InputEventScreenTouch:
		_pointer(event.index, event.position, event.pressed)
	elif event is InputEventScreenDrag:
		_drag(event.index, event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_pointer(99, event.position, event.pressed)
	elif event is InputEventMouseMotion and wheel_pointer == 99:
		_drag(99, event.position)
	elif event is InputEventKey and event.pressed:
		if event.keycode == KEY_Q: fire_side(0)
		if event.keycode == KEY_E or event.keycode == KEY_SPACE: fire_side(1)

func _pointer(id: int, pos: Vector2, pressed: bool) -> void:
	if not pressed:
		if wheel_pointer == id: wheel_pointer = -1
		fire_pointers.erase(id)
		return
	if pos.distance_to(wheel_center()) < 110:
		wheel_pointer = id
		_drag(id, pos)
		if tutorial_step == 0: tutorial_step = 1
	else:
		for side in 2:
			if pos.distance_to(fire_center(side)) < 64:
				fire_pointers[id] = side
				fire_side(side)
				if tutorial_step == 1: tutorial_step = 2

func _drag(id: int, pos: Vector2) -> void:
	if wheel_pointer != id: return
	var delta := pos - wheel_center()
	if delta.length() > 12:
		wheel_vector = delta.normalized()
		desired_heading = delta.angle()

func _process(delta: float) -> void:
	if not running or paused: return
	step(minf(delta, 0.05))
	queue_redraw()

func step(dt: float) -> void:
	if not running or paused: return
	elapsed += dt
	if automated: _bot()
	var keyboard := Vector2(float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)), float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN)) - float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)))
	if keyboard.length() > 0: desired_heading = keyboard.angle()
	heading = rotate_toward(heading, desired_heading, float(ship.get("turn_speed", 3.0)) * dt)
	var velocity := Vector2.from_angle(heading) * float(ship.get("speed", 130))
	player += velocity * dt
	shield_time = maxf(0, shield_time - dt)
	rapid_time = maxf(0, rapid_time - dt)
	invincible_time = maxf(0, invincible_time - dt)
	flash = maxf(0, flash - dt)
	shake = maxf(0, shake - dt * 18)
	combo_time -= dt
	if combo_time <= 0: combo = 0
	for side in 2: cooldowns[side] = maxf(0, cooldowns[side] - dt)
	for side in fire_pointers.values(): fire_side(side)
	if Input.is_physical_key_pressed(KEY_Q): fire_side(0)
	if Input.is_physical_key_pressed(KEY_E) or Input.is_physical_key_pressed(KEY_SPACE): fire_side(1)
	if assisted:
		for side in 2:
			if _side_target(side) != null: fire_side(side)
	_update_spawns(dt)
	_update_enemies(dt)
	_update_bullets(dt)
	_update_pickups(dt)
	_update_hazards(dt)
	_update_particles(dt)
	supply_clock -= dt
	if supply_clock <= 0:
		supply_clock = float(level.get("powerup_interval",23))
		var supply_pool := ["repair","shield","rapid","magnet"]
		_drop(player+Vector2.from_angle(heading)*160,supply_pool[rng.randi_range(0,3)])
	if rng.randf() < dt * 16: _particle(player - Vector2.from_angle(heading) * 32, Color(0.65, 0.95, 0.94, 0.6), -velocity * 0.15, 1.4, 5)
	peak_entities = maxi(peak_entities, enemies.size() + bullets.size() + particles.size() + pickups.size())
	if hp <= 0: finish(false)
	if mode != "endless":
		var obj: Dictionary = level.get("objective", {"type":"kills","target":5})
		var complete := false
		match obj.type:
			"kills": complete = kills >= int(obj.target)
			"coins": complete = treasure >= int(obj.target)
			"survive": complete = elapsed >= float(obj.target)
			"boss": complete = bosses >= int(obj.target)
		if complete: finish(true)
		elif elapsed >= float(level.get("duration_limit", 150)): finish(false)
	hud_changed.emit()

func _bot() -> void:
	var obj: Dictionary = level.get("objective", {})
	if obj.get("type", "kills") == "coins" and not pickups.is_empty():
		desired_heading = (pickups[0].pos - player).angle()
	elif not enemies.is_empty():
		var nearest: Dictionary = enemies[0]
		for e in enemies:
			if e.pos.distance_squared_to(player) < nearest.pos.distance_squared_to(player): nearest = e
		var d: Vector2 = nearest.pos - player
		desired_heading = d.angle() + (PI / 2.0 if d.length() < 310 else 0.7)
	else: desired_heading = elapsed * 0.25
	for side in 2: fire_side(side)

func _update_spawns(dt: float) -> void:
	spawn_clock -= dt
	var endless: Dictionary = level.get("endless",{})
	var difficulty := (1.0 + elapsed / 60.0 * float(endless.get("enemy_strength_gain_per_minute",0.12))) if mode == "endless" else float(level.get("enemy_strength", 1.0))
	var cap := int(level.get("max_enemies",8))
	if mode == "endless": cap = mini(int(endless.get("max_enemies_cap",14)),int(endless.get("max_enemies_start",4))+int(elapsed/35))
	if spawn_clock <= 0:
		spawn_clock = float(level.get("spawn_interval",4.0))
		if mode == "endless": spawn_clock = lerpf(float(endless.get("spawn_interval_start",5)),float(endless.get("spawn_interval_min",1.35)),minf(1,elapsed/float(endless.get("spawn_ramp_seconds",300))))
		if enemies.size() < cap:
			var pool: Array = level.get("enemy_pool", ["chaser"])
			spawn_enemy(str(pool[rng.randi_range(0, pool.size() - 1)]))
	var waves: Array = level.get("waves", [])
	while wave_index < waves.size() and elapsed >= float(waves[wave_index].at):
		for kind in waves[wave_index].enemies:
			if enemies.size() < cap: spawn_enemy(str(kind))
		wave_index += 1
	if level.get("boss") != null and not boss_spawned and elapsed > float(level.boss.get("at",8)):
		boss_spawned = true
		spawn_enemy("boss")
		toast.emit("BOSS AHOY!  " + str(level.boss.get("name", "Dread Captain")))
	if mode == "endless" and elapsed > boss_clock:
		boss_clock += float(endless.get("boss_every_seconds",90))
		spawn_enemy("boss")
		toast.emit("DREAD CAPTAIN INBOUND!")
	if mode == "endless":
		var next_biome := int(elapsed/float(endless.get("biome_change_seconds",90)))%5
		if next_biome != biome_index:
			biome_index = next_biome
			biome = definitions.biomes[biome_index]
			toast.emit("NEW WATERS: " + str(biome.name))
			island_cache.clear()
			hazards.clear()
			for n in mini(int(endless.get("hazard_count_cap",8)),2+int(elapsed/90)):
				hazards.append({"pos":player+Vector2.from_angle(rng.randf()*TAU)*rng.randf_range(240,750),"type":biome.get("hazard","reef"),"radius":52.0,"damage":9.0*difficulty,"tick":0.0,"force":40.0,"period":9.0,"duration":2.0,"phase":float(n)})

func spawn_enemy(kind: String) -> Dictionary:
	if enemies.size() >= 36: return {}
	if mode == "endless" and enemies.size() >= int(level.get("endless",{}).get("max_enemies_cap",14)):
		if kind != "boss": return {}
		# A timed boss replaces an old rival, keeping even unattended runs bounded.
		var replace_index := 0
		for i in enemies.size():
			if enemies[i].kind != "boss": replace_index=i; break
		enemies.remove_at(replace_index)
	var strength := float(level.get("enemy_strength", 1.0))
	if mode == "endless": strength = 1.0 + elapsed/60.0*float(level.get("endless",{}).get("enemy_strength_gain_per_minute",0.12))
	var specs := {"chaser":[42,82,9,3.8,2],"skirmisher":[36,112,8,3.2,8],"sniper":[40,60,13,4.2,14],"rammer":[72,128,17,5.0,15],"runner":[32,98,7,4.5,5],"boss":[300,58,18,2.0,9]}
	var stats: Array = specs.get(kind, specs.chaser)
	var data: Dictionary = definitions.get("enemies",{}).get(kind,{})
	stats = [data.get("hp",stats[0]),data.get("speed",stats[1]),data.get("damage",stats[2]),data.get("cooldown",stats[3]),[2,3,5,8,6,15][["chaser","skirmisher","sniper","rammer","runner","boss"].find(kind)] if kind in specs else 2]
	var pos := player + Vector2.from_angle(rng.randf_range(-PI, PI)) * rng.randf_range(330, 440)
	var hp_value := float(stats[0]) * (0.8 + strength * 0.2)
	if kind == "boss" and level.get("boss") != null: hp_value = float(level.boss.get("hp", hp_value))
	var e := {"pos":pos,"heading":(player-pos).angle(),"hp":hp_value,"max_hp":hp_value,"kind":kind,"speed":float(stats[1]) * minf(1.6, 0.9 + strength*0.1),"damage":float(stats[2]) * sqrt(strength),"cooldown":rng.randf_range(1.8, 4.0),"rate":float(stats[3]),"sprite":int(stats[4]),"radius":42.0 if kind == "boss" else 24.0,"flash":0.0,"phase":rng.randf_range(0, TAU)}
	e.cannon_count = int(data.get("cannon_count",1))
	e.coin_drop = int(data.get("coin_drop",2))
	e.score = int(data.get("score",100))
	e.pattern = "fan"
	if kind == "boss":
		var boss_data: Dictionary = level.get("boss",{}) if level.get("boss") is Dictionary else {}
		e.speed = float(boss_data.get("speed",e.speed))
		e.damage = float(boss_data.get("damage",e.damage))
		e.rate = float(boss_data.get("cooldown",e.rate))
		e.cannon_count = int(boss_data.get("cannon_count",3))
		e.pattern = str(boss_data.get("pattern",["broadside","charge","fan","spiral"][int(elapsed/90)%4]))
		e.score = int(boss_data.get("score",1500))
	enemies.append(e)
	return e

func _update_enemies(dt: float) -> void:
	for i in range(enemies.size()-1, -1, -1):
		var e: Dictionary = enemies[i]
		var offset: Vector2 = player - e.pos
		var distance := offset.length()
		if distance > 1050:
			enemies.remove_at(i)
			continue
		var angle := offset.angle()
		match e.kind:
			"skirmisher": angle += 0.9 * sin(elapsed * 1.4 + e.phase)
			"sniper":
				if distance < 280: angle += PI
				elif distance < 340: angle += PI/2
			"runner":
				if distance < 220: angle += PI
			"rammer": angle += 0.2 * sin(elapsed + e.phase)
			"boss":
				if e.pattern == "charge" and fmod(elapsed+e.phase,6.0) < 1.7:
					e.pos += Vector2.from_angle(e.heading)*dt*75
				elif distance < 230: angle += PI/2
		e.heading = rotate_toward(float(e.heading), angle, dt * (1.7 if e.kind == "boss" else 2.6))
		e.pos += Vector2.from_angle(e.heading) * float(e.speed) * dt
		e.flash = maxf(0, float(e.flash) - dt)
		e.cooldown -= dt
		if e.cooldown <= 0 and distance < 500 and e.kind != "runner":
			e.cooldown = e.rate
			var count := int(e.cannon_count)
			if e.kind == "boss" and e.pattern == "fan": count += 2
			for n in count:
				var fire_angle := offset.angle() + (float(n) - float(count-1)/2) * 0.14
				if e.kind == "boss":
					if e.pattern == "spiral": fire_angle = elapsed*1.5+float(n)*TAU/count
					elif e.pattern == "broadside": fire_angle = e.heading+(-PI/2 if n%2==0 else PI/2)
				_bullet(e.pos, Vector2.from_angle(fire_angle) * (180 if e.kind == "sniper" else 145), e.damage, false)
		if distance < e.radius + 23:
			_damage_player(e.damage)
			e.pos -= offset.normalized() * 28
			if e.kind == "rammer": _burst(e.pos, Color("ff975e"), 14)

func _side_target(side: int) -> Variant:
	var angle := heading + (-PI/2 if side == 0 else PI/2)
	var best: Variant = null
	var best_distance := 350.0
	for e in enemies:
		var offset: Vector2 = e.pos - player
		if offset.length() < best_distance and absf(angle_difference(angle, offset.angle())) < 0.9:
			best = e
			best_distance = offset.length()
	return best

func fire_side(side: int) -> bool:
	if not running or paused or cooldowns[side] > 0: return false
	cooldowns[side] = float(ship.get("cooldown", 1.1)) * (0.5 if rapid_time > 0 else 1.0)
	var angle := heading + (-PI/2 if side == 0 else PI/2)
	var target: Variant = _side_target(side)
	if target != null:
		var aim: Vector2 = target.pos - player
		angle = aim.angle()
	var count := int(ship.get("cannon_count", 3))
	var damage := float(ship.get("damage", 22))
	for n in count:
		var along := (float(n) - float(count-1)/2.0) * 13
		var origin := player + Vector2.from_angle(heading) * along + Vector2.from_angle(angle) * 26
		_bullet(origin, Vector2.from_angle(angle + (float(n)-float(count-1)/2)*0.045) * 390, damage, true, side)
		_burst(origin, Color("ffe2a0"), 5)
	shots += count
	_sound("cannon", rng.randf_range(0.92, 1.08))
	if not reduced_motion: shake = 2.2
	return true

func _bullet(pos: Vector2, vel: Vector2, damage: float, friendly: bool, side := -1) -> void:
	if bullets.size() >= MAX_BULLETS: return
	bullets.append({"pos":pos,"previous":pos,"vel":vel,"damage":damage,"friendly":friendly,"side":side,"life":1.5 if friendly else 3.4})

func _update_bullets(dt: float) -> void:
	for i in range(bullets.size()-1,-1,-1):
		var b: Dictionary = bullets[i]
		b.previous = b.pos
		b.pos += b.vel * dt
		b.life -= dt
		var hit := false
		if b.friendly:
			for e in enemies:
				var nearest := Geometry2D.get_closest_point_to_segment(e.pos, b.previous, b.pos)
				if e.hp > 0 and nearest.distance_to(e.pos) < e.radius + 5:
					e.hp -= b.damage
					e.flash = 0.15
					_burst(b.pos, Color("ffd080"), 6)
					hit = true
					if e.hp <= 0:
						if b.get("side",-1) >= 0: kills_by_side[b.side] += 1
						_sink(e)
					break
		else:
			var nearest := Geometry2D.get_closest_point_to_segment(player, b.previous, b.pos)
			if nearest.distance_to(player) < 24:
				_damage_player(b.damage)
				hit = true
		if hit or b.life <= 0 or b.pos.distance_to(player) > 1000: bullets.remove_at(i)
	for i in range(enemies.size()-1,-1,-1):
		if enemies[i].hp <= 0: enemies.remove_at(i)

func _sink(e: Dictionary) -> void:
	kills += 1
	combo += 1
	best_combo = maxi(combo, best_combo)
	combo_time = 5.0
	score += int(e.get("score",100)) * mini(combo, 8)
	if e.kind == "boss": bosses += 1
	_burst(e.pos, Color("ff9b4b"), 30 if e.kind == "boss" else 18)
	_sound("hit")
	if not reduced_motion: shake = 6.0 if e.kind == "boss" else 3.5
	for i in mini(12,int(e.get("coin_drop",2))): _drop(e.pos+Vector2.from_angle(i*2.4)*float(i)*4,"coin")
	if rng.randf() < 0.35 or e.kind == "boss":
		var pool := ["repair", "shield", "rapid", "magnet"]
		_drop(e.pos + Vector2(28,0), pool[rng.randi_range(0,3)])

func _drop(pos: Vector2, kind: String) -> void:
	if pickups.size() < MAX_PICKUPS: pickups.append({"pos":pos,"type":kind,"life":30.0})

func _damage_player(amount: float) -> void:
	if invincible_time > 0 or debug_invulnerable: return
	if shield_time > 0:
		_burst(player, Color("8ef5ff"), 10)
		invincible_time = 0.3
		return
	hp = maxf(0, hp - amount)
	damage_taken += amount
	invincible_time = 0.65
	flash = 0.22
	combo = 0
	_burst(player, Color("ff635f"), 14)
	_sound("hit")
	if OS.get_name()=="Android" and Progression.settings.get("haptics",true): Input.vibrate_handheld(40)
	if not reduced_motion: shake = 7

func _update_pickups(dt: float) -> void:
	for i in range(pickups.size()-1,-1,-1):
		var p: Dictionary = pickups[i]
		p.life -= dt
		var distance: float = p.pos.distance_to(player)
		var reach := float(ship.get("perk", {}).get("pickup_radius", 100.0))
		if distance < reach:
			p.pos = p.pos.move_toward(player, dt * 250)
		if distance < 30:
			match p.type:
				"coin":
					treasure += 1
					score += 60
					_sound("coin")
				"repair": hp = minf(max_hp, hp + max_hp * 0.3)
				"shield": shield_time = 8.0
				"rapid": rapid_time = 9.0
				"magnet":
					for coin in pickups:
						if coin.type == "coin" and coin.pos.distance_to(player) < 750: coin.pos = player + Vector2(rng.randf_range(-20,20),rng.randf_range(-20,20))
			if p.type != "coin":
				powerups += 1
				toast.emit({"repair":"HULL PATCHED +30%","shield":"BUBBLE SHIELD!","rapid":"DOUBLE-TIME CANNONS!","magnet":"TREASURE MAGNET!"}.get(p.type,"POWER UP!"))
				_sound("power")
			pickups.remove_at(i)
		elif p.life <= 0 or distance > 1200: pickups.remove_at(i)
	# Salvage missions always have attainable treasure even if a chest was missed.
	if level.get("objective", {}).get("type", "") == "coins" and pickups.size() < 6:
		_drop(player + Vector2.from_angle(rng.randf_range(-PI,PI))*rng.randf_range(150,280), "coin")
	if mode == "endless" and pickups.size() < 8 and rng.randf() < dt * 0.6:
		_drop(player + Vector2.from_angle(rng.randf_range(-PI,PI))*250, "coin")

func _update_hazards(dt: float) -> void:
	for h in hazards:
		h.tick = maxf(0, h.tick - dt)
		var offset: Vector2 = h.pos - player
		var active := true
		if h.type == "storm": active = fmod(elapsed+float(h.get("phase",0)),float(h.get("period",9))) < float(h.get("duration",2))
		if offset.length() < h.radius + 20 and active:
			match h.type:
				"current": player += Vector2(float(h.get("force",45)), 10) * dt
				"maelstrom": player += offset.normalized() * dt * float(h.get("force",60))
				_: pass
			if h.tick <= 0 and h.type != "current":
				_damage_player(h.damage)
				h.tick = 1.2
	# Islands repel ships softly; cannon combat remains forgiving near beaches.
	var coord := Vector2i(floori(player.x / chunk_size), floori(player.y / chunk_size))
	for x in range(coord.x-1,coord.x+2):
		for y in range(coord.y-1,coord.y+2):
			var island := _island(Vector2i(x,y))
			if island.is_empty(): continue
			var offset: Vector2 = player - island.pos
			if offset.length() < island.radius + 10:
				player = island.pos + offset.normalized() * (island.radius + 11)
				_damage_player(4)
	if island_cache.size() > 100:
		for key in island_cache.keys():
			if (Vector2(key) - Vector2(coord)).length() > 5: island_cache.erase(key)

func _island(coord: Vector2i) -> Dictionary:
	if island_cache.has(coord): return island_cache[coord]
	var local := RandomNumberGenerator.new()
	local.seed = hash(str(coord.x) + ":" + str(coord.y) + ":plunder:" + str(voyage_seed))
	var item := {}
	if local.randf() < 0.52 and coord != Vector2i.ZERO:
		item = {"pos":Vector2(coord)*chunk_size + Vector2(local.randf_range(90,chunk_size-100),local.randf_range(90,chunk_size-100)),"radius":local.randf_range(40,76),"trees":local.randi_range(2,4)}
	island_cache[coord] = item
	return item

func _particle(pos: Vector2, color: Color, velocity: Vector2, life: float, radius: float) -> void:
	if particles.size() < MAX_PARTICLES: particles.append({"pos":pos,"color":color,"vel":velocity,"life":life,"total":life,"radius":radius})

func _burst(pos: Vector2, color: Color, count: int) -> void:
	for i in count: _particle(pos, color.lerp(Color("fff3c4"),rng.randf()*0.4), Vector2.from_angle(rng.randf()*TAU)*rng.randf_range(20,115),rng.randf_range(0.25,0.7),rng.randf_range(2,6))

func _update_particles(dt: float) -> void:
	for i in range(particles.size()-1,-1,-1):
		var p: Dictionary = particles[i]
		p.life -= dt
		p.pos += p.vel * dt
		p.vel *= 1.0 - dt*1.5
		if p.life <= 0: particles.remove_at(i)

func _sound(key: String, pitch := 1.0) -> void:
	if muted or not sfx.has(key) or audio_pool.is_empty(): return
	var voice := audio_pool[audio_cursor % audio_pool.size()]
	audio_cursor += 1
	voice.stream = sfx[key]
	voice.pitch_scale = pitch
	voice.play()

func finish(won: bool) -> Dictionary:
	if not running: return {}
	running = false
	var stars := 0
	if won:
		stars = 1
		var targets: Dictionary = level.get("star_targets", {})
		if hp / max_hp >= float(targets.get("health", 0.5)): stars += 1
		if elapsed <= float(targets.get("time", 110)): stars += 1
	var summary := {"mode":mode,"level_id":int(level.get("id",1)),"ship_id":str(ship.get("id","swiftfin")),"won":won,"stars":stars,"score":score,"kills":kills,"bosses":bosses,"treasure":treasure,"seconds":elapsed,"damage_taken":damage_taken,"shots":shots,"powerups":powerups,"max_combo":best_combo,"both_sides_kills":mini(kills_by_side[0],kills_by_side[1]),"health_ratio":hp/max_hp,"reward":level.get("reward",{})}
	finished.emit(summary)
	return summary

func _draw() -> void:
	if ship == null or ship.is_empty(): return
	var size := screen_size()
	var water := Color(str(biome.get("colors", {}).get("water", "#087e98")))
	draw_rect(Rect2(Vector2.ZERO,size),water)
	# A single tiled wave texture keeps the moving ocean cheap on mobile GPUs.
	var wave_offset := Vector2(-posmod(player.x*0.22,144),-posmod(player.y*0.22,140))
	draw_texture_rect(textures.waves,Rect2(wave_offset,size+Vector2(144,140)),true)
	var coord := Vector2i(floori(player.x/chunk_size),floori(player.y/chunk_size))
	for x in range(coord.x-2,coord.x+3):
		for y in range(coord.y-2,coord.y+3):
			var island := _island(Vector2i(x,y))
			if not island.is_empty(): _draw_island(island)
	for h in hazards:
		var p := world_screen(h.pos)
		var active: bool = h.type != "storm" or fmod(elapsed+float(h.get("phase",0)),maxf(1,float(h.get("period",9)))) < float(h.get("duration",2))
		var color := Color("e97f52") if h.type == "mine" else (Color("fff09e") if h.type=="storm" and active else Color("93c4ba"))
		draw_circle(p, h.radius+8, Color(color,0.12))
		if h.type == "maelstrom" or h.type == "current" or h.type == "storm":
			for j in 4: draw_arc(p,h.radius-float(j)*8,elapsed+j,elapsed+j+4.6,24,Color("9fdfe3"),2,true)
		else:
			draw_circle(p,h.radius*0.55,Color("415e65"))
			draw_circle(p+Vector2(-8,-10),h.radius*0.3,color)
			if h.type == "mine":
				for j in 8: draw_line(p+Vector2.from_angle(j*PI/4)*22,p+Vector2.from_angle(j*PI/4)*32,Color("ffad78"),5,true)
	for p in pickups:
		var location := world_screen(p.pos) + Vector2(0,sin(elapsed*4+p.pos.x)*3)
		if location.y > size.y-248: continue
		var colors := {"coin":"#ffd166","repair":"#78eda4","shield":"#80deff","rapid":"#ffb075","magnet":"#cd9dff"}
		var c := Color(colors.get(p.type,"#ffffff"))
		draw_circle(location,17,Color(0.02,0.2,0.24,0.25))
		draw_circle(location,12,c)
		draw_arc(location,9,0,TAU,16,Color("fff5c9"),2,true)
		if p.type == "repair":
			draw_line(location-Vector2(6,0),location+Vector2(6,0),Color("186354"),4)
			draw_line(location-Vector2(0,6),location+Vector2(0,6),Color("186354"),4)
		elif p.type == "coin": draw_line(location-Vector2(0,5),location+Vector2(0,5),Color("bc7736"),3)
		else: draw_circle(location,4,Color("ffffff"))
	for p in particles:
		var c: Color = p.color
		c.a *= maxf(0,p.life/p.total)
		var position := world_screen(p.pos)
		if position.x < -20 or position.x > size.x+20 or position.y < -20 or position.y > size.y-220: continue
		var radius: float = p.radius * (0.4 + p.life/p.total*0.6)
		draw_texture_rect(textures.particle,Rect2(position-Vector2.ONE*radius,Vector2.ONE*radius*2),false,c)
	for e in enemies:
		_draw_ship(world_screen(e.pos),e.heading,int(e.sprite),90 if e.kind == "boss" else 62,Color("ffffff") if e.flash > 0 else Color("ffd7c2"))
		var p := world_screen(e.pos) + Vector2(-24,-48 if e.kind == "boss" else -36)
		draw_rect(Rect2(p,Vector2(48,5)),Color("153c4b"))
		draw_rect(Rect2(p,Vector2(48*maxf(0,e.hp/e.max_hp),5)),Color("ff826c"))
	for b in bullets:
		var p := world_screen(b.pos)
		draw_line(p,p-b.vel.normalized()*12,Color("fff2b0") if b.friendly else Color("ff9e72"),3,true)
		draw_circle(p,4 if b.friendly else 5,Color("fff7d5") if b.friendly else Color("ff6b5d"))
	var center := camera_center()
	if not reduced_motion: center += Vector2(sin(elapsed*80),cos(elapsed*91))*shake
	var player_sprite := int(ship.get("sprite",4))
	if hp < max_hp*0.35: player_sprite += 12
	elif hp < max_hp*0.65: player_sprite += 6
	_draw_ship(center,heading,player_sprite,74,Color("ffb5a4") if flash > 0 else Color.WHITE)
	if shield_time > 0: draw_arc(center,48,0,TAU,40,Color("9afaff"),3,true)
	if hp < max_hp*0.35 and int(elapsed*8)%2 == 0:
		draw_circle(center+Vector2(12,12),9,Color("ffad58"))
		draw_circle(center+Vector2(10,19),5,Color("ff5b50"))
	_draw_controls()
	if flash > 0: draw_rect(Rect2(Vector2.ZERO,size),Color(1,0.2,0.15,flash*0.4))

func _draw_ship(pos: Vector2, angle: float, sprite_id: int, length: float, tint: Color) -> void:
	var texture: Texture2D = textures.get("ship%d" % sprite_id)
	if texture == null: return
	var dimensions := texture.get_size()
	var extent := dimensions / dimensions.y * length
	draw_set_transform(pos+Vector2(4,5),angle-PI/2)
	draw_texture_rect(texture,Rect2(-extent/2,extent),false,Color(0.02,0.15,0.2,0.28))
	draw_set_transform(pos,angle-PI/2)
	draw_texture_rect(texture,Rect2(-extent/2,extent),false,tint)
	draw_set_transform(Vector2.ZERO)

func _draw_island(island: Dictionary) -> void:
	var p := world_screen(island.pos)
	var r: float = island.radius
	if p.x < -r*2 or p.x > screen_size().x+r*2 or p.y < -r*2 or p.y > screen_size().y+r*2: return
	var sand := Color(str(biome.get("colors",{}).get("sand","#f6d998")))
	var grasses := {"sunlit_shoals":"#68b874","mangrove_maze":"#40785a","ember_archipelago":"#62514d","frostwake_reach":"#bde2dc","tempest_crown":"#796691"}
	var grass := Color(str(grasses.get(biome.get("id",""),"#68b874")))
	draw_circle(p,r+17,Color(0.5,0.9,0.85,0.18))
	draw_circle(p,r+9,Color("80d5c4"))
	draw_circle(p,r,sand)
	# Reuse the supplied seamless sand tiles and palm sprites, tinting for each biome.
	var tile_ids := [1,2,3,17,18,19,33,34,35]
	var tile_side := r*0.63
	for i in 9:
		var tex: Texture2D = textures.get("tile%d" % tile_ids[i])
		if tex != null: draw_texture_rect(tex,Rect2(p+Vector2(i%3-1,i/3-1)*tile_side-Vector2.ONE*tile_side/2,Vector2.ONE*tile_side),false,sand.lightened(0.12))
	draw_circle(p+Vector2(4,-4),r*0.72,grass)
	for i in int(island.trees):
		var tree := p + Vector2.from_angle(i*2.4)*r*0.42
		var palm: Texture2D = textures.get("tile%d" % (70+i%3))
		if palm != null:
			draw_texture_rect(palm,Rect2(tree-Vector2(22,28),Vector2(44,50)),false,Color.WHITE if biome.get("id","")!="frostwake_reach" else Color("c6efdf"))
			continue
		draw_line(tree+Vector2(2,12),tree,Color("986a43"),7,true)
		for j in 5:
			var tip := tree+Vector2.from_angle(j*TAU/5)*20
			draw_line(tree+Vector2(2,2),tip+Vector2(2,2),Color(0.02,0.25,0.18,0.2),9,true)
			draw_line(tree,tip,grass.lightened(0.18),6,true)
			draw_circle(tip,5,grass.lightened(0.18))

func _draw_controls() -> void:
	var size := screen_size()
	draw_rect(Rect2(0,size.y-232,size.x,232),Color(0.015,0.12,0.18,0.88))
	draw_line(Vector2(0,size.y-232),Vector2(size.x,size.y-232),Color(0.42,0.83,0.83,0.28),2)
	var center := wheel_center()
	draw_circle(center+Vector2(0,5),81,Color("071e2b"))
	draw_circle(center,77,Color("684733"))
	draw_arc(center,68,0,TAU,60,Color("e4ab61"),10,true)
	draw_arc(center,57,0,TAU,60,Color("352a28"),4,true)
	for i in 8:
		var a := float(i)*PI/4 + heading + PI/2
		var direction := Vector2.from_angle(a)
		draw_line(center+direction*17,center+direction*85,Color("946339"),9,true)
		draw_line(center+direction*22,center+direction*82,Color("e4b578"),4,true)
		draw_circle(center+direction*85,6,Color("edbf7d"))
	draw_circle(center,23,Color("c69452"))
	draw_circle(center,16,Color("ffe1a0"))
	var arrow := wheel_vector if wheel_pointer >= 0 else Vector2.from_angle(heading)
	draw_line(center,center+arrow*38,Color("fff1c3"),4,true)
	for side in 2:
		var p := fire_center(side)
		var ready: bool = cooldowns[side] <= 0
		draw_circle(p+Vector2(0,5),55,Color("081b28"))
		draw_circle(p,53,Color("bf6444") if ready else Color("3b5661"))
		draw_arc(p,50,-PI/2,-PI/2+TAU*(1.0-minf(1,cooldowns[side]/float(ship.get("cooldown",1.1)))),40,Color("ffd48a"),4,true)
		draw_set_transform(p,PI-0.2 if side == 0 else 0.2)
		draw_texture_rect(textures.cannon,Rect2(-27,-15,54,30),false,Color("ffedc4"))
		draw_set_transform(Vector2.ZERO)
