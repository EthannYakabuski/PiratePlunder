extends SceneTree
## Observational balance sample using actual purchased mid-tier loadouts.
## Run after the authoritative game suite; no results are recorded to a profile.
const ProgressionScript = preload("res://scripts/progression.gd")
const STEP := 0.05
const CASES := [{"level":20,"rank":7},{"level":30,"rank":9},{"level":40,"rank":11},{"level":50,"rank":13}]
var ArenaScript: GDScript
var campaign: Dictionary = {}
var ships: Array = []
var checks := 0
var failures := 0
var observations: Array[Dictionary] = []

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		printerr("FAIL: "+label)

func _biome(id: String) -> Dictionary:
	for biome in campaign.biomes:
		if biome.id==id: return biome
	return campaign.biomes[0]

func _observe(ship: Dictionary,level_id: int,rank: int) -> void:
	var profile=ProgressionScript.new()
	var identity: String="balance-%s-%d" % [ship.id,level_id]
	profile.save_path="res://tests/."+identity+".json"
	profile._load_definitions()
	profile.reset_data(identity)
	var step: int=int(ship.progression.xp_per_rank)
	profile.data.devices[identity].ship_xp[ship.id]=int(step*(rank-1)*rank/2)
	profile.data.devices[identity].metrics.coins_collected=20000
	profile.settings.auto_fire=false
	profile.settings.music=false
	profile.settings.sfx=false
	var owned: Array[String]=[]
	for upgrade in profile.upgrades:
		if int(upgrade.required_rank)>rank: continue
		var purchase: Dictionary=profile.purchase_upgrade(ship.id,upgrade.id)
		_check(purchase.success,"rank%d %s can purchase %s" % [rank,ship.id,upgrade.id])
		if purchase.success: owned.append(str(upgrade.id))
	var loadout: Dictionary=profile.ship_loadout(ship.id)
	_check(loadout.rank==rank,"loadout uses the intended ship rank")
	_check(not loadout.primary_auto and not loadout.secondary_auto_port and not loadout.secondary_auto_starboard,"mid-tier sample has no weapon automation")
	var stage: Dictionary=campaign.levels[level_id-1]
	var arena=ArenaScript.new()
	root.add_child(arena)
	arena.start_run(loadout,stage,_biome(stage.biome),"campaign")
	arena.set_process(false)
	arena.muted=true
	arena.reduced_motion=true
	arena.automated=true
	arena.debug_invulnerable=false
	var output: Array=[]
	arena.finished.connect(func(summary: Dictionary): output.append(summary.duplicate(true)))
	for frame in ceili(240.0/STEP):
		if not arena.running: break
		arena.step(STEP)
	var outcome: Dictionary=output[0] if not output.is_empty() else {"won":false,"seconds":arena.elapsed,"health_ratio":arena.hp/arena.max_hp,"kills":arena.kills,"damage_taken":arena.damage_taken,"powerups":arena.powerups,"shots":arena.shots}
	_check(not arena.assisted and not arena.debug_invulnerable,"sample remains manual and damage-enabled")
	_check(profile.data.recent_runs.is_empty() and profile.data.levels.is_empty(),"observational voyages never update profile runs or campaign progress")
	var nearby: Array=[]
	for hazard in arena.hazards:
		if arena.player.distance_to(hazard.pos)<float(hazard.radius)+60:
			nearby.append({"type":hazard.type,"distance":arena.player.distance_to(hazard.pos),"radius":hazard.radius})
	observations.append({"ship_id":ship.id,"ship_name":ship.name,"level_id":level_id,"level_name":stage.name,"rank":rank,"won":outcome.won,"result":"win" if outcome.won else ("defeat" if not arena.running else "timeout"),"seconds":outcome.seconds,"health_ratio":outcome.health_ratio,"hp_remaining":arena.hp,"max_hp":arena.max_hp,"damage_taken":outcome.damage_taken,"kills":outcome.kills,"authored_total":arena.campaign_total_ships,"deployed":arena.campaign_deployed_count,"powerups":outcome.powerups,"shots":outcome.shots,"cannons_port":loadout.cannons_port,"cannons_starboard":loadout.cannons_starboard,"secondary_port":loadout.secondary_port,"secondary_starboard":loadout.secondary_starboard,"primary_cooldown":loadout.cooldown,"secondary_cooldown":loadout.secondary_cooldown,"upgrades":owned,"gold_spent":profile.gold_spent(),"manual_controls":true,"damage_enabled":true,"nearby_hazards_at_end":nearby})
	print("BALANCE_OBSERVATION "+JSON.stringify(observations[-1]))
	root.remove_child(arena)
	arena.free()
	for suffix in ["",".tmp",".bak"]:
		var path: String=profile.save_path+str(suffix)
		if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	profile.free()

func _run() -> void:
	var started:=Time.get_ticks_usec()
	campaign=JSON.parse_string(FileAccess.get_file_as_string("res://data/campaign.json"))
	ships=JSON.parse_string(FileAccess.get_file_as_string("res://data/ships.json")).ships
	ArenaScript=load("res://scripts/arena.gd")
	if ArenaScript==null or not ArenaScript.can_instantiate():
		printerr("FAIL: Arena script must compile before balance observations")
		quit(1)
		return
	for item in CASES:
		for ship in ships: _observe(ship,int(item.level),int(item.rank))
	var wins:=0
	for item in observations: wins+=1 if item.won else 0
	var report: Dictionary={"date":"2026-10-15","engine":Engine.get_version_info().string,"checks":checks,"failures":failures,"wins":wins,"runs":observations.size(),"step_seconds":STEP,"timeout_seconds":240,"manual_controls":true,"damage_enabled":true,"test_gold_budget_per_case":20000,"records_progression":false,"policy":"Use the runtime navigation/broadside bot. Buy every rank-eligible upgrade with real isolated purchase receipts; no automation, invulnerability, hull refills, stat overrides, teleports, or forced kills. Bot defeats are observations and do not fail this test unless setup/isolation contracts fail.","observations":observations,"wall_seconds":(Time.get_ticks_usec()-started)/1000000.0}
	DirAccess.make_dir_recursive_absolute("res://tests/output")
	var file:=FileAccess.open("res://tests/output/balance-observations.json",FileAccess.WRITE)
	if file!=null: file.store_string(JSON.stringify(report,"  "))
	print("BALANCE_SUMMARY "+JSON.stringify({"checks":checks,"failures":failures,"wins":wins,"runs":observations.size(),"wall_seconds":report.wall_seconds}))
	quit(1 if failures>0 else 0)
