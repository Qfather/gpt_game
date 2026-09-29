extends SceneTree

var failed: bool = false


func _initialize() -> void:
	call_deferred("_run")


func _expect(value: bool, message: String) -> void:
	if not value:
		failed = true
		push_error("失败：" + message)


func _run() -> void:
	var data: BuildingData = load("res://data/buildings/TorchData.tres")
	_expect(data.construction_cost.get(&"wood", 0.0) == 5.0, "火把木材消耗错误")
	_expect(data.construction_time == 10.0, "火把施工时间错误")
	var scene: Node = load("res://Scene/main.tscn").instantiate()
	scene.level_preset = scene.level_preset.duplicate(true)
	scene.level_preset.fog_of_war_enabled = true
	scene.level_preset.map_resources.clear()
	scene.get_node("Systems/MapGenerateRuntime").settlement_seed = 42
	root.add_child(scene)
	current_scene = scene
	for frame: int in range(10):
		await process_frame
	var fog: Node = scene.get_node("FogOfWar")
	var grid: BuildGrid = scene.get_node("Systems/BuildGrid")
	var hud: GameHUD = scene.get_node("UI/HUD") as GameHUD
	hud._on_building_tab_changed(2)
	_expect(hud.build_buttons.get_child_count() == 1 and hud.build_buttons.get_child(0).text == "火把", "战略标签未显示火把")
	var dark_cell: Vector2i = Vector2i.ZERO
	var found: bool = false
	for z: int in range(grid.grid_min.y, grid.grid_max.y + 1):
		for x: int in range(grid.grid_min.x, grid.grid_max.x + 1):
			var cell := Vector2i(x, z)
			if grid.is_area_free(cell, Vector2i.ONE, 0, false, true) and not fog.is_visible_at(grid.grid_to_world(cell)):
				dark_cell = cell
				found = true
				break
		if found:
			break
	_expect(found, "没有找到可放置火把的迷雾地块")
	if found:
		_expect(not grid.is_area_free(dark_cell, Vector2i.ONE), "普通建筑错误允许放在迷雾中")
		_expect(grid.occupy_area(dark_cell, Vector2i.ONE, 0, false, true), "火把无法占用迷雾地块")
		var site: ConstructionSite = load("res://Scene/building/construction_site.tscn").instantiate() as ConstructionSite
		site.setup(data, dark_cell, 0, false)
		site.set_activation_deferred_until_unpause(true)
		scene.add_child(site)
		site.set_process(false)
		site.global_position = grid.grid_to_world(dark_cell)
		fog.refresh_visibility()
		_expect(not fog.is_visible_at(site.global_position), "未完工火把提前提供视野")
		_expect(site.click_area.input_ray_pickable, "迷雾中火把工地无法点击")
		site.queue_free()
		var torch: Node3D = data.building_scene.instantiate() as Node3D
		scene.add_child(torch)
		torch.global_position = grid.grid_to_world(dark_cell)
		torch.set_building_data(data)
		torch.set_build_grid_occupancy(dark_cell, Vector2i.ONE, 0)
		_expect(is_equal_approx(float(torch.get("lifetime")), 120.0), "火把持续时间不是 120 秒")
		var original_position: Vector3 = torch.global_position
		var cell_size: float = scene.get_node("Systems/MapGenerateRuntime").map_data.cell_size_m
		for layer: int in range(WFCHeightControl.MAX_LEVEL + 1):
			torch.global_position.y = float(layer + 1) * cell_size * WFCHeightControl.LEVEL_HEIGHT
			_expect(is_equal_approx(torch.get_sight_radius(), 12.0 * (1.0 + 0.2 * layer)), "火把高台视野加成错误：第 %d 层" % layer)
		torch.global_position.y = cell_size * 2.0 * WFCHeightControl.LEVEL_HEIGHT
		fog.visibility_map.fill(Color.BLACK)
		fog._reveal_at(Vector3.ZERO, torch.get_sight_radius())
		_expect(fog.is_visible_at(Vector3(13, 0, 0)), "高台火把实际视野没有扩展")
		_expect(not fog.is_visible_at(Vector3(15, 0, 0)), "高台火把实际视野扩展过大")
		torch.global_position = original_position
		fog.refresh_visibility()
		_expect(fog.is_visible_at(torch.global_position), "完工火把没有提供视野")
		torch.set("elapsed", 30.0)
		var panel: ResourceBuildingPanel = scene.get_node("UI/ResourceBuildingPanel") as ResourceBuildingPanel
		panel.current_building = torch
		panel.refresh()
		_expect(is_equal_approx(panel.demolition_progress_bar.value, 75.0), "火把面板剩余时间进度条错误")
		_expect(panel.material_label.text.contains("剩余时间"), "火把面板没有显示倒计时")
		if "--preview" in OS.get_cmdline_user_args():
			panel.open_building(torch)
			for frame: int in range(30):
				await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://.godot/torch_panel_preview.png")
		var elapsed_before_pause: float = float(torch.get("elapsed"))
		paused = true
		for frame: int in range(3):
			await process_frame
		paused = false
		_expect(is_equal_approx(float(torch.get("elapsed")), elapsed_before_pause), "暂停时火把仍在计时")
		panel.current_building = null
		torch.set("elapsed", float(torch.get("lifetime")))
		await process_frame
		await process_frame
		fog.refresh_visibility()
		_expect(not is_instance_valid(torch), "火把到期后没有删除")
		_expect(grid.is_area_free(dark_cell, Vector2i.ONE, 0, false, true), "火把到期后没有释放占地")
		_expect(not fog.is_visible_at(grid.grid_to_world(dark_cell)), "火把到期后视野没有消失")
	scene.queue_free()
	await process_frame
	print("火把建筑测试", "失败" if failed else "通过")
	quit(1 if failed else 0)
