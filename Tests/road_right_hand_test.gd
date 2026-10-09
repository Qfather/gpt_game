extends SceneTree

func _init() -> void:
	call_deferred("_run")
	call_deferred("_watchdog")

func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world
	var grid := BuildGrid.new()
	world.add_child(grid)
	var roads = preload("res://Script/world/road_manager.gd").new()
	roads.grid = grid
	world.add_child(roads)
	var region := NavigationRegion3D.new()
	var mesh := NavigationMesh.new()
	mesh.vertices = PackedVector3Array([Vector3(-10,0.5,-10), Vector3(-10,0.5,10), Vector3(10,0.5,10), Vector3(10,0.5,-10)])
	mesh.add_polygon(PackedInt32Array([0,1,2,3]))
	region.navigation_mesh = mesh
	world.add_child(region)
	var base: BuildingBase = load("res://Scene/building/base.tscn").instantiate()
	world.add_child(base)
	base.position = Vector3(-12, 0, -12)
	var captured: bool = false
	if DisplayServer.get_name() != "headless":
		var camera := Camera3D.new()
		world.add_child(camera)
		camera.position = Vector3(0, 12, 8)
		camera.look_at(Vector3(0, 0, 0.5))
		camera.make_current()
		var light := DirectionalLight3D.new()
		world.add_child(light)
		light.rotation_degrees.x = -60
	for frame: int in range(6): await physics_frame
	var layouts: Array[Array] = [[], [], []]
	for x: int in range(-6, 7): layouts[0].append(Vector2i(x, 0))
	for z: int in range(-6, 7): layouts[1].append(Vector2i(0, z))
	for x: int in range(-6, 1): layouts[2].append(Vector2i(x, 0))
	for z: int in range(1, 7): layouts[2].append(Vector2i(0, z))
	for layout: Array in layouts:
		roads.remove_cells(roads.placement_order.duplicate())
		var cells: Array[Vector2i] = []
		cells.assign(layout)
		assert(roads.place_cells(cells, 1) == cells.size())
		for speed: float in [1.0, 3.0]:
			Engine.time_scale = speed
			var first = load("res://Scene/unit/villager.tscn").instantiate()
			var second = load("res://Scene/unit/villager.tscn").instantiate()
			var start: Vector3 = grid.grid_to_world(cells[0])
			var goal: Vector3 = grid.grid_to_world(cells[-1])
			for worker in [first, second]:
				world.add_child(worker)
				worker.set_process(false)
				worker.set_physics_process(false)
				worker.navigation_agent.path_desired_distance = 0.1
				worker.navigation_agent.target_desired_distance = 0.1
			first.position = start
			second.position = goal
			for frame: int in range(6): await physics_frame
			first.navigation_agent.target_position = goal
			second.navigation_agent.target_position = start
			var forward: PackedVector3Array = roads.preferred_path(start, goal, region.get_navigation_map())
			await physics_frame
			var backward: PackedVector3Array = roads.preferred_path(goal, start, region.get_navigation_map())
			assert(not forward.is_empty() and not backward.is_empty(), "两个方向都必须规划道路路线")
			var outgoing: Vector3 = (grid.grid_to_world(cells[1]) - start).normalized()
			if layouts.find(layout) == 0 and speed == 3.0:
				# 即使留有旧绕行状态，停用后也应沿靠右道路前进。
				for worker in [first, second]:
					worker.state = worker.State.MOVE_TO_PATROL_POINT
					worker.patrol_collision_avoid_time = 100.0
					worker.patrol_collision_avoid_direction = Vector3.FORWARD
			var right_lane_found: bool = false
			for point: Vector3 in forward:
				if absf((point - start).dot(outgoing.cross(Vector3.UP)) - 0.25) < 0.001: right_lane_found = true
			assert(right_lane_found, "道路路线必须包含右半幅中心")
			var minimum_separation: float = INF
			var queries: int = roads.route_queries
			for frame: int in range(900):
				await physics_frame
				for worker in [first, second]: worker.move_along_navigation()
				minimum_separation = minf(minimum_separation, first.position.distance_to(second.position))
				if DisplayServer.get_name() != "headless" and not captured and first.position.distance_to(second.position) < 0.8:
					await RenderingServer.frame_post_draw
					root.get_texture().get_image().save_png("res://.godot/road-right-hand.png")
					captured = true
				for worker in [first, second]:
					assert(roads.cells.has(grid.world_to_grid(worker.position)), "行走及转角不能离开一格道路：布局=%d 位置=%s" % [layouts.find(layout), worker.position])
				if first.position.distance_to(goal) < 0.4 and second.position.distance_to(start) < 0.4: break
			assert(first.position.distance_to(goal) < 0.4 and second.position.distance_to(start) < 0.4, "双方必须实际走到终点：%s / %s" % [first.position, second.position])
			assert(minimum_separation > 0.35, "对向角色不能依靠穿透错身")
			assert(roads.route_queries - queries <= 2, "移动途中不能每帧重算道路路线")
			print("靠右通行通过：布局=", layouts.find(layout), " 倍速=", speed, " 最近距离=", minimum_separation)
			first.queue_free()
			second.queue_free()
			await process_frame
	Engine.time_scale = 1.0
	# 中心线可走、右半幅被导航边界阻断时，必须回退普通导航。
	roads.remove_cells(roads.placement_order.duplicate())
	var straight: Array[Vector2i] = []
	straight.assign(layouts[0])
	roads.place_cells(straight, 1)
	var narrow := NavigationMesh.new()
	narrow.vertices = PackedVector3Array([Vector3(-10,0.5,0.4), Vector3(-10,0.5,0.6), Vector3(10,0.5,0.6), Vector3(10,0.5,0.4)])
	narrow.add_polygon(PackedInt32Array([0,1,2,3]))
	region.navigation_mesh = narrow
	for frame: int in range(6): await physics_frame
	var blocked: PackedVector3Array = roads.preferred_path(Vector3(-5.5,0,0.5), Vector3(6.5,0,0.5), region.get_navigation_map())
	assert(blocked.is_empty(), "右半幅不可通行时不能把偏移路线拉出导航范围")
	print("右半幅阻断后回退普通导航通过")
	# 停用主动避让不会取消单位的实体阻挡。
	var walker = load("res://Scene/unit/villager.tscn").instantiate()
	var standing = load("res://Scene/unit/villager.tscn").instantiate()
	for worker in [walker, standing]:
		world.add_child(worker)
		worker.set_process(false)
		worker.set_physics_process(false)
	for frame: int in range(6): await physics_frame
	walker.position = Vector3(-1, 0, 0.5)
	standing.position = Vector3(0, 0, 0.5)
	for frame: int in range(90):
		await physics_frame
		walker.velocity = Vector3(2, 0, 0)
		walker.move_and_slide()
	assert(walker.position.x > -0.3 and walker.position.x < -0.1, "实体碰撞必须拦住正面对撞，不能穿透静止单位")
	print("保留单位实体碰撞通过")
	world.queue_free()
	await process_frame
	print("道路靠右真实移动测试通过")
	quit()

func _watchdog() -> void:
	await create_timer(90.0, true, false, true).timeout
	push_error("道路靠右测试超时或断言失败")
	quit(1)
