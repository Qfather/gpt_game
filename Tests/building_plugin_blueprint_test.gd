extends SceneTree

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	var panel: Control = load("res://addons/resource_editor/building_editor_panel.gd").new()
	root.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await process_frame
	for index: int in range(panel.buildings.size()):
		if panel.buildings[index].id == &"militia_camp": panel.select_building(index)
	assert(panel.current.id == &"militia_camp")
	assert(panel.recipe_list.get_child_count() >= 3)
	var name := "test_blueprint_editor_%d" % OS.get_process_id()
	var path := "res://data/buildings/" + name + ".tres"
	assert(not FileAccess.file_exists(path))
	panel._show_create_building()
	var dialog: ConfirmationDialog
	for node: Node in panel.get_children():
		if node is ConfirmationDialog: dialog = node
	assert(dialog != null)
	var fields: VBoxContainer = dialog.get_child(0)
	fields.get_child(0).text = name
	fields.get_child(1).text = "测试：可配置营地"
	dialog.confirmed.emit()
	dialog.hide()
	await process_frame
	assert(FileAccess.file_exists(path) and panel.current.id == StringName(name))
	panel.current.tier = 1
	panel.current.blueprint_pool = &"test_pool"
	panel.current.upgrade_from_id = &"militia_camp"
	panel.current.allow_direct_build = false
	panel.current.upgrade_cost.assign({&"wood": 7.0})
	panel.current.upgrade_time = 8.0
	panel.current.training_recipes[0].time_seconds = 12.0
	panel.current.training_slots = 3
	assert(panel.save_current())
	var restored: BuildingData = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	assert(restored.tier == 1 and restored.blueprint_pool == &"test_pool")
	assert(restored.upgrade_from_id == &"militia_camp" and restored.training_slots == 3)
	assert(restored.training_recipes[0].time_seconds == 12.0)
	assert(load("res://data/buildings/MilitiaCampData.tres").training_recipes[0].time_seconds == 10.0)
	panel.current.upgrade_from_id = panel.current.id
	assert(not panel.save_current(), "非法前置关联不能保存")
	panel.current.upgrade_from_id = &"militia_camp"
	panel.current.training_recipes[0].cost.assign({&"not_a_resource": 5.0})
	assert(not panel.save_current(), "非法材料ID不能保存")
	panel.current.training_recipes[0].cost.assign({&"wood": 5.0})
	assert(panel.save_current())
	panel._update_evolution_fields()
	panel._update_training_fields()
	if DisplayServer.get_name() != "headless":
		panel.tabs.current_tab = 3
		for frame: int in range(5): await process_frame
		await create_timer(0.2).timeout
		RenderingServer.force_draw(false)
		root.get_texture().get_image().save_png("res://.godot/building_blueprint_plugin.png")
		panel.tabs.current_tab = 4
		for frame: int in range(5): await process_frame
		await create_timer(0.2).timeout
		RenderingServer.force_draw(false)
		root.get_texture().get_image().save_png("res://.godot/building_training_plugin.png")
	panel._show_delete_building()
	dialog = null
	for node: Node in panel.get_children():
		if node is ConfirmationDialog: dialog = node
	assert(dialog != null)
	dialog.confirmed.emit()
	dialog.hide()
	await process_frame
	assert(not FileAccess.file_exists(path))
	panel.queue_free()
	await process_frame
	print("建筑插件新建、等级／池／前置／训练保存、非法配置拒绝和删除测试通过")
	quit()
