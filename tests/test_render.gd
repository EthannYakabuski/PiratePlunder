extends SceneTree
## Actual desktop renderer benchmark, not an extrapolated Android measurement.
var samples: Array[float] = []
func _initialize() -> void: call_deferred("run")
func run() -> void:
	Engine.max_fps = 60
	var progress: Node = root.get_node("Progression")
	progress.save_path = "res://tests/.render-save.json"
	progress.reset_data("render-test")
	var main: Node2D = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.selected_mode="endless"
	main.selected_ship=1
	main.start_run()
	main.arena.automated=true
	main.arena.debug_invulnerable=true
	main.arena.muted=true
	main.arena.elapsed=600
	for i in 14: main.arena.spawn_enemy("boss" if i%5==0 else "skirmisher")
	var last := Time.get_ticks_usec()
	var peak_memory := 0.0
	var peak_draw_calls := 0.0
	var cpu_samples: Array[float] = []
	for frame in 660:
		await process_frame
		var now := Time.get_ticks_usec()
		if frame>=60: samples.append(float(now-last)/1000.0)
		last=now
		peak_memory=maxf(peak_memory,Performance.get_monitor(Performance.MEMORY_STATIC))
		peak_draw_calls=maxf(peak_draw_calls,Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		if frame>=60: cpu_samples.append(Performance.get_monitor(Performance.TIME_PROCESS)*1000)
	var total := 0.0
	for sample in samples: total+=sample
	samples.sort()
	var result := {"frames":samples.size(),"resolution":root.size,"average_frame_ms":total/samples.size(),"p95_frame_ms":samples[int(samples.size()*0.95)],"max_frame_ms":samples[-1],"peak_static_memory_mb":peak_memory/1048576,"peak_draw_calls":peak_draw_calls,"peak_entities":main.arena.peak_entities,"renderer":"GL Compatibility","platform":OS.get_name(),"driver":RenderingServer.get_video_adapter_name(),"fps_cap":60}
	cpu_samples.sort()
	result.cpu_process_p95_ms=cpu_samples[int(cpu_samples.size()*0.95)]
	DirAccess.make_dir_recursive_absolute("res://tests/output")
	var file := FileAccess.open("res://tests/output/render-benchmark.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(result,"  "))
	file.close()
	print("RENDER_BENCHMARK "+JSON.stringify(result))
	main.queue_free()
	await process_frame
	quit()
