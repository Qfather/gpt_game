extends SceneTree

func _init() -> void: call_deferred("_run")

func _run() -> void:
	Engine.time_scale = 6.0
	var main: Node3D = load("res://Scene/main.tscn").instantiate()
	main.level_preset = main.level_preset.duplicate(true)
	main.level_preset.layout_seed = 418
	main.level_preset.events.clear()
	main.level_preset.camp_config.enabled = false
	main.level_preset.wildlife_config.enabled = false
	root.add_child(main)
	current_scene = main
	for index: int in range(40): await physics_frame
	var runtime: MapGenerateRuntime = get_first_node_in_group("map_generate_runtime")
	while runtime._navigation_baking or runtime._navigation_update_queued: await physics_frame
	# 测试只隔离视野和关卡事件，保留真实地图、碰撞、导航、材料与任务流程。
	var fog: Node = get_first_node_in_group("fog_of_war")
	if fog != null: fog.queue_free()
	await process_frame
	var grid: BuildGrid = get_first_node_in_group("build_grid")
	var ghost: BuildingGhost = main.get_node("Systems/BuildingGhost")
	var base: Node3D = get_first_node_in_group("bases")
	var data: BuildingData = load("res://data/buildings/FisherHutData.tres")
	var catalog := BuildingCatalog.for_tree(self)
	assert(not catalog.can_build(data))
	catalog.offered.append(data)
	assert(catalog.choose_blueprint(data.id) and catalog.can_build(data))
	var candidates: Array = []
	var coast_count := 0
	for z: int in range(grid.grid_min.y,grid.grid_max.y):
		for x: int in range(grid.grid_min.x,grid.grid_max.x):
			var cell := Vector2i(x,z)
			if not grid.is_water_cell(cell): continue
			for turn: int in range(4):
				if grid.is_water_cell(grid.get_shore_cells(cell,data.grid_size,turn)[0]): continue
				coast_count += 1
				if coast_count < 6:
					var shore_cell := grid.get_shore_cells(cell,data.grid_size,turn)[0]
					print("岸边：",shore_cell," 高度=",grid.get_ground_height(shore_cell)," 可建=",grid.is_cell_buildable(shore_cell,true))
				if ghost.can_place_at(data,cell,turn): candidates.append([cell,turn])
	print("岸边候选=",coast_count," 合法占地=",candidates.size())
	candidates.sort_custom(func(a: Array,b: Array) -> bool: return grid.grid_to_world(a[0]).distance_squared_to(base.global_position) < grid.grid_to_world(b[0]).distance_squared_to(base.global_position))
	var placed := false
	var diagnostics := 0
	for candidate: Array in candidates:
		var point: Vector3 = grid.grid_to_world(candidate[0]) + Vector3(0.5,0,0.5)
		point.y = grid.get_building_height(data,candidate[0],candidate[1])
		var transform := Transform3D(Basis(Vector3.UP,candidate[1]*PI*0.5),point)
		var entrance := transform * Vector3(0,0,2.0)
		var nav_point := NavigationServer3D.map_get_closest_point(main.get_world_3d().navigation_map,entrance)
		if Vector2(nav_point.x-entrance.x,nav_point.z-entrance.z).length() > 0.35 or absf(nav_point.y-entrance.y) > 0.8: continue
		var path := NavigationServer3D.map_get_path(main.get_world_3d().navigation_map,base.get_entrance_position(),nav_point,true)
		if diagnostics < 5:
			print("导航候选：",entrance," 最近=",NavigationServer3D.map_get_closest_point(main.get_world_3d().navigation_map,entrance)," 终点=",path[-1] if not path.is_empty() else Vector3.INF)
			diagnostics += 1
		if path.is_empty() or path[-1].distance_to(nav_point) > 0.35: continue
		placed = ghost._create_construction_site(data,candidate[0],candidate[1],false,transform,false,false)
		if placed: break
	if not placed:
		push_error("真实地图没有找到可达贴岸水面")
		quit(1)
		return
	var hut: Node3D
	for index: int in range(5400):
		await physics_frame
		await process_frame
		if hut == null:
			for building: Node in get_nodes_in_group("resource_buildings"):
				if building.building_data != null and building.building_data.id == data.id: hut = building
			if hut != null:
				hut.boat_capacity = 2
				hut.catch_min = 1
				hut.catch_max = 1
				hut.work_radius = 8.0
				for worker: Node in hut.workers:
					worker.hunger = 0.0
					worker.fatigue = 0.0
					worker.hunger_rate = 0.0
					worker.fatigue_rate = 0.0
		if hut != null and hut.get_storage_amount() >= 2:
			var camera: GameCameraController = main.get_node("Systems/Camera3D")
			camera.orbit_distance = 10.0
			camera.focus_on_position(hut.global_position)
			if DisplayServer.get_name() != "headless":
				for frame: int in range(20): await process_frame
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("res://.godot/fisher-map.png")
			print("[通过] 真实程序地图与导航：蓝图解锁、贴岸放置、实际运料施工、自动任职、船行捕鱼与返屋处理")
			quit(0)
			return
	push_error("真实地图捕鱼链路超时")
	quit(1)
