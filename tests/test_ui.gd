extends SceneTree
var checks := 0
var failed := 0
func _initialize() -> void: call_deferred("run")
func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failed += 1
		push_error(message)
func button_texts(node: Node) -> Array[String]:
	var result: Array[String]=[]
	if node is Button: result.append(node.text)
	for child in node.get_children(): result.append_array(button_texts(child))
	return result
func wrapping_fits(node: Node, max_width: float) -> bool:
	if node is Label and node.text.begins_with("Unlock a separate"):
		if node.size.x>max_width or node.get_line_count()<2: return false
	for child in node.get_children():
		if not wrapping_fits(child,max_width): return false
	return true
func run() -> void:
	var progress: Node = root.get_node("Progression")
	progress.save_path = "res://tests/.ui-save.json"
	progress.reset_data("ui-test")
	progress.settings.music=false
	var main: Node2D = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	check(main.screen=="chart","Launch opens Your Next Adventure directly")
	check(progress.ships.size()==4,"Four ships remain available")
	check(progress.is_level_unlocked(1) and not progress.is_level_unlocked(2),"Shared campaign unlocks preserved")
	main._select_level(1)
	check(main.screen=="ships","Mission opens the only ship chooser")
	main._choose_ship(2)
	check(main.screen=="run" and main.arena.running,"One ship tap starts the voyage")
	check(main.arena.max_hp==110 and main.arena.ship.damage==28,"Base ship stats survive loadout integration")
	check(not main.arena.assisted,"New players have manual primary cannons")
	check(not main.arena.secondary_available(0) and not main.arena.secondary_available(1),"New players have no unearned secondary guns")
	main._pause()
	check(main.arena.paused,"Pause freezes combat")
	var locked_auto_button := false
	for text in button_texts(main.ui):
		if text.contains("auto fire"): locked_auto_button=true
	check(not locked_auto_button,"Pause cannot enable locked automatic fire")
	check(not main.arena.set_primary_assist(true),"Runtime rejects unpurchased automation")
	main.arena.paused=false
	main._run_ui()
	main.arena.finish(false)
	check(main.screen=="result" and progress.metric("runs_started")==1,"Result recorded once")
	main.capture_mode="qa"
	main._run_finished(main.last_summary.duplicate(true))
	check(progress.metric("runs_started")==1,"Automated screenshot runs never change player progression")
	main.capture_mode=""
	main.show_chart()
	check(not main.arena.visible,"Chart hides previous battlefield")
	main.shipyard_return="chart"
	main.show_shipyard()
	check(main.screen=="shipyard","Shipyard opens without starting a run")
	await process_frame
	await process_frame
	if DisplayServer.get_name()!="headless":
		check(wrapping_fits(main.ui,main.size().x-64),"Long upgrade descriptions wrap inside their cards")
	var device: Dictionary=progress.data.devices[progress.data.device_id]
	device.ship_xp.swiftfin=100000
	device.metrics.coins_collected=20000
	main.selected_ship=0
	main.show_shipyard()
	var before: Dictionary=progress.ship_loadout("swiftfin")
	var wallet: int=progress.gold()
	main._buy_upgrade("swiftfin","port_cannon_1")
	var after: Dictionary=progress.ship_loadout("swiftfin")
	check(main.screen=="shipyard" and after.cannons_port==before.cannons_port+1,"Purchase refreshes the upgraded ship")
	check(after.cannons_starboard==before.cannons_starboard,"Single-side upgrade leaves opposite count unchanged")
	check(progress.gold()<wallet,"Shipyard spends earned gold")
	check(not after.primary_auto,"Rank alone does not grant automation")
	main.show_ships()
	check(main.screen=="ships","Ship choice available after upgrading")
	progress.set_setting("auto_fire",true)
	main.selected_mode="endless"
	main.start_run()
	check(main.arena.mode=="endless" and main.arena.max_hp>0,"Endless remains playable")
	check(not main.arena.assisted,"Legacy preference cannot bypass purchased automation")
	for i in 40: main.arena.spawn_enemy("boss")
	check(main.arena.enemies.size()==14,"Endless boss population remains capped")
	main.arena.finish(false)
	main.selected_mode="daily"
	main.start_run()
	check(main.arena.mode=="daily","Daily remains separate from finite campaign flow")
	main.arena.finish(true)
	check(not progress.is_level_unlocked(2),"Daily results cannot unlock campaign")
	main.show_logbook()
	check(main.screen=="logbook","Logbook renders")
	main.show_settings()
	check(main.screen=="settings","Settings render")
	var has_auto_setting := false
	for text in button_texts(main.ui):
		if text.contains("auto fire"): has_auto_setting=true
	check(not has_auto_setting,"General settings cannot grant locked automation")
	main.queue_free()
	await process_frame
	for suffix in ["",".bak",".tmp"]:
		if FileAccess.file_exists(progress.save_path+suffix): DirAccess.remove_absolute(progress.save_path+suffix)
	print("UI_SUITE checks=%d failures=%d" % [checks,failed])
	quit(1 if failed else 0)
