extends SceneTree
## Actual runtime contracts plus finite campaign/manual-control feasibility.
## Test-only progression path; no run is recorded into the player's save.
const STEP := 0.05
var ArenaScript: GDScript
var campaign: Dictionary = {}
var ships: Array = []
var checks := 0
var failures := 0
var contract_failures: Array[String] = []
var matrix: Array[Dictionary] = []
var normal_runs: Array[Dictionary] = []
var navigation_runs: Array[Dictionary] = []
var quick := false
var peak_endless: Dictionary = {}
var started_usec := 0

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		contract_failures.append(label)
		printerr("FAIL: "+label)

func _biome(id: String) -> Dictionary:
	for item in campaign.biomes:
		if item.id==id: return item
	return campaign.biomes[0]

func _arena(ship_index:=0,level_id:=1,mode:="campaign"):
	var a=ArenaScript.new()
	root.add_child(a)
	var ship: Dictionary=ships[ship_index].duplicate(true)
	var stage: Dictionary=campaign.levels[level_id-1].duplicate(true)
	if mode!="campaign":
		stage={"id":0,"name":"Open Sea Test","biome":campaign.endless.starting_biome,"objective":{"type":"survive","target":90},"duration_limit":100,"endless":campaign.endless,"enemy_pool":campaign.endless.enemy_pool,"boss":null,"enemy_strength":1.0}
	a.start_run(ship,stage,_biome(stage.biome),mode)
	a.set_process(false)
	a.muted=true
	a.reduced_motion=true
	return a

func _dispose(a) -> void:
	root.remove_child(a)
	a.free()

func _isolated(a) -> void:
	a.enemies.clear(); a.bullets.clear(); a.pickups.clear(); a.hazards.clear(); a.particles.clear()
	a.authored_islands.clear(); a.campaign_encounters.clear(); a.bot_navigation.clear()
	a.campaign_bounds=Rect2(-1000,-1000,2000,2000)
	a.campaign_total_ships=999; a.encounter_index=0; a.encounter_wait=-1.0
	a.player=Vector2.ZERO; a.heading=-PI/2; a.desired_heading=a.heading
	a.ship.speed=0.0; a.assisted=false; a.automated=false; a.debug_invulnerable=true
	a.cooldowns=[0.0,0.0]; a.secondary_cooldowns=[0.0,0.0]
	a._build_navigation()

func _target(a,pos: Vector2) -> Dictionary:
	var enemy: Dictionary=a.spawn_enemy("chaser",pos)
	enemy.speed=0.0; enemy.cooldown=999.0; enemy.hp=1000.0; enemy.max_hp=1000.0
	return enemy

func _controls() -> void:
	var progress=root.get_node("Progression")
	progress.settings.auto_fire=true
	var a=_arena()
	_isolated(a)
	_target(a,Vector2(-180,0))
	a.assisted=true
	for i in 25: a.step(STEP)
	_check(a.shots==0 and not a.assisted,"legacy auto-fire preference/direct assisted flag cannot grant ownership")
	_check(not a.set_primary_assist(true),"locked primary automation rejects settings toggle")
	a.ship.cannons_port=4; a.ship.cannons_starboard=1
	_check(a.fire_side(0),"manual port broadside fires")
	_check(a.shots==4 and a.cooldowns[0]>0 and a.cooldowns[1]==0,"asymmetric port count and independent cooldown")
	_check(not a.fire_side(0) and a.fire_side(1),"starboard remains usable during port reload")
	_check(a.shots==5,"starboard uses its own one-cannon loadout")
	_check(not a.fire_side(-1) and not a.fire_side(2),"invalid side cannot index weapon arrays")
	a.paused=true
	var elapsed: float=a.elapsed
	a.step(STEP)
	_check(a.elapsed==elapsed and not a.fire_side(0),"pause suspends movement and weapons")
	a.paused=false
	a.cooldowns=[0.0,0.0]
	a._pointer(1,a.wheel_center()+Vector2.RIGHT*55,true)
	a._pointer(2,a.fire_center(0),true)
	a._pointer(3,a.fire_center(1),true)
	_check(a.wheel_pointer==1 and a.fire_pointers.size()==2,"wheel and two manual cannon touches coexist")
	_check(absf(a.desired_heading)<0.01,"wheel drag points the ship")
	a.paused=true
	_check(a.wheel_pointer==-1 and a.fire_pointers.is_empty(),"pausing releases held controls rather than leaving a firing finger stuck")
	a.paused=false
	for pointer in [1,2,3]: a._pointer(pointer,Vector2.ZERO,false)
	_check(a.wheel_pointer==-1 and a.fire_pointers.is_empty(),"released primary fingers clear ownership")
	a._pointer(42,a.fire_center(0),true)
	var release:=InputEventScreenTouch.new()
	release.index=42; release.position=Vector2(500,35); release.pressed=false
	root.push_input(release,true)
	_check(not a.fire_pointers.has(42),"touch release routed through _input clears a fire finger above UI")
	a._pointer(99,a.fire_center(1),true)
	var mouse_release:=InputEventMouseButton.new()
	mouse_release.button_index=MOUSE_BUTTON_LEFT; mouse_release.pressed=false; mouse_release.position=Vector2(500,35)
	root.push_input(mouse_release,true)
	_check(not a.fire_pointers.has(99),"mouse release routed through _input clears a held cannon")
	a.heading=-PI/2; a.desired_heading=a.heading; a.cooldowns=[0.0,0.0]
	a.ship.primary_auto=true
	_check(a.set_primary_assist(true),"purchased primary automation can be enabled")
	var before: int=a.shots
	a.step(STEP)
	_check(a.shots>before,"purchased primary automation uses a broadside target")
	a.set_primary_assist(false)
	before=a.shots
	for i in 5: a.step(STEP)
	_check(a.shots==before,"purchased automatic fire can still be disabled")
	progress.settings.auto_fire=false
	_dispose(a)

func _secondary_contract() -> void:
	var a=_arena()
	_isolated(a)
	_check(not a.secondary_fire(0) and not a.secondary_fire(1),"unowned secondary weapons stay locked")
	a.ship.secondary_port=true; a.ship.secondary_starboard=false
	a.ship.secondary_count=3; a.ship.secondary_damage=32.0; a.ship.secondary_cooldown=3.8
	a.ship.secondary_speed=245.0; a.ship.secondary_spread=0.24; a.ship.secondary_radius=7.0
	_check(a.secondary_fire(0),"purchased port secondary is manually usable")
	_check(a.bullets.size()==3 and a.bullets[0].secondary and a.bullets[0].radius==7,"secondary fires a distinct heavy three-shot fan")
	_check(a.cooldowns==[0.0,0.0] and a.secondary_cooldowns[0]>0 and a.secondary_cooldowns[1]==0,"secondary reload is separate from both primary reloads")
	_check(not a.secondary_fire(0) and not a.secondary_fire(1),"secondary ownership and cooldown are enforced per side")
	a.ship.secondary_starboard=true
	_check(a.secondary_fire(1),"starboard secondary is independent of port cooldown")
	a.secondary_cooldowns=[0.0,0.0]
	a._pointer(21,a.secondary_center(0),true)
	a._pointer(22,a.secondary_center(1),true)
	_check(a.secondary_pointers.size()==2,"two auxiliary touches have independent pointer ownership")
	a.paused=true
	_check(a.secondary_pointers.is_empty(),"pause clears held auxiliary controls")
	a.paused=false
	a._pointer(21,Vector2.ZERO,false); a._pointer(22,Vector2.ZERO,false)
	_check(a.secondary_pointers.is_empty(),"secondary touches release cleanly")
	a.enemies.clear(); a.bullets.clear(); a.secondary_cooldowns=[0.0,0.0]
	_target(a,Vector2(-180,0)); _target(a,Vector2(180,0))
	var before: int=a.shots
	for i in 4: a.step(STEP)
	_check(a.shots==before,"secondary remains manual before its automation upgrade")
	a.ship.secondary_auto_port=true
	a.step(STEP)
	_check(a.shots==before+3 and a.secondary_cooldowns[1]==0 and a.cooldowns==[0.0,0.0],"purchased port auxiliary auto does not grant starboard or primary automation")
	a.ship.secondary_auto_starboard=true
	a.step(STEP)
	_check(a.shots==before+6,"purchased starboard auxiliary auto works independently")
	_dispose(a)

func _combat() -> void:
	var a=_arena()
	_isolated(a)
	var enemy: Dictionary=_target(a,Vector2.ZERO)
	enemy.hp=100; enemy.max_hp=100
	a._bullet(Vector2(-100,0),Vector2(1000,0),35,true)
	a._update_bullets(0.2)
	_check(enemy.hp==65,"swept cannon collision detects a ship crossed between frames")
	enemy.hp=10
	a._bullet(Vector2(-100,0),Vector2(1000,0),35,true)
	a._update_bullets(0.2)
	_check(a.kills==1 and a.enemies.is_empty(),"lethal hit sinks one authored ship once")
	_check(a.pickups.size()>0,"sunken fleet leaves finite loot")
	a.debug_invulnerable=false; a.invincible_time=0
	a._bullet(Vector2(-100,0),Vector2(1000,0),10,false)
	a._update_bullets(0.2)
	_check(a.hp==a.max_hp-10,"hostile projectile damages hull")
	var hull: float=a.hp
	a._damage_player(50)
	_check(a.hp==hull,"hit grace prevents stacked instant damage")
	a.invincible_time=0; a.shield_time=2
	a._damage_player(20)
	_check(a.hp==hull,"shield absorbs damage")
	a.authored_islands.clear()
	a.authored_islands.append({"pos":Vector2.ZERO,"radius":70.0,"trees":1})
	a.bullets.clear()
	a._bullet(Vector2(-150,0),Vector2(1000,0),20,true)
	a._update_bullets(0.3)
	_check(a.bullets.is_empty(),"land blocks swept cannon fire as cover")
	_dispose(a)

func _finite_encounters() -> void:
	var a=_arena()
	var stage: Dictionary={"id":1,"name":"Finite Contract","biome":campaign.biomes[0].id,"objective":{"type":"fleet","target":3},"duration_limit":0.1,"layout":{"bounds":[-700,-700,1400,1400],"player_spawn":[0,300],"player_heading":-PI/2,"islands":[],"hazards":[],"pickups":[{"pos":[400,400],"type":"coin"}]},"encounters":[{"id":"first","name":"Opening pair","delay":0,"ships":[{"id":"first_ship","kind":"chaser","pos":[0,-300],"heading":PI/2}]},{"id":"last","name":"Last fleet","delay":2,"ships":[{"id":"second_ship","kind":"chaser","pos":[-200,-350],"heading":PI/2},{"id":"last_boss","kind":"boss","pos":[200,-350],"heading":PI/2}]}],"boss":{"hp":200,"speed":58,"damage":10,"cooldown":2,"cannon_count":2,"pattern":"fan"},"reward":{},"star_targets":{"time":80,"health":0.5}}
	a.start_run(ships[0],stage,campaign.biomes[0],"campaign")
	a.set_process(false); a.muted=true; a.ship.speed=0; a.debug_invulnerable=true
	_check(a.campaign_total_ships==3 and a.campaign_deployed_count==1 and a.enemies.size()==1,"only the first authored fleet is initially deployed")
	_check(a.player==Vector2(0,300) and a.island_cache.is_empty(),"campaign uses authored spawn without procedural islands")
	var pickups: int=a.pickups.size()
	a.elapsed=800
	a._update_spawns(500)
	a.step(STEP)
	_check(a.enemies.size()==1 and a.campaign_deployed_count==1 and a.running,"elapsed time cannot add enemies, duplicate boss, or expire a campaign")
	_check(a.pickups.size()==pickups,"campaign does not replenish random supplies")
	a.enemies[0].pos=Vector2(5000,5000)
	a._update_enemies(0)
	_check(a.enemies.size()==1,"distant authored enemies are never despawned")
	for enemy in a.enemies: a._sink(enemy)
	a.enemies.clear()
	a.step(STEP)
	_check(a.running and a.encounter_index==1,"clearing an early fleet cannot win before future fleets")
	for i in 20: a.step(STEP)
	_check(a.enemies.is_empty(),"next fleet respects its authored two-second delay")
	for i in 21: a.step(STEP)
	_check(a.enemies.size()==2 and a.encounter_index==2 and a.campaign_deployed_count==3,"remaining finite fleet deploys exactly once after delay")
	var bosses:=0
	for enemy in a.enemies:
		if enemy.kind=="boss": bosses+=1
	_check(bosses==1,"boss is authored once in its final fleet")
	var output: Array=[]
	a.finished.connect(func(summary: Dictionary): output.append(summary))
	for enemy in a.enemies: a._sink(enemy)
	a.enemies.clear(); a.step(STEP)
	_check(not a.running and output.size()==1 and output[0].won and output[0].kills==3,"victory requires every authored ship and all encounters")
	_check(a.campaign_deployed_count==a.campaign_total_ships,"deployed count stays equal to authored total")
	_dispose(a)

func _geometry() -> void:
	var a=_arena()
	_isolated(a)
	a.authored_islands.clear()
	a.authored_islands.append({"pos":Vector2.ZERO,"radius":100.0,"trees":2})
	a.campaign_bounds=Rect2(-600,-600,1200,1200)
	a.ship.speed=130.0
	a._build_navigation()
	var swept: Vector2=a._move_ship(Vector2(-300,0),Vector2(600,0),23)
	_check(swept.x < -122 and a._water_point(swept,23),"fast player motion cannot tunnel through an island")
	_check(a._segment_clear(swept,swept+Vector2(-90,0),29),"a ship touching shore can escape its navigation safety margin")
	_check(not a._segment_clear(swept,swept+Vector2(90,0),29),"shoreline escape does not permit inward travel through land")
	var boundary: Vector2=a._move_ship(Vector2(550,500),Vector2(5000,2000),23)
	_check(a.campaign_bounds.grow(-23).has_point(boundary),"player remains inside the authored map")
	for kind in ["chaser","skirmisher","sniper","rammer","runner","boss"]:
		a.enemies.clear()
		a.player=Vector2(420,0) if kind!="runner" else Vector2(0,450)
		var e: Dictionary=a.spawn_enemy(kind,Vector2(-360,0),{"heading":0,"patrol":[[350,0]]})
		e.cooldown=999; e.spawn_grace=999
		var clear:=true
		var best_x: float=e.pos.x
		for frame in 800:
			a.elapsed+=STEP
			a._update_enemies(STEP)
			clear=clear and a._water_point(e.pos,float(e.radius)-0.1)
			best_x=maxf(best_x,e.pos.x)
		_check(clear,"%s never overlaps land or leaves bounds" % kind)
		_check(best_x>70,"%s navigates around the blocking island instead of shoreline jamming" % kind)
		navigation_runs.append({"kind":kind,"water_clear":clear,"best_x":best_x})
	_dispose(a)

func _voyage(ship_index: int,level_id: int,invulnerable: bool) -> Dictionary:
	var a=_arena(ship_index,level_id)
	a.automated=true; a.debug_invulnerable=invulnerable
	var output: Array=[]
	a.finished.connect(func(summary: Dictionary): output.append(summary))
	for frame in ceili(240.0/STEP):
		if not a.running: break
		a.step(STEP)
	var result: Dictionary=output[0].duplicate(true) if not output.is_empty() else {"won":false,"seconds":a.elapsed,"kills":a.kills,"health_ratio":a.hp/a.max_hp}
	result.ship_id=ships[ship_index].id; result.level_id=level_id
	result.invulnerable=invulnerable; result.assisted=a.assisted
	result.authored_total=a.campaign_total_ships; result.deployed=a.campaign_deployed_count
	result.manual_controls=true; result.max_entities=a.peak_entities
	if not result.won:
		result.remaining=[]
		for enemy in a.enemies: result.remaining.append({"kind":enemy.kind,"hp":enemy.hp,"pos":enemy.pos,"heading":enemy.heading})
		result.player=a.player; result.heading=a.heading; result.shots=a.shots
	_dispose(a)
	return result

func _campaign_matrix() -> void:
	var ids: Array=[1,3,10,20,30,40,50] if quick else range(1,51)
	var selected_ship:=-1
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--level="): ids=[int(arg.trim_prefix("--level="))]
		if arg.begins_with("--ship="):
			for i in ships.size():
				if ships[i].id==arg.trim_prefix("--ship="): selected_ship=i
	for ship_index in ships.size():
		if selected_ship>=0 and ship_index!=selected_ship: continue
		var wins:=0
		for id in ids:
			var result:=_voyage(ship_index,id,true)
			matrix.append(result)
			wins+=1 if result.won else 0
			_check(not result.assisted,"manual feasibility bot never enables primary automation")
			if not result.won: printerr("BOT_TIMEOUT "+JSON.stringify(result))
		_check(wins==ids.size(),"manual-control feasibility clears every tested finite level with "+str(ships[ship_index].id))
		print("FINITE_MATRIX ship=%s wins=%d/%d" % [ships[ship_index].id,wins,ids.size()])
	for ship_index in ships.size():
		if "--matrix-only" in OS.get_cmdline_user_args(): break
		for id in [1,2,3]:
			var result:=_voyage(ship_index,id,false)
			normal_runs.append(result)
			_check(result.won,"normal-hull manual bot clears opening level%d with %s" % [id,result.ship_id])

func _endless() -> void:
	var a=_arena(0,1,"endless")
	a.automated=true; a.debug_invulnerable=true; a.rng.seed=557901
	var maxima: Dictionary={"enemies":0,"bullets":0,"particles":0,"pickups":0,"islands":0,"geometry":0}
	for frame in ceili((180.0 if quick else 1200.0)/STEP):
		a.step(STEP)
		for key in ["enemies","bullets","particles","pickups"]: maxima[key]=maxi(int(maxima[key]),a.get(key).size())
		maxima.islands=maxi(int(maxima.islands),a.island_cache.size())
		maxima.geometry=maxi(int(maxima.geometry),a.geometry_cache.size())
	_check(a.running,"endless remains active after sustained simulation")
	_check(maxima.enemies<=int(campaign.endless.max_enemies_cap),"endless fleet remains capped")
	_check(maxima.bullets<=a.MAX_BULLETS and maxima.particles<=a.MAX_PARTICLES and maxima.pickups<=a.MAX_PICKUPS,"endless transient objects remain capped")
	_check(maxima.islands<=120 and maxima.geometry<=65,"infinite geometry caches remain bounded")
	var coord:=Vector2i(8,9)
	var first: Dictionary=a._island(coord).duplicate(true)
	a.island_cache.erase(coord)
	_check(a._island(coord)==first,"infinite geography regenerates deterministically")
	peak_endless={"seconds":a.elapsed,"maxima":maxima,"kills":a.kills}
	_dispose(a)
	var daily=_arena(0,1,"daily")
	daily.debug_invulnerable=true; daily.automated=true
	for frame in ceili(95.0/STEP):
		if not daily.running: break
		daily.step(STEP)
	_check(not daily.running and daily.elapsed>=90 and daily.kills>0,"daily retains timed procedural challenge separately from finite campaign")
	_dispose(daily)

func _run() -> void:
	started_usec=Time.get_ticks_usec()
	quick="--quick" in OS.get_cmdline_user_args()
	var progress=root.get_node("Progression")
	progress.save_path="res://tests/.game-suite-save.json"
	progress.reset_data("finite-game-suite")
	progress.settings.sfx=false; progress.settings.music=false; progress.settings.auto_fire=false
	campaign=JSON.parse_string(FileAccess.get_file_as_string("res://data/campaign.json"))
	ships=JSON.parse_string(FileAccess.get_file_as_string("res://data/ships.json")).ships
	ArenaScript=load("res://scripts/arena.gd")
	if ArenaScript==null or not ArenaScript.can_instantiate():
		printerr("FAIL: Arena script must compile")
		quit(1)
		return
	if "--matrix-only" not in OS.get_cmdline_user_args() and "--endless-only" not in OS.get_cmdline_user_args(): _controls(); _secondary_contract(); _combat(); _finite_encounters(); _geometry()
	if "--endless-only" in OS.get_cmdline_user_args(): _endless()
	elif "--contracts-only" not in OS.get_cmdline_user_args():
		_campaign_matrix()
		if "--matrix-only" not in OS.get_cmdline_user_args(): _endless()
	var wins:=0
	for result in matrix: wins+=1 if result.won else 0
	var normal_wins:=0
	for result in normal_runs: normal_wins+=1 if result.won else 0
	var report: Dictionary={"checks":checks,"failures":failures,"contract_failures":contract_failures,"campaign_passes":wins,"campaign_runs":matrix.size(),"normal_passes":normal_wins,"normal_runs":normal_runs.size(),"navigation":navigation_runs,"endless":peak_endless,"wall_seconds":(Time.get_ticks_usec()-started_usec)/1000000.0,"manual_controls":true,"matrix":matrix}
	DirAccess.make_dir_recursive_absolute("res://tests/output")
	var file:=FileAccess.open("res://tests/output/game-tests.json",FileAccess.WRITE)
	if file!=null: file.store_string(JSON.stringify(report,"  "))
	print("GAME_TEST_SUMMARY "+JSON.stringify({"checks":checks,"failures":failures,"campaign_passes":wins,"campaign_runs":matrix.size(),"normal_passes":normal_wins,"normal_runs":normal_runs.size(),"navigation":navigation_runs,"endless":peak_endless,"wall_seconds":report.wall_seconds}))
	for suffix in ["",".tmp",".bak"]:
		var path: String="res://tests/.game-suite-save.json"+str(suffix)
		if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	quit(1 if failures>0 else 0)
