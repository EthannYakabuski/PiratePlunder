extends SceneTree
## Render genuine game UI at full phone/tablet dimensions without a desktop
## monitor's window-height limit. The presentation uses the same logical expand
## policy as project.godot; only the capture surface is an offscreen SubViewport.

var requested_size := Vector2i(1080, 1920)

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-size="):
			var dimensions: PackedStringArray = arg.trim_prefix("--capture-size=").split("x")
			if dimensions.size() != 2:
				push_error("Capture size must be WIDTHxHEIGHT")
				quit(2)
				return
			requested_size = Vector2i(int(dimensions[0]), int(dimensions[1]))
	if requested_size.x < 320 or requested_size.y < 320:
		push_error("Capture dimensions must be at least 320 pixels")
		quit(2)
		return
	call_deferred("_boot_capture")

func _boot_capture() -> void:
	root.size = Vector2i(540, 800)
	var logical_size := Vector2i(540, 960)
	var aspect := float(requested_size.x) / float(requested_size.y)
	if aspect > 540.0 / 960.0:
		logical_size.x = ceili(960.0 * aspect)
	else:
		logical_size.y = ceili(540.0 / aspect)
	var viewport := SubViewport.new()
	viewport.name = "StoreCaptureViewport"
	viewport.size = requested_size
	viewport.size_2d_override = logical_size
	viewport.size_2d_override_stretch = true
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var scene: PackedScene = load("res://scenes/main.tscn")
	if scene == null:
		push_error("Capture launcher could not load the game scene")
		quit(2)
		return
	var game := scene.instantiate()
	viewport.add_child(game)
	print("CAPTURE_VIEWPORT requested=" + str(requested_size) + " logical=" + str(logical_size) + " actual_visible=" + str(viewport.get_visible_rect().size))
