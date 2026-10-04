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
	_expect(tool.panel.visible and not main.building_ghost.start_preview, "道路菜单打开且取消建筑蓝图")
	tool.panel.get_child(0).get_child(1).get_child(0).pressed.emit()
	for frame: int in range(3): await process_frame
	_mouse(camera.unproject_position(grid.grid_to_world(cells[0])), true)
	await process_frame
	_mouse(camera.unproject_position(grid.grid_to_world(cells[-1])))
	await process_frame
	_mouse(camera.unproject_position(grid.grid_to_world(cells[-1])), false)
	await process_frame
	_expect(roads.cells.size() == 8, "实际鼠标拖拽铺设8格纯色土路")
	base.take_resource(&"stone", base.get_resource(&"stone"))
	base.add_resource(&"stone", 3)
	tool.panel.get_child(0).get_child(1).get_child(3).pressed.emit()
	_expect(tool.all_selected and not tool.upgrade_button.disabled and tool.upgrade_button.text.contains("3/8"), "选择全部土路显示可支付升级数量")
	tool.upgrade_button.pressed.emit()
	_expect(roads.dirt_count() == 5 and base.get_resource(&"stone") == 0, "道路UI按库存部分升级")
	base.add_resource(&"stone", 1)
	for frame: int in range(3): await process_frame
	_expect(not tool.upgrade_button.disabled and tool.upgrade_button.text.contains("1/5"), "库存补充后升级按钮自动更新")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/road_ui_preview.png")
	tool._set_mode(1)
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	root.push_input(escape, true)
	_expect(tool.mode == 0 and not tool.preview.visible, "Esc取消道路预览")
	tool.open()
	tool._set_mode(1)
	main.hud.build_requested.emit(load("res://data/buildings/HouseData.tres"))
	_expect(tool.mode == 0 and not tool.panel.visible, "选择建筑关闭铺路工具")
	paused = false
	main.queue_free()
	camera.queue_free()
	await process_frame
	print("道路UI运行测试", "失败" if failed else "通过")
	quit(1 if failed else 0)
