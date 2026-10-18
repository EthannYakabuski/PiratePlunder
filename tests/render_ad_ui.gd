extends SceneTree
## Internal layout QA. The labeled banner rectangle is a placeholder, not an ad.
const Flow = preload("res://tests/test_ad_flow.gd")
var output_size := Vector2i(1080,1920)

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-size="):
			var parts := arg.trim_prefix("--qa-size=").split("x")
			if parts.size()==2: output_size=Vector2i(int(parts[0]),int(parts[1]))
	call_deferred("_run")

func _save(view: SubViewport, name: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var folder := "res://tests/output/ad-ui/%dx%d" % [output_size.x,output_size.y]
	DirAccess.make_dir_recursive_absolute(folder)
	view.get_texture().get_image().save_png(folder.path_join(name+".png"))

func _run() -> void:
	var progress: Node=root.get_node("Progression")
	var previous: Dictionary=progress.data.duplicate(true)
	var previous_settings: Dictionary=progress.settings.duplicate(true)
	var previous_path: String=progress.save_path
	progress.save_path="res://tests/output/.ad-ui-profile.json"
	progress.reset_data("ad-ui-qa")
	progress.settings.music=false
	progress.settings.sfx=false
	var view:=SubViewport.new()
	view.size=output_size
	var logical:=Vector2i(540,960)
	var aspect:=float(output_size.x)/output_size.y
	if aspect>540.0/960: logical.x=ceili(960*aspect)
	else: logical.y=ceili(540/aspect)
	view.size_2d_override=logical
	view.size_2d_override_stretch=true
	view.disable_3d=true
	view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var fake:=Flow.MockAds.new()
	fake.logical_banner_height=120
	root.add_child(fake)
	var game=load("res://scenes/main.tscn").instantiate()
	game.ads_service=fake
	view.add_child(game)
	var layer:=CanvasLayer.new()
	layer.layer=20
	view.add_child(layer)
	var banner:=ColorRect.new()
	banner.color=Color("294854")
	banner.position=Vector2(0,logical.y-120)
	banner.size=Vector2(logical.x,120)
	layer.add_child(banner)
	var label:=Label.new()
	label.text="INTERNAL QA PLACEHOLDER\n120-unit banner space · native ad renders here"
	label.position=Vector2(15,15)
	label.size=banner.size-Vector2(30,30)
	label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size",17)
	banner.add_child(label)
	await _save(view,"home-large-banner")
	banner.hide()
	game._select_level(1)
	game._choose_ship(0)
	game.arena.score=1234
	game.arena.elapsed=42
	game.arena.damage_taken=99
	game.arena.hp=0
	game.arena._request_defeat()
	await _save(view,"rewarded-rescue-offer")
	game._watch_revive()
	fake.close_reward_surface()
	fake.deliver_reward(true)
	game.arena.paused=true
	await _save(view,"restored-voyage")
	game.queue_free()
	view.queue_free()
	fake.queue_free()
	await process_frame
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(progress.save_path+suffix): DirAccess.remove_absolute(progress.save_path+suffix)
	progress.data=previous
	progress.settings=previous_settings
	progress.save_path=previous_path
	print("AD_UI_QA rendered ",output_size,"; banner rectangle is labeled placeholder; real SDK unused")
	quit()
