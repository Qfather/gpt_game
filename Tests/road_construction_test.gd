extends SceneTree

var failed: bool = false

func _initialize() -> void: call_deferred("_run")

func _expect(ok: bool, message: String) -> void:
	print("[", "通过" if ok else "失败", "] ", message)
	if not ok: failed = true

func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world
	if DisplayServer.get_name() != "headless":
		var camera := Camera3D.new()
		world.add_child(camera)
		camera.position = Vector3(8,18,18)
		camera.look_at(Vector3.ZERO)
		camera.make_current()
		var light := DirectionalLight3D.new()
		world.add_child(light)
		light.rotation_degrees.x = -60
	var grid := BuildGrid.new()
	grid.grid_min = Vector2i(-12, -12)
	grid.grid_max = Vector2i(12, 12)
	world.add_child(grid)
	var roads = preload("res://Script/world/road_manager.gd").new()
	roads.grid = grid
	world.add_child(roads)
	var tasks := TaskManager.new()
	world.add_child(tasks)
	grid.occupied_cells[Vector2i(0, 0)] = true
	grid.occupied_cells[Vector2i(0, 1)] = true
	var path: Array[Vector2i] = roads.plan_stroke(Vector2i(-3, 0), Vector2i(3, 0))
	_expect(path.size() > 7 and path[0] == Vector2i(-3, 0) and path[-1] == Vector2i(3, 0), "拖拽两端通过绕障连通")
	for index: int in range(1, path.size()):
		var diff: Vector2i = path[index] - path[index - 1]
		_expect(absi(diff.x) + absi(diff.y) == 1 and roads.can_place(path[index]), "路径连续且不穿过房屋占地")
	for offset: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]: grid.occupied_cells[Vector2i(3, 0) + offset] = true
	_expect(roads.plan_stroke(Vector2i(-3, 0), Vector2i(3, 0)).is_empty(), "目标封闭时拒绝整条道路")
	grid.occupied_cells.clear()
	# 使用实际资源碰撞边界验证绕障。
	var stone: Node3D = load("res://Scene/resource/stone.tscn").instantiate()
	world.add_child(stone)
	stone.position = grid.grid_to_world(Vector2i.ZERO)
	await process_frame
	path = roads.plan_stroke(Vector2i(-5, 0), Vector2i(5, 0))
	_expect(not path.is_empty() and not path.has(Vector2i.ZERO), "道路绕开实际资源")
	stone.queue_free()
	await process_frame
	var region := NavigationRegion3D.new()
	world.add_child(region)
	var source := NavigationMeshSourceGeometryData3D.new()
	source.add_faces(PackedVector3Array([Vector3(-12, 0, -12), Vector3(12, 0, -12), Vector3(-12, 0, 12), Vector3(12, 0, -12), Vector3(12, 0, 12), Vector3(-12, 0, 12)]), Transform3D.IDENTITY)
	var mesh := NavigationMesh.new()
	mesh.agent_radius = 0.3
	NavigationServer3D.bake_from_source_geometry_data(mesh, source)
	region.navigation_mesh = mesh
	var base: Node3D = load("res://Scene/building/base.tscn").instantiate()
	world.add_child(base)
	base.position = Vector3(-10, 0, -10)
	base.take_resource(&"stone", base.get_resource(&"stone"))
	base.add_resource(&"stone", 1.0)
	for frame: int in range(6): await physics_frame
	var near_cell := Vector2i(2, 0)
	var far_cell := Vector2i(5, 0)
	_expect(roads.queue_cells([far_cell, near_cell], 1) == 2 and roads.cells.is_empty(), "免费土路先生成待施工蓝图")
	_expect(is_equal_approx(roads.speed_multiplier(grid.grid_to_world(near_cell)), 1.0), "待建道路不提供加速")
	var worker: Node3D = load("res://Scene/unit/villager.tscn").instantiate()
	world.add_child(worker)
	worker.position = grid.grid_to_world(Vector2i(1, 0))
	worker.set_physics_process(false)
	for frame: int in range(10): await physics_frame
	worker.state = worker.State.IDLE
	tasks._dispatch_available_tasks()
	_expect(worker.current_task == roads.pending[near_cell], "居民先标记并领取最近路格")
	var task: GameTask = worker.current_task
	roads.work_cell(task, worker, 100.0)
	_expect(not roads.cells.has(near_cell), "未走到路格不能施工")
	worker.position = grid.grid_to_world(near_cell)
	roads.work_cell(task, worker, 2.9)
	_expect(not roads.cells.has(near_cell), "土路不足3秒不能完工")
	roads.work_cell(task, worker, 0.1)
	_expect(roads.cells.get(near_cell) == 1 and not roads.pending.has(near_cell), "土路施工3秒后生效")
	_expect(roads.queue_cells([near_cell], 2) == 1 and base.get_resource(&"stone") == 0.0, "升级读取建筑配置扣除成本")
	_expect(roads.queue_cells([Vector2i(8, 0), Vector2i(9, 0)], 2) == 0 and not roads.pending.has(Vector2i(8, 0)), "材料不足时整条新路不截断标记")
	tasks._dispatch_available_tasks()
	task = roads.pending[near_cell]
	_expect(worker.current_task == task, "居民按距离继续领取升级施工")
	roads.work_cell(task, worker, 4.9)
	_expect(roads.cells[near_cell] == 1 and is_equal_approx(roads.speed_multiplier(worker.position), 1.05), "升级不足5秒保留原土路")
	roads.work_cell(task, worker, 0.1)
	_expect(roads.cells[near_cell] == 2 and is_equal_approx(roads.speed_multiplier(worker.position), 1.10), "升级5秒后石路生效")
	worker.state = worker.State.RETURN_TO_IDLE
	tasks._dispatch_available_tasks()
	worker._start_current_task()
	_expect(worker.state == worker.State.MOVE_TO_ROAD and is_equal_approx(worker.navigation_agent.target_desired_distance, 0.25), "从住宅完工返回待命状态接道路任务，保留道路抵达距离")
	_expect(VillagerPanel.STATE_DISPLAY_NAMES.size() == worker.State.size() and VillagerPanel.TASK_DISPLAY_NAMES.size() == GameTask.TaskType.size(), "居民面板覆盖所有现有状态与任务")
	_expect(VillagerPanel.STATE_DISPLAY_NAMES[worker.State.MOVE_TO_ROAD] == "前往道路施工" and VillagerPanel.TASK_DISPLAY_NAMES[GameTask.TaskType.BUILD_ROAD] == "道路施工", "道路任务不显示未知")
	var panel: VillagerPanel = load("res://UI/unit_panel/villager_panel.tscn").instantiate()
	root.add_child(panel)
	await process_frame
	await process_frame
	panel.open_unit(worker)
	_expect(panel.state_label.text == "状态：前往道路施工" and panel.task_label.text == "当前任务：道路施工", "实际居民面板正确显示道路状态与任务")
	if DisplayServer.get_name() != "headless":
		await create_timer(0.3).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/road-resident-panel.png")
	panel.queue_free()
	worker.set_physics_process(true)
	tasks.request_dispatch()
	var deadline: int = Time.get_ticks_msec() + 20000
	while not roads.cells.has(far_cell) and Time.get_ticks_msec() < deadline: await physics_frame
	_expect(roads.cells.get(far_cell) == 1, "实际居民走到下一路格并完成施工")
	deadline = Time.get_ticks_msec() + 15000
	while worker.state != worker.State.IDLE and Time.get_ticks_msec() < deadline: await physics_frame
	_expect(worker.current_task == null and worker.state == worker.State.IDLE and worker.global_position.distance_to(base.global_position) <= base.idle_radius + 0.5, "待建道路全部完成后实际返回据点待命")
	worker.set_physics_process(false)
	_expect(roads.queue_cells([Vector2i(6, 0)], 1) == 1, "新增施工任务")
	var cancelled: GameTask = roads.pending[Vector2i(6, 0)]
	roads.remove_cells([Vector2i(6, 0)])
	_expect(cancelled.state == GameTask.State.CANCELLED and not roads.pending.has(Vector2i(6, 0)), "拆除待建道路释放施工预约")
	var blocked_cell := Vector2i(7, 0)
	roads.queue_cells([blocked_cell], 1)
	var blocked_task: GameTask = roads.pending[blocked_cell]
	blocked_task.assigned_worker = worker
	grid.occupied_cells[blocked_cell] = true
	roads.work_cell(blocked_task, worker, 5.0)
	_expect(blocked_task.state == GameTask.State.CANCELLED and not roads.pending.has(blocked_cell) and not roads.cells.has(blocked_cell), "施工期间新增房屋立即取消被阻挡路格")
	world.queue_free()
	await process_frame
	print("道路连通与居民施工测试", "失败" if failed else "通过")
	quit(1 if failed else 0)
