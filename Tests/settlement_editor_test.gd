extends SceneTree
func _init() -> void:
	call_deferred("_run")
func _run() -> void:
	var panel: Control = load("res://addons/resource_editor/raid_editor_panel.gd").new()
	root.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await process_frame
	panel.level_flow = panel.level_flow.duplicate(true)
	panel.level_flow.camp_config = null
	panel.environment_panel.edit_preset(panel.level_flow)
	var environment: Control = panel.environment_panel
	assert(environment.settlement_fields.size() == 10)
	for field: Dictionary in environment.settlement_fields:
		if field.key == "initial_wood": field.spin.value = 321
		if field.key == "initial_villagers": field.spin.value = 4
		if field.key == "max_group_size": field.spin.value = 3
	assert(panel.level_flow.settlement_config.initial_wood == 321)
	assert(panel.level_flow.settlement_config.initial_villagers == 4)
	assert(panel.level_flow.settlement_config.immigration_rules.max_group_size == 3)
	assert(load("res://data/levels/Level_01.tres").initial_wood == 200)
	assert(load("res://data/population/immigration_rules.tres").max_group_size == 2)
	panel.database = panel.database.duplicate(true)
	panel.database.take_over_path("res://.godot/settlement_editor_database.tres")
	panel.selected_event = null
	panel.selected_group = null
	panel.preset_path = "res://.godot/settlement_editor_level.tres"
	assert(panel._save_all())
	var saved: LevelFlowData = ResourceLoader.load(panel.preset_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP)
	assert(saved.settlement_config.initial_wood == 321 and saved.settlement_config.initial_villagers == 4)
	assert(saved.settlement_config.immigration_rules.max_group_size == 3)
	assert(saved.settlement_config.resource_path.contains("::"))
	assert(saved.settlement_config.immigration_rules.resource_path.contains("::"))
	if DisplayServer.get_name() != "headless":
		root.size = Vector2i(1440, 1000)
		var tabs: TabContainer = environment.get_child(1)
		tabs.current_tab = 1
		var parent_tabs: TabContainer = environment.get_parent()
		parent_tabs.current_tab = 1
		await create_timer(0.5).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/settlement_editor_preview.png")
	panel.queue_free()
	await process_frame
	print("初始资源与人口插件测试通过：中文字段、修改、隔离、嵌入保存读回")
	quit()
