extends SceneTree

var failed: bool = false

func _init() -> void: call_deferred("_run")

func _expect(ok: bool, message: String) -> void:
	print("[通过] " if ok else "[失败] ", message)
	failed = failed or not ok

func _wait_until(condition: Callable, frames: int = 900) -> bool:
	for frame: int in range(frames):
		if condition.call(): return true
		await physics_frame
	return condition.call()

func _capture(path: String) -> void:
	await process_frame
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)

func _run() -> void:
	var main: Node = load("res://Scene/main.tscn").instantiate()
	main.get_node("Systems/MapGenerateRuntime").settlement_seed = 42
	root.add_child(main)
	current_scene = main
	Engine.time_scale = 3.0
	var base: BuildingBase = get_first_node_in_group("bases")
	var grid: BuildGrid = get_first_node_in_group("build_grid")
	var residents: Array[Node] = get_nodes_in_group("villagers")
	var manager: PopulationManager = main.get_node("Systems/PopulationManager")
	manager.set_process(false)
	main.get_node("Systems/TaskManager").set_process(false)
	await _wait_until(func() -> bool:
		for resident: Node in residents:
			if resident.leaving_immigration_base or resident.initial_idle_position_pending: return false
		return true)
	manager.refresh_population()
	for resident: Node in residents: resident.idle_reposition_timer = 10000.0
	var camera: GameCameraController = main.get_node("Systems/Camera3D")
	camera.orbit_yaw = 0.0
	camera.orbit_distance = 12.0
	camera.focus_on_position(base.global_position)
	var roads: Node = get_first_node_in_group("road_manager")
	base.idle_space.next_refresh = 0
	base.idle_space.refresh(base)
	_expect(base.idle_space.free_ratio > 0.6, "初始据点空地充足")
	var available: Array[Vector3] = base.idle_space.points.duplicate()
	var total_idle_cells: int = roundi(float(available.size()) / base.idle_space.free_ratio)
	var road_cells: Array[Vector2i] = []
	for point: Vector3 in available: road_cells.append(grid.world_to_grid(point))
	var occupied_point: Vector2i = grid.world_to_grid(residents[0].global_position)
	var single_cell: Array[Vector2i] = [occupied_point]
	roads.place_cells(single_cell, 1)
	base.idle_space.next_refresh = 0
	residents[0].return_to_idle()
	_expect(grid.world_to_grid(residents[0].navigation_agent.target_position) != occupied_point, "据点待命目标避开已铺道路")
	var blocked: Vector2i = grid.world_to_grid(residents[0].navigation_agent.target_position)
	grid.occupied_cells[blocked] = true
	base.idle_space.next_refresh = 0
	residents[0].move_to_idle_area()
	_expect(grid.world_to_grid(residents[0].navigation_agent.target_position) != blocked and not residents[0].has_unreachable_warning(), "待命点被建筑占用后重新选点，不显示感叹号")
	grid.occupied_cells.erase(blocked)
	roads.place_cells(road_cells, 1)
	base.idle_space.next_refresh = 0
	base.idle_space.refresh(base)
	_expect(base.idle_space.free_ratio < 0.5 and base.idle_space.indoors, "周围空地不足50%时使用室内待命")
	for resident: Node in residents: resident.return_to_idle()
	_expect(await _wait_until(func() -> bool:
		for resident: Node in residents:
			if not resident.indoor_idle or resident.passing_door: return false
		return true), "居民实际从门口依次进入据点待命")
	_expect(base.get_indoor_residents().size() == residents.size(), "室内人数正确统计")
	for resident: Node in residents:
		_expect(not resident.visible and resident.collision_layer == 0 and resident.is_idle() and resident.can_take_task(null) and not resident.has_idle_warning(), "室内待命隐藏模型、取消碰撞并仍可接任务")
	await _capture("res://.godot/indoor-idle.png")
	var indicator: Node = base.get_node("OccupancyIndicator")
	_expect(indicator.count_label.text == "×3" and not indicator.sleep_label.visible, "待命显示共享头像×3，不显示ZZZ")
	var hide_event := InputEventKey.new()
	hide_event.keycode = KEY_H
	hide_event.pressed = true
	root.push_input(hide_event)
	_expect(not main.get_node("UI/HUD").visible, "H同时隐藏建筑人员头像")
	await _capture("res://.godot/indoor-hud-hidden.png")
	root.push_input(hide_event)
	var sleeper: Node = residents[0]
	sleeper.fatigue = 95.0
	sleeper.rest_recovery_rate = 0.0
	sleeper.begin_resting()
	_expect(await _wait_until(func() -> bool: return sleeper.state == sleeper.State.RESTING), "住据点的居民疲劳时直接在据点睡觉")
	await _capture("res://.godot/indoor-sleep.png")
	_expect(base.get_indoor_residents().size() == 3 and indicator.sleep_label.visible, "睡觉与待命共用人数头像，额外显示ZZZ")
	_expect(not sleeper.can_take_task(null) and not sleeper.is_idle(), "睡觉居民不能领取任务")
	sleeper.fatigue = 0.0
	_expect(await _wait_until(func() -> bool: return sleeper.indoor_idle and not sleeper.passing_door), "休息结束出门后重新按据点规则待命")
	await process_frame
	_expect(not indicator.sleep_label.visible, "无人睡觉后取消ZZZ")
	# 真实道路任务验证室内待命者接任务后排队出门。
	var task_cell: Vector2i = road_cells[0]
	single_cell[0] = task_cell
	_expect(roads.queue_cells(single_cell, 2) == 1, "创建石路施工任务")
	var worker: Node = residents[1]
	var task: GameTask = roads.pending[task_cell]
	_expect(main.get_node("Systems/TaskManager").claim_task(task, worker), "室内待命居民可以领取实际施工任务")
	_expect(await _wait_until(func() -> bool: return roads.cells.get(task_cell) == 2), "室内待命居民走出门并完成实际道路施工")
	_expect(await _wait_until(func() -> bool: return worker.indoor_idle and not worker.passing_door), "施工完成后重新进入拥挤据点待命")
	var partially_cleared: Array[Vector2i] = []
	for index: int in range(ceili(float(total_idle_cells) * 0.55)): partially_cleared.append(road_cells[index])
	roads.remove_cells(partially_cleared)
	base.idle_space.next_refresh = 0
	base.idle_space.refresh(base)
	_expect(base.idle_space.free_ratio >= 0.5 and base.idle_space.free_ratio <= 0.6 and base.idle_space.indoors, "空地恢复到50%至60%之间仍保持室内待命，避免反复进出")
	roads.place_cells(partially_cleared, 1)
	base.idle_space.next_refresh = 0
	worker.set_combat_role(CombatRole.Type.SWORDSMAN)
	for frame: int in range(15): await physics_frame
	_expect(worker.indoor_idle and not worker.passing_door, "无敌人也无军营的军事居民不会反复出入据点")
	worker.set_combat_role(CombatRole.Type.NONE)
	var camp: ResourceBuildingBase = load("res://Scene/building/game/lumber_camp.tscn").instantiate()
	main.get_node("buildings").add_child(camp)
	camp.global_position = base.global_position + Vector3(-6, 0, 3)
	_expect(camp.add_worker(sleeper), "室内待命居民可以分配伐木职业")
	_expect(await _wait_until(func() -> bool: return sleeper.visible and not sleeper.passing_door and not sleeper.indoor_idle), "分配职业后居民实际从据点出门")
	camp.remove_worker(sleeper)
	_expect(await _wait_until(func() -> bool: return sleeper.indoor_idle and not sleeper.passing_door), "取消职业后回拥挤据点室内待命")
	camp.queue_free()
	# 新住宅分配明确的住所，休息从住宅门口进入。
	var house: House = load("res://Scene/building/game/house.tscn").instantiate()
	main.get_node("buildings").add_child(house)
	house.global_position = base.global_position + Vector3(6, 0, 3)
	base.base_housing_capacity = 1
	manager.refresh_population()
	var house_resident: Node = residents[2]
	_expect(house_resident.home_building == house, "据点床位不足时住宅接收居民，住所归属持久保存")
	house_resident.fatigue = 95.0
	house_resident.rest_recovery_rate = 0.0
	house_resident.begin_resting()
	_expect(await _wait_until(func() -> bool: return house_resident.state == house_resident.State.RESTING and house_resident.indoor_building == house), "住住宅的居民从据点出门并走进自己的住宅睡觉")
	camera.focus_on_position(house.global_position)
	await _capture("res://.godot/house-sleep.png")
	_expect(house.get_indoor_residents().size() == 1 and house.get_node("OccupancyIndicator").sleep_label.visible, "住宅显示头像×1与ZZZ")
	house_resident.fatigue = 0.0
	_expect(await _wait_until(func() -> bool: return house_resident.indoor_idle and not house_resident.passing_door), "住宅睡醒后返回据点待命")
	# 拆路恢复充足空地，居民出门后重新选择空地。
	roads.remove_cells(road_cells)
	base.idle_space.next_refresh = 0
	base.idle_space.refresh(base)
	_expect(base.idle_space.free_ratio > 0.6 and not base.idle_space.indoors, "空地恢复60%以上才重新使用室外待命")
	_expect(await _wait_until(func() -> bool:
		for resident: Node in residents:
			if resident.indoor_idle or resident.passing_door or resident.initial_idle_position_pending: return false
		return true), "居民排队走出据点并抵达空地")
	_expect(base.get_indoor_residents().is_empty() and house.get_indoor_residents().is_empty(), "所有人离开后清空建筑人数")
	Engine.time_scale = 1.0
	quit(1 if failed else 0)
