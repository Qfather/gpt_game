extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var panel: Control = load("res://addons/resource_editor/raid_editor_panel.gd").new()
	root.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await process_frame
	var environment: Control = panel.environment_panel
	var initial: int = panel.level_flow.map_resources.size()
	environment._add_resource()
	assert(panel.level_flow.map_resources.size() == initial + 1)
	environment._remove_resource()
	assert(panel.level_flow.map_resources.size() == initial)
	assert(environment.map_inspector.get_edited_object() == panel.level_flow.map_config)
	assert(panel.timeline.get_root().get_child_count() == panel.level_flow.events.size())
	panel.database = panel.database.duplicate(true)
	panel.database.take_over_path("res://.godot/test_raid_database.tres")
	panel.preset_path = "res://.godot/test_editor_level.tres"
	assert(panel._save_all())
	var saved: LevelFlowData = ResourceLoader.load(panel.preset_path, "", ResourceLoader.CACHE_MODE_IGNORE) as LevelFlowData
	assert(saved.map_resources.size() == initial and saved.map_config != null)
	print("关卡编辑面板测试通过：地图检查器、资源增删、原出怪时间线、统一保存")
	if "--preview" in OS.get_cmdline_user_args():
		root.size = Vector2i(1440, 1000)
		for child: Node in panel.get_children():
			if child is TabContainer:
				(child as TabContainer).current_tab = 1
		await process_frame
		await process_frame
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/level_editor_preview.png")
	panel.queue_free()
	await process_frame
	quit()

