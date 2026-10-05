extends SceneTree

var failed: bool = false

func _initialize() -> void: call_deferred("_run")

func _expect(ok: bool, message: String) -> void:
	print("[", "通过" if ok else "失败", "] ", message)
	if not ok:
		failed = true
		push_error(message)

func _mouse(position: Vector2, pressed: Variant = null) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = position
	root.push_input(motion, true)
	if pressed != null:
		var event := InputEventMouseButton.new()
		event.position = position
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event, true)

func _run() -> void:
	root.size = Vector2i(1280, 720)
	var main = load("res://Scene/main.tscn").instantiate()
	main.level_preset = main.level_preset.duplicate(true)
	main.level_preset.layout_seed = 418
	main.level_preset.events.clear()
	main.level_preset.map_resources.clear()
	main.level_preset.camp_config.enabled = false
	main.level_preset.fog_of_war_enabled = false
	root.add_child(main)
	current_scene = main
	for frame: int in range(12):
		await process_frame
		await physics_frame
	paused = true
	var edited: BuildingData = load("res://data/buildings/HouseData.tres")
	var original_category: int = edited.category
	var original_sort: int = edited.sort_id
	edited.category = BuildingData.Category.PROCESSING
	edited.sort_id = -10
	main.hud._configure_building_menu()
	main.hud._on_building_tab_changed(4)
	_expect(main.hud.build_buttons.get_child_count() == 1 and main.hud.build_buttons.get_child(0).text == edited.display_name, "建筑分类修改决定HUD加工分类内容")
	_expect(main.hud.menu_buildings[0] == edited, "HUD按排序ID升序排列")
	edited.category = original_category
	edited.sort_id = original_sort
	main.hud._configure_building_menu()
	var roads: Node = main.road_manager
	var tool: Node = main.road_tool
	var grid: BuildGrid = roads.grid
	var cells: Array[Vector2i] = []
	var found_slope: bool = false
	for y: int in range(grid.grid_min.y, grid.grid_max.y + 1):
		for x: int in range(grid.grid_min.x, grid.grid_max.x + 1):
			var cell := Vector2i(x, y)
			var runtime: Node = main.get_node("Systems/MapGenerateRuntime")
			var map_cell: Vector2i = runtime._grid_to_map_cell(cell)
			if runtime.map_data.has_cell(map_cell) and not runtime._is_grid_cell_buildable(cell):
				found_slope = true
				var slope_cells: Array[Vector2i] = [cell]
				_expect(roads.place_cells(slope_cells, 1) == 0, "真实坡面／台阶不能铺路")
				break
		if found_slope: break
	_expect(found_slope, "测试地图包含坡面")
	var base: Node3D = get_first_node_in_group("bases")
	var origin: Vector2i = grid.world_to_grid(base.position)
	for y: int in range(origin.y + 4, origin.y + 12):
		for x: int in range(origin.x - 8, origin.x + 8):
			var candidate: Array[Vector2i] = []
			for offset: int in range(8):
				var cell := Vector2i(x + offset, y)
				if roads.can_place(cell): candidate.append(cell)
			if candidate.size() == 8:
				cells = candidate
				break
		if not cells.is_empty(): break
	_expect(cells.size() == 8, "找到真实地图连续平地")
	if cells.is_empty():
		quit(1)
		return
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 20.0
	camera.position = grid.grid_to_world(cells[3]) + Vector3(0, 20, 0)
	camera.look_at(grid.grid_to_world(cells[3]), Vector3.FORWARD)
	camera.make_current()
	main.hud.building_tabs.current_tab = 3
	main.hud.build_buttons.get_child(0).pressed.emit()
	_expect(tool.mode == 1 and not main.building_ghost.start_preview, "点击HUD土路立即进入拖拽模式")
	_expect(main.hud.get_node_or_null("RoadPanel") == null, "选择道路不创建额外操作面板")
	for frame: int in range(3): await process_frame
	var original_occupancy: Dictionary = grid.occupied_cells.duplicate()
	for offset: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]: grid.occupied_cells[cells[-1] + offset] = true
	_mouse(camera.unproject_position(grid.grid_to_world(cells[0])), true)
	_mouse(camera.unproject_position(grid.grid_to_world(cells[-1])))
	await process_frame
	tool.preview_from = Vector2i(2147483647, 0)
	tool._process(0.0)
	_expect(not tool.stroke_valid, "封闭目标时整条道路预览无效")
	var colors: PackedColorArray = tool.preview.mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
	_expect(colors[0].r > 0.8 and colors[-1].g < 0.2, "无法连通时整条预览为红色")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/road_ui_blocked.png")
	_mouse(camera.unproject_position(grid.grid_to_world(cells[-1])), false)
	_expect(roads.pending.is_empty() and roads.cells.is_empty(), "无法连通时松开不生成截断道路")
	grid.occupied_cells = original_occupancy
	tool.preview_from = Vector2i(2147483647, 0)
	_mouse(camera.unproject_position(grid.grid_to_world(cells[0])), true)
	await process_frame
	_mouse(camera.unproject_position(grid.grid_to_world(cells[-1])))
	await process_frame
	_mouse(camera.unproject_position(grid.grid_to_world(cells[-1])), false)
	await process_frame
	_expect(roads.pending.size() == 8 and roads.cells.is_empty(), "实际鼠标拖拽标记8格待施工土路")
	# 暂停中确认不会自动完工；后续升级UI使用已完成道路夹具。
	_expect(roads.speed_multiplier(grid.grid_to_world(cells[0])) == 1.0, "暂停中待建道路不提供加速")
	roads.remove_cells(cells)
	roads.place_cells(cells, 1)
	base.take_resource(&"stone", base.get_resource(&"stone"))
	base.add_resource(&"stone", 1)
	main.hud.build_buttons.get_child(1).pressed.emit()
	_expect(tool.mode == 2, "点击HUD石路立即进入拖拽模式")
	_mouse(camera.unproject_position(grid.grid_to_world(cells[0])), true)
	_mouse(camera.unproject_position(grid.grid_to_world(cells[-1])))
	await process_frame
	tool.preview_from = Vector2i(2147483647, 0)
	tool._process(0.0)
	_expect(not tool.stroke_valid, "升级整条道路材料不足时显示无效预览")
	_mouse(camera.unproject_position(grid.grid_to_world(cells[-1])), false)
	_expect(roads.pending.is_empty(), "材料不足时不标记截断升级")
	base.add_resource(&"stone", 7)
	_mouse(camera.unproject_position(grid.grid_to_world(cells[0])), true)
	_mouse(camera.unproject_position(grid.grid_to_world(cells[-1])))
	await process_frame
	tool.preview_from = Vector2i(2147483647, 0)
	tool._process(0.0)
	_expect(tool.stroke_valid, "补充材料后直接拖拽预览升级")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/road_ui_preview.png")
	_mouse(camera.unproject_position(grid.grid_to_world(cells[-1])), false)
	_expect(roads.dirt_count() == 8 and roads.pending.size() == 8 and base.get_resource(&"stone") == 0, "拖拽石路标记升级施工并保留原土路")
	tool._set_mode(1)
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	root.push_input(escape, true)
	_expect(tool.mode == 0 and not tool.preview.visible, "Esc取消道路预览")
	tool.open()
	tool._set_mode(1)
	main.hud.build_requested.emit(load("res://data/buildings/HouseData.tres"))
	_expect(tool.mode == 0 and not tool.preview.visible, "选择建筑关闭铺路工具")
	paused = false
	main.queue_free()
	camera.queue_free()
	await process_frame
	print("道路UI运行测试", "失败" if failed else "通过")
	quit(1 if failed else 0)
