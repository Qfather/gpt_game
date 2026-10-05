extends SceneTree

func _initialize() -> void: call_deferred("_run")

func _sample(main: Node, dragging: bool) -> void:
	var tool: Node = main.road_tool
	var camera: Camera3D = root.get_camera_3d()
	var grid: BuildGrid = main.road_manager.grid
	var origin: Vector2i = grid.world_to_grid(get_first_node_in_group("bases").global_position)
	if dragging:
		tool.open(main.road_manager.ROAD_DATA[1])
		tool.dragging = true
		tool.drag_start = origin + Vector2i(-8, 6)
		while not main.road_manager.can_place(tool.drag_start): tool.drag_start.x += 1
		tool.set_process(false)
	else: tool.close()
	var fog: Node = get_first_node_in_group("fog_of_war")
	fog.set_process(false)
	var fog_total: int = 0
	var fog_max: int = 0
	var total: int = 0
	var max_update: int = 0
	var process_total: float = 0.0
	var physics_total: float = 0.0
	var frames: Array[float] = []
	var start_frame: int = Time.get_ticks_usec()
	for index: int in range(60):
		if dragging:
			tool.mouse_position = camera.unproject_position(grid.grid_to_world(origin + Vector2i(index % 20 - 8, 6 + index % 3)))
			var start: int = Time.get_ticks_usec()
			tool._process(0.0)
			var elapsed: int = Time.get_ticks_usec() - start
			total += elapsed
			max_update = maxi(max_update, elapsed)
		var fog_start: int = Time.get_ticks_usec()
		fog._process(1.0 / 60.0)
		var fog_elapsed: int = Time.get_ticks_usec() - fog_start
		fog_total += fog_elapsed
		fog_max = maxi(fog_max, fog_elapsed)
		await process_frame
		var now: int = Time.get_ticks_usec()
		frames.append((now - start_frame) / 1000.0)
		process_total += Performance.get_monitor(Performance.TIME_PROCESS)
		physics_total += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)
		start_frame = now
	frames.sort()
	print("拖拽=", dragging, " 暂停=", paused, " 更新平均ms=", total / 60000.0, " 最大ms=", max_update / 1000.0, " 帧中位ms=", frames[30], " P95ms=", frames[57], " 迷雾平均ms=", fog_total / 60000.0, " 最大ms=", fog_max / 1000.0, " CPU帧ms=", process_total * 1000.0 / 60.0, " 物理ms=", physics_total * 1000.0 / 60.0)
	if dragging: assert(not tool.stroke.is_empty(), "必须实际生成预览")
	tool.close()

func _run() -> void:
	root.size = Vector2i(1280, 720)
	if "--no-picking" in OS.get_cmdline_user_args(): root.physics_object_picking = false
	OS.low_processor_usage_mode = false
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var main = load("res://Scene/main.tscn").instantiate()
	main.level_preset = main.level_preset.duplicate(true)
	main.level_preset.layout_seed = 418
	main.level_preset.events.clear()
	main.level_preset.camp_config.enabled = false
	root.add_child(main)
	current_scene = main
	for frame: int in range(40): await physics_frame
	var base: Node3D = get_first_node_in_group("bases")
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 30.0
	camera.position = base.global_position + Vector3(0, 35, 6)
	camera.look_at(base.global_position + Vector3(0, 0, 6), Vector3.FORWARD)
	camera.make_current()
	if "--with-roads" in OS.get_cmdline_user_args():
		var cells: Array[Vector2i] = []
		var grid: BuildGrid = main.road_manager.grid
		var origin: Vector2i = grid.world_to_grid(base.global_position)
		for y: int in range(origin.y + 3, origin.y + 13):
			for x: int in range(origin.x - 12, origin.x + 12):
				var cell := Vector2i(x, y)
				if main.road_manager.can_place(cell): cells.append(cell)
		print("待建道路格数：", main.road_manager.queue_cells(cells, 1))
	for pause: bool in [false, true]:
		paused = pause
		await _sample(main, false)
		await _sample(main, true)
	paused = false
	main.queue_free()
	camera.queue_free()
	await process_frame
	quit()
