extends SceneTree

var failed: bool = false

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var panel: Control = load("res://addons/resource_editor/raid_editor_panel.gd").new()
	root.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await process_frame
	var editor: Control = panel.camp_editor_panel
	panel.level_flow.camp_config = load("res://data/camps/camp_spawn_v0.tres")
	editor.edit_preset(panel.level_flow)
	var source: CampSpawnConfig = panel.level_flow.camp_config
	_expect(editor.pool_list.item_count == 2, "营地页加载本关随机池")
	editor._make_local()
	_expect(panel.level_flow.camp_config != source, "复制为本关独有时同时隔离共享刷新配置")
	_expect(panel.level_flow.camp_config.camp_pool[0].camp != source.camp_pool[0].camp, "营地方案复制不会修改共享方案")
	panel.level_flow.camp_config.camp_pool[1].start_time = 700.0
	_expect(source.camp_pool[1].start_time == 600.0, "复制后其他方案的本关时间设置也独立")
	editor.controls["maximum_camps"].value = 3
	_expect(panel.level_flow.camp_config.maximum_camps == 3 and source.maximum_camps == 2, "修改刷新参数只影响本关副本")
	var initial: int = editor.pool_list.item_count
	editor._add_entry()
	_expect(editor.pool_list.item_count == initial + 1, "可添加带默认守卫和奖励的新营地")
	editor._remove_entry()
	_expect(editor.pool_list.item_count == initial, "可移除营地")
	# 保存测试全部使用副本，不覆盖项目现有关卡或共享营地资源。
	panel.level_flow = panel.level_flow.duplicate(true)
	editor.edit_preset(panel.level_flow)
	panel.database = panel.database.duplicate(true)
	panel.database.take_over_path("res://.godot/test_camp_editor_database.tres")
	panel.preset_path = "res://.godot/test_camp_editor_level.tres"
	_expect(panel._save_all(), "统一保存入口支持营地配置")
	var saved: LevelFlowData = ResourceLoader.load(panel.preset_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP)
	_expect(saved.camp_config.maximum_camps == 3 and saved.camp_config.camp_pool.size() == 2, "营地设置和池随关卡保存并正确读回")
	if "--preview" in OS.get_cmdline_user_args():
		root.size = Vector2i(1440, 1000)
		for child: Node in panel.get_children():
			if child is TabContainer:
				child.current_tab = 2
		editor.pool_list.select(0)
		editor._select_entry(0)
		await create_timer(1.0).timeout
		for button: Node in editor.inspector.find_children("*", "Button", true, false):
			if button is Button and button.text == "TreasureCampData":
				if button.toggle_mode:
					button.button_pressed = true
				button.pressed.emit()
				break
		await create_timer(0.8).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/camp_editor_preview.png")
	panel.queue_free()
	await process_frame
	print("营地关卡编辑测试", "失败" if failed else "通过")
	quit(1 if failed else 0)

func _expect(condition: bool, message: String) -> void:
	print("[", "通过" if condition else "失败", "] ", message)
	if not condition:
		failed = true
		push_error("失败：" + message)
