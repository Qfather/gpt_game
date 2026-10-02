extends SceneTree

func _init() -> void:
	call_deferred("_schedule")

func _schedule() -> void:
	create_timer(5).timeout.connect(_run)

func _run() -> void:
	var tabs := TabContainer.new()
	root.add_child(tabs)
	tabs.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var buildings: Control = load("res://addons/resource_editor/building_editor_panel.gd").new()
	buildings.name = "建筑"
	tabs.add_child(buildings)
	for i: int in range(buildings.buildings.size()):
		if buildings.buildings[i].id not in [&"hunter_hut", &"archer_camp", &"arrow_tower"]: continue
		buildings.select_building(i)
		assert(buildings.preview.mesh_count > 0)
		if buildings.current.id == &"hunter_hut": assert(buildings.field_controls.has(".:processing_min"))
		if buildings.current.id == &"archer_camp": assert(buildings.field_controls.has(".:training_role"))
		if buildings.current.id == &"arrow_tower": assert(buildings.field_controls.has(".:attack_range_multiplier"))
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			buildings.preview.viewport.get_texture().get_image().save_png("res://.godot/ranged_model_" + String(buildings.current.id) + ".png")
	var units: Control = load("res://addons/resource_editor/unit_editor_panel.gd").new()
	units.name = "单位"
	tabs.add_child(units)
	tabs.current_tab = 1
	for i: int in range(units.items.size()):
		if units.items[i].get("id") not in [&"hunter", &"archer"]: continue
		units.select_unit(i)
		assert(units.current.uses_arrows and units.preview.mesh_count > 0)
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			units.preview.viewport.get_texture().get_image().save_png("res://.godot/ranged_model_" + String(units.current.id) + ".png")
	var level: Control = load("res://addons/resource_editor/level_environment_panel.gd").new()
	level.name = "地图与资源"
	tabs.add_child(level)
	tabs.current_tab = 2
	var preset: LevelFlowData = load("res://data/levels/LevelFlow_40min_Hard.tres").duplicate(true)
	level.edit_preset(preset)
	level.get_child(1).current_tab = 1
	assert(preset.wildlife_config.prey_pool.size() == 3)
	preset.wildlife_config.maximum_animals = 7
	preset.wildlife_config.prey_pool[0].meat_yield = 4
	assert(ResourceSaver.save(preset, "res://.godot/ranged_editor_level.tres") == OK)
	var saved: LevelFlowData = ResourceLoader.load("res://.godot/ranged_editor_level.tres", "", ResourceLoader.CACHE_MODE_IGNORE_DEEP)
	assert(saved.wildlife_config.maximum_animals == 7 and saved.wildlife_config.prey_pool[0].meat_yield == 4)
	assert(load("res://data/levels/LevelFlow_40min_Hard.tres").wildlife_config.maximum_animals == 12)
	assert(load("res://data/wildlife/rabbit.tres").meat_yield == 1)
	if DisplayServer.get_name() != "headless":
		root.size = Vector2i(1440, 900)
		for i: int in range(8): await process_frame
		level._translate_node(level.wildlife_inspector)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/ranged_editor_level.png")
	print("狩猎与远程编辑器测试通过：新增建筑／单位模型渲染、专属参数、关卡猎物保存读回与隔离")
	tabs.queue_free()
	await process_frame
	quit()
