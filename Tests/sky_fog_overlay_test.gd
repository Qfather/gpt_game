extends SceneTree
func _init() -> void: call_deferred("_run")
func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("天空像素回归需要图形模式")
		quit(1)
		return
	root.size = Vector2i(1280,720)
	var main: Node = load("res://Scene/main.tscn").instantiate()
	main.get_node("Systems/MapGenerateRuntime").settlement_seed = 42
	main.get_node("Systems/StylizedDayNight").cycle_paused = true
	root.add_child(main)
	current_scene = main
	for frame: int in range(4): await process_frame
	var game_camera: Node = main.get_node("Systems/Camera3D")
	game_camera.set_process(false)
	var base: Node3D = get_first_node_in_group("bases")
	var camera := Camera3D.new()
	main.add_child(camera)
	camera.global_position = base.global_position + Vector3(0,6,16)
	camera.look_at(base.global_position + Vector3(0,8,-30))
	camera.make_current()
	var fog: Node = main.get_node("FogOfWar")
	for frame: int in range(5): await process_frame
	await RenderingServer.frame_post_draw
	var with_fog: Image = root.get_texture().get_image()
	var suffix: String = "regression"
	with_fog.save_png("res://.godot/sky-fog-" + suffix + ".png")
	fog.overlay.hide()
	for frame: int in range(3): await process_frame
	await RenderingServer.frame_post_draw
	var without_fog: Image = root.get_texture().get_image()
	without_fog.save_png("res://.godot/sky-no-overlay-" + suffix + ".png")
	var sky_delta: float = 0.0
	var sky_samples: int = 0
	for y: int in range(120,210,5):
		for x: int in range(280,950,5):
			var a: Color = with_fog.get_pixel(x,y)
			var b: Color = without_fog.get_pixel(x,y)
			sky_delta += absf(a.r-b.r)+absf(a.g-b.g)+absf(a.b-b.b)
			sky_samples += 1
	print("天空区域遮罩开关RGB平均差：", sky_delta / sky_samples)
	assert(sky_delta / sky_samples < 0.01, "天空仍被战争迷雾遮暗")
	var ground_delta: float = 0.0
	for y: int in range(480,600,5):
		for x: int in range(800,1050,5):
			var a: Color = with_fog.get_pixel(x,y)
			var b: Color = without_fog.get_pixel(x,y)
			ground_delta += absf(a.r-b.r)+absf(a.g-b.g)+absf(a.b-b.b)
	print("地形区域遮罩RGB差合计：", ground_delta)
	assert(ground_delta > 10.0, "未探索地形的战争迷雾失效")
	print("天空战争迷雾回归通过：天空不遮暗、地形仍遮暗")
	main.queue_free()
	await process_frame
	quit()