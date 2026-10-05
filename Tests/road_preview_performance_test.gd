extends SceneTree

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	var main = load("res://Scene/main.tscn").instantiate()
	main.level_preset = main.level_preset.duplicate(true)
	main.level_preset.layout_seed = 418
	main.level_preset.events.clear()
	main.level_preset.camp_config.enabled = false
	main.level_preset.fog_of_war_enabled = false
	root.add_child(main)
	current_scene = main
	for frame: int in range(20): await physics_frame
	paused = true
	var roads: Node = main.road_manager
	var grid: BuildGrid = roads.grid
	var base: Node3D = get_first_node_in_group("bases")
	var origin: Vector2i = grid.world_to_grid(base.global_position)
	var candidates: Array[Vector2i] = []
	for y: int in range(origin.y + 4, origin.y + 12):
		for x: int in range(origin.x - 12, origin.x + 12):
			var cell := Vector2i(x, y)
			if roads.can_place(cell): candidates.append(cell)
	assert(candidates.size() >= 30)
	print("道路预览实地图资源数：", get_nodes_in_group("resources").size())
	var start: int = Time.get_ticks_usec()
	var first: Array[Vector2i] = roads.plan_stroke(candidates[0], candidates[29])
	print("道路预览首次准备毫秒：", (Time.get_ticks_usec() - start) / 1000.0)
	start = Time.get_ticks_usec()
	for index: int in range(300):
		assert(roads.can_work_cell(candidates[index % 30]))
	print("施工占地检查300次毫秒：", (Time.get_ticks_usec() - start) / 1000.0)
	var total: int = 0
	var maximum: int = 0
	for index: int in range(30):
		start = Time.get_ticks_usec()
		roads.plan_stroke(candidates[0], candidates[index])
		var elapsed: int = Time.get_ticks_usec() - start
		total += elapsed
		maximum = maxi(maximum, elapsed)
	print("道路预览30次移动查询毫秒：平均=", total / 30000.0, " 最大=", maximum / 1000.0)
	if "--baseline" not in OS.get_cmdline_user_args():
		assert(roads.stroke_graph_builds == 1, "拖动终点不能重复重建地形图")
		assert(maximum < 20000, "缓存后的道路查询应低于20毫秒")
		assert(not first.is_empty())
		var blocked: Vector2i = first[first.size() / 2]
		grid.occupied_cells[blocked] = true
		var rerouted: Array[Vector2i] = roads.plan_stroke(first[0], first[-1])
		assert(not roads.can_work_cell(blocked), "施工检查立即识别新增房屋")
		assert(not rerouted.has(blocked), "新增房屋占地必须使预览立即绕行或无效")
		grid.occupied_cells.erase(blocked)
		assert(roads.plan_stroke(first[0], first[-1]) == first, "移除占地后恢复路线")
		var stone: Node3D = load("res://Scene/resource/stone.tscn").instantiate()
		main.add_child(stone)
		stone.global_position = grid.grid_to_world(blocked)
		await process_frame
		roads.refresh_stroke_obstacles()
		assert(not roads.can_work_cell(blocked), "施工检查识别新增资源")
		assert(not roads.plan_stroke(first[0], first[-1]).has(blocked), "新资源使缓存路线失效")
		stone.queue_free()
		await process_frame
		roads.refresh_stroke_obstacles()
		assert(roads.plan_stroke(first[0], first[-1]) == first, "资源移除后缓存恢复通行")
		print("道路预览缓存、房屋与资源动态失效测试通过")
	paused = false
	main.queue_free()
	await process_frame
	quit()
