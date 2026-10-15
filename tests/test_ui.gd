extends SceneTree
var checks := 0
var failed := 0
func _initialize() -> void: call_deferred("run")
func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failed += 1
		push_error(message)
func run() -> void:
	var progress: Node = root.get_node("Progression")
	progress.save_path = "res://tests/.ui-save.json"
	progress.reset_data("ui-test")
	# Fast headless screen tests don't need an asynchronous audio-device playback.
	progress.settings.music=false
	var main: Node2D = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	check(main.screen == "ships","Launch opens ship cards")
	check(progress.ships.size()==4,"Four distinct ships")
	main._choose_ship(0,true)
	check(main.screen=="chart","Ship leads to shared chart")
	check(progress.is_level_unlocked(1) and not progress.is_level_unlocked(2),"New profile locks later levels")
	main._select_level(1)
	check(main.screen=="ships" and not main.launch_cards,"Level opens run ship cards")
	main._choose_ship(2,false)
	check(main.screen=="run" and main.arena.running,"Ship tap starts a run")
	check(main.arena.max_hp==110,"Base HP survives additive rank bonuses")
	check(main.arena.ship.damage==28,"Base damage survives rank bonuses")
	check(main.arena.assisted,"One-thumb auto fire default on")
	main._pause()
	check(main.arena.paused,"Pause freezes combat")
	main.arena.paused=false
	main._run_ui()
	main.arena.finish(false)
	check(main.screen=="result","Defeat opens result")
	check(progress.metric("runs_started")==1,"Result recorded exactly once")
	main.show_chart()
	check(not main.arena.visible,"Chart hides previous arena")
	main.selected_mode="endless"
	main.start_run()
	check(main.arena.mode=="endless" and main.arena.max_hp>0,"Endless playable")
	check(main.arena.level.endless.max_enemies_cap==14,"Endless honors authored configuration")
	for i in 40: main.arena.spawn_enemy("boss")
	check(main.arena.enemies.size()==14,"Repeated boss spawns cannot exceed endless hard cap")
	main.arena.finish(false)
	main.selected_mode="daily"
	main.start_run()
	check(main.arena.mode=="daily","Daily mode starts")
	main.arena.finish(true)
	check(not progress.is_level_unlocked(2),"Daily result does not unlock campaign")
	main.show_logbook()
	check(main.screen=="logbook","Logbook renders")
	main.show_settings()
	check(main.screen=="settings","Settings render")
	progress.set_setting("auto_fire",false)
	main.selected_mode="campaign"
	main.selected_level=1
	main.start_run()
	check(not main.arena.assisted,"Auto fire setting restored")
	main.arena.finished.disconnect(main._run_finished)
	main.queue_free()
	await process_frame
	for suffix in ["",".bak",".tmp"]:
		if FileAccess.file_exists(progress.save_path+suffix): DirAccess.remove_absolute(progress.save_path+suffix)
	print("UI_SUITE checks=%d failures=%d" % [checks,failed])
	quit(1 if failed else 0)
