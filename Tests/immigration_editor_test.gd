extends SceneTree
func _init() -> void:
	call_deferred("_schedule")
func _schedule() -> void:
	create_timer(5).timeout.connect(_run)
func _run() -> void:
	var panel: Control = load("res://addons/resource_editor/raid_editor_panel.gd").new()
	root.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await process_frame
	panel.level_flow = panel.level_flow.duplicate(true)
	panel.level_flow.camp_config = null
	panel.environment_panel.edit_preset(panel.level_flow)
	var environment: Control = panel.environment_panel
	var tabs: TabContainer = environment.get_child(1)
	var column: Control = tabs.get_child(2)
	var groups: Array[ImmigrationGroup] = panel.level_flow.settlement_config.immigration_rules.groups
	assert(groups.size() == 7 and environment.immigration_list.item_count == 7)
	column.get_child(1).get_child(0).pressed.emit()
	assert(groups.size() == 8 and environment.immigration_list.item_count == 8)
	column.get_child(1).get_child(1).pressed.emit()
	assert(groups.size() == 7)
	var group: ImmigrationGroup = groups[3]
	group.food_amount = 23
	environment._refresh_immigration_list(3)
	assert(environment.immigration_inspector.get_edited_object() == group)
	assert(load("res://data/levels/LevelFlow_V0.tres").settlement_config.immigration_rules.groups[3].food_amount == 20)
	assert(load("res://data/levels/LevelFlow_40min_Hard.tres").settlement_config.immigration_rules.groups[3].food_amount == 20)
	panel.database = panel.database.duplicate(true)
	panel.database.take_over_path("res://.godot/immigration_editor_database.tres")
	panel.selected_event = null
	panel.selected_group = null
	panel.preset_path = "res://.godot/immigration_editor_level.tres"
	assert(panel._save_all())
	var saved: LevelFlowData = ResourceLoader.load(panel.preset_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP)
	var restored: ImmigrationGroup = saved.settlement_config.immigration_rules.groups[3]
	assert(restored.food_amount == 23 and restored.food_tag == &"meat")
	assert(restored.required_buildings[0].id == &"house")
	assert(restored.resident_traits[0].get_trait_id() == "likes_meat")
	assert(restored.resident_traits[0].trait_data.preferred_nutrition_multiplier == 1.25)
	assert(restored.resource_path.contains("::"))
	assert(restored.resident_traits[0].trait_data.resource_path.contains("::"))
	assert(saved.events.size() == 27)
	if DisplayServer.get_name() != "headless":
		root.size = Vector2i(1440, 1000)
		tabs.current_tab = 2
		environment.get_parent().current_tab = 1
		await create_timer(0.8).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/immigration_editor_preview.png")
	panel.queue_free()
	await process_frame
	print("移民池插件测试通过：添加移除、阶段、食物标签、建筑、居民标签、隔离保存读回")
	quit()
