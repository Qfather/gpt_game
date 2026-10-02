extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var panel: Control = load("res://addons/resource_editor/raid_editor_panel.gd").new()
	root.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await process_frame
	assert(panel.preset_path == "res://data/levels/LevelFlow_40min_Hard.tres")
	assert(panel.timeline.get_root().get_child_count() == 27)
	for group_id: StringName in [&"hard40_01", &"hard40_03"]:
		var available: Array[EnemyData] = panel._get_available_units_for_group(panel.database.get_group(group_id))
		var names: Array[String] = []
		for unit: EnemyData in available:
			names.append(unit.display_name)
		assert("骷髅" in names and "小恶魔" in names and "食人魔" in names)
	var item: TreeItem = panel.timeline.get_root().get_first_child()
	while item.get_next() != null:
		item = item.get_next()
	item.select(0)
	panel._on_timeline_selected()
	assert(panel.start_time_spin.value == 2400 and item.get_text(4) == "关底BOSS")
	if DisplayServer.get_name() != "headless":
		root.size = Vector2i(1440, 1000)
		await create_timer(0.5).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/forty_minute_editor_preview.png")
	# 保存到临时副本，仅验证事件编辑器的统一保存，不写入共享营地方案。
	panel.level_flow = panel.level_flow.duplicate(true)
	panel.level_flow.camp_config = null
	panel.database = panel.database.duplicate(true)
	panel.database.take_over_path("res://.godot/forty_minute_editor_database.tres")
	panel.selected_event = null
	panel.selected_group = null
	panel.preset_path = "res://.godot/forty_minute_editor_level.tres"
	assert(panel._save_all())
	var saved: LevelFlowData = ResourceLoader.load(panel.preset_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP)
	assert(saved.events.size() == 27 and saved.get_final_rift_boss_event().start_time == 2400)
	panel.queue_free()
	await process_frame
	print("40分钟困难关卡插件测试通过：时间线、敌人选择、关底标记与保存读回")
	quit()
