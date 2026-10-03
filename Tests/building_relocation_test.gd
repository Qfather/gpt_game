extends SceneTree

var main: Node3D
var failed := false
var grid: BuildGrid

func _init() -> void:
	call_deferred("_run")

func _expect(value: bool, text: String) -> void:
	print("[", "通过" if value else "失败", "] ", text)
	if not value:
		failed = true
		push_error(text)

func _click(position: Vector2, button: int = MOUSE_BUTTON_LEFT) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = position
	motion.global_position = position
	root.push_input(motion)
	for i in range(3): await physics_frame
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = true
	event.position = position
	event.global_position = position
	root.push_input(event)
	await physics_frame
	event = event.duplicate()
	event.pressed = false
	root.push_input(event)
	for i in range(4): await process_frame

func _free_cell(data: BuildingData, near: Vector3) -> Vector2i:
	var result := Vector2i(10000, 10000)
	var distance := INF
	for x in range(grid.grid_min.x, grid.grid_max.x):
		for z in range(grid.grid_min.y, grid.grid_max.y):
			var cell := Vector2i(x,z)
			if grid.is_area_free(cell, data.grid_size, 0, false, true):
				var d: float = grid.grid_to_world(cell).distance_to(near)
				if d < distance:
					distance = d
					result = cell
	return result

func _transform(data: BuildingData, cell: Vector2i, rotation_step: int = 0) -> Transform3D:
	var size: Vector2i = grid.get_rotated_size(data.grid_size, rotation_step)
	return Transform3D(Basis(Vector3.UP, rotation_step * PI * 0.5), grid.grid_to_world(cell) + Vector3(size.x - 1, 0, size.y - 1) * grid.cell_size * 0.5)

func _building(path: String, near: Vector3) -> BuildingBase:
	var data: BuildingData = load("res://data/buildings/" + path + "Data.tres")
	var cell := _free_cell(data, near)
	var building: BuildingBase = data.building_scene.instantiate()
	building.set_building_data(data)
	main.add_child(building)
	building.global_transform = _transform(data, cell)
	grid.occupy_area(cell, data.grid_size, 0, false, true)
	building.set_build_grid_occupancy(cell, data.grid_size, 0)
	main.register_building(building)
	return building

func _run() -> void:
	main = load("res://Scene/main.tscn").instantiate()
	main.level_preset = main.level_preset.duplicate(true)
	main.level_preset.layout_seed = 418
	main.level_preset.events.clear()
	main.level_preset.camp_config.enabled = false
	main.level_preset.wildlife_config.enabled = false
	main.level_preset.fog_of_war_enabled = false
	root.add_child(main)
	current_scene = main
	for i in range(30): await physics_frame
	var units: Array[Node] = get_nodes_in_group("villagers")
	for unit: Node in units: unit.set_physics_process(false)
	var base: Node3D = get_first_node_in_group("bases")
	var camera: Camera3D = main.get_viewport().get_camera_3d()
	var ghost: BuildingGhost = main.building_ghost
	grid = ghost.build_grid
	var building := _building("LumberCamp", base.global_position + Vector3(5,0,2))
	building.current_health = 180.0
	building.deposit_resource(&"wood", 7)
	var worker: Node3D = units[0]
	building.add_worker(worker)
	worker.global_position = building.get_interaction_position(worker)
	worker.carried_resource_id = &"wood"
	worker.carried_amount = 3.0
	var old_cell: Vector2i = building.build_grid_position
	var old_position: Vector3 = building.global_position
	var old_inventory: float = base.get_resource(&"wood")
	camera.focus_on_position(building.global_position)
	for i in range(4): await physics_frame
	await _click(camera.unproject_position(building.global_position + Vector3.UP * 0.5))
	await create_timer(0.4).timeout
	_expect(main.resource_building_panel.move_button.visible, "完成建筑面板显示移动按钮")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/building_move_button_preview.png")
	await _click(main.resource_building_panel.move_button.get_global_rect().get_center())
	await create_timer(0.4).timeout
	_expect(ghost.moving_building == building and ghost.start_preview and not main.resource_building_panel.visible, "实际点击移动按钮进入蓝图预览并关闭面板")
	await _click(Vector2(600, 300), MOUSE_BUTTON_RIGHT)
	_expect(not ghost.start_preview and building.global_position == old_position and grid.occupied_cells.has(old_cell), "右键取消保留原建筑及原占地")
	ghost.select_moving_building(building)
	var own_cells: Array[Vector2i] = ghost._moving_building_cells()
	_expect(grid.is_area_free(old_cell, building.building_data.grid_size, 0, false, true, own_cells), "搬迁校验允许与自身占地重叠")
	var base_building: BuildingBase = base as BuildingBase
	_expect(not building.relocate(grid, base_building.build_grid_position, 0, false, _transform(building.building_data, base_building.build_grid_position)), "禁止搬进其他建筑占地")
	var destination := _free_cell(building.building_data, old_position + Vector3(-7,0,-3))
	camera.focus_on_position(_transform(building.building_data, destination).origin)
	for i in range(4): await physics_frame
	# Viewport.push_input 不改变原生鼠标位置；固定预览网格后验证左键确认路径。
	ghost.set_process(false)
	ghost.grid_position = destination
	ghost.global_transform = _transform(building.building_data, destination)
	var move_cost := building.get_relocation_cost(ghost.global_position)
	ghost.is_valid_position = grid.is_area_free(destination, building.building_data.grid_size, 0, false, true, ghost._moving_building_cells())
	await _click(camera.unproject_position(grid.grid_to_world(destination)))
	ghost.set_process(true)
	_expect(not ghost.start_preview and building.build_grid_position == destination, "左键确认新位置完成搬迁")
	_expect(building.current_health == 180.0 and building.get_resource_amount(&"wood") == 7.0 and base.get_resource(&"wood") == old_inventory - move_cost[&"wood"], "血量、库存保留，据点仅扣除搬迁费用")
	_expect(building.workers.has(worker) and worker.workplace == building and worker.carried_amount == 3.0, "工人归属与身上资源保留")
	_expect(not grid.occupied_cells.has(old_cell) and grid.occupied_cells.has(destination) and get_nodes_in_group("construction_sites").is_empty(), "原占地释放、新占地登记，不创建施工工地")
	await create_timer(0.6).timeout
	var worker_origin: Vector3 = worker.global_position
	for i in range(420):
		worker._physics_process(1.0 / 60.0)
		await physics_frame
		if worker.relocated_building == null and worker.carried_amount == 0.0: break
	_expect(worker.global_position.distance_to(worker_origin) > 1.0 and worker.relocated_building == null and building.get_resource_amount(&"wood") >= 10.0, "工人实际步行到新址，卸货并恢复工作")
	worker.set_physics_process(false)
	main.clear_selection()
	main._select_world_object(building)
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/building_relocation_preview.png")
	# 猎户携带的未处理猎物保留，处理目的地改为新小屋。
	var hut := _building("HunterHut", base.global_position + Vector3(-4,0,4))
	var hunter: Node3D = units[1]
	hut.add_worker(hunter)
	hunter.hunting.prey_count = 3
	hunter.hunting.raw_meat = 6.0
	hunter.hunting.request_return(hunter)
	hunter.hunting.return_destination = hut.get_interaction_position(hunter)
	var hut_cell := _free_cell(hut.building_data, hut.global_position + Vector3(5,0,-5))
	paused = true
	_expect(hut.relocate(grid, hut_cell, 0, false, _transform(hut.building_data, hut_cell)), "暂停时可搬迁猎人小屋")
	_expect(hunter.workplace == hut and hunter.hunting.prey_count == 3 and hunter.hunting.raw_meat == 6.0 and hunter.hunting.return_destination == Vector3.INF and hunter.relocated_building == hut, "猎户保留猎物并丢弃旧的处理目的地")
	paused = false
	ghost.select_moving_building(hut)
	hut.take_damage(100000.0)
	for i in range(3): await process_frame
	_expect(not ghost.start_preview and ghost.moving_building == null, "预览期间原建筑被摧毁则自动取消搬迁")
	var site := ConstructionSite.new()
	site.building_data = building.building_data
	_expect(not site.can_be_moved(), "未完成的工地不提供搬迁")
	site.free()
	main.queue_free()
	await process_frame
	print("建筑搬迁测试", "失败" if failed else "通过")
	quit(1 if failed else 0)
