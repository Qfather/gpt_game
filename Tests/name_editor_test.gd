extends SceneTree

var failed := false

func _init() -> void:
	call_deferred("_schedule")

func _schedule() -> void:
	create_timer(5).timeout.connect(_run)

func _expect(value: bool, text: String) -> void:
	print("[", "通过" if value else "失败", "] ", text)
	if not value:
		failed = true
		push_error(text)

func _run() -> void:
	var panel: TabContainer = load("res://addons/resource_editor/unit_editor_panel.gd").new()
	root.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await process_frame
	var tabs: TabContainer = panel.name_panel
	_expect(panel.get_tab_title(0) == "单位详情" and panel.get_tab_title(1) == "名称", "插件顶部是全局单位详情和名称页签")
	_expect(tabs.get_tab_count() == 3 and tabs.get_tab_title(0) == "怪物名称" and tabs.get_tab_title(1) == "人类名称" and tabs.get_tab_title(2) == "BOSS名称", "名称页下有三个独立类别")
	var monster: Control = tabs.get_child(0)
	var human: Control = tabs.get_child(1)
	var boss: Control = tabs.get_child(2)
	_expect(monster.pool_path.ends_with("EnemyNames.tres") and human.pool_path.ends_with("HumanNames.tres") and boss.pool_path.ends_with("BossNames.tres"), "三个类别分别加载全局名称池")
	_expect(human.rows["surnames"].visible and not human.rows["full_names"].visible and boss.rows["full_names"].visible and not monster.rows["surnames"].visible, "人类显示姓与名，怪物和BOSS显示完整名称")
	human.fields["surnames"].text = "欧阳\n陆"
	human.fields["given_names"].text = "青禾\n长风"
	human.pool_name.text = "测试姓名池"
	human.generate_preview()
	_expect(human.preview.text.contains("青禾") or human.preview.text.contains("长风"), "未保存内容可生成预览")
	for index: int in range(panel.items.size()):
		if panel.items[index] is EnemyData:
			panel.select_unit(index)
			break
	_expect(human.fields["surnames"].text == "欧阳\n陆" and monster.pool_path.ends_with("EnemyNames.tres"), "切换单位不会切换或重置全局名称页")
	human.fields["given_names"].text = ""
	human.fields["characters"].text = "青\n禾"
	human.generate_preview()
	_expect(not human.preview.text.is_empty(), "空名字池可预览两个备用字")
	var unit_before: Resource = panel.current.duplicate(true)
	for page: Control in [human, monster, boss]:
		page.pool_path = "res://.godot/global_names_%s.tres" % page.name
		human.fields["characters"].text = "长风"
	_expect(not human.save_pool(), "备用字每行多字时拒绝保存")
	human.fields["characters"].text = "青\n禾"
	monster.fields["full_names"].text = "碎牙测试\n赤角测试"
	boss.fields["full_names"].text = "深渊之王测试\n织母测试"
	for page: Control in [human, monster, boss]:
		_expect(page.save_pool(), "独立保存%s到测试副本" % page.name)
		var reloaded: Resource = ResourceLoader.load(page.pool_path, "", ResourceLoader.CACHE_MODE_IGNORE)
		_expect(reloaded.full_names == page.pool.full_names and reloaded.surnames == page.pool.surnames, "保存内容可实际重载：%s" % page.name)
	_expect(panel.current.fixed_name == unit_before.fixed_name and panel.current.display_name == unit_before.display_name, "保存全局名称不修改当前单位配置")
	panel.current_tab = 1
	tabs.current_tab = 1
	human.generate_preview()
	await create_timer(0.3).timeout
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/name_editor_global_preview.png")
		tabs.current_tab = 2
		boss.generate_preview()
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/name_editor_boss_preview.png")
		panel.current_tab = 0
		await create_timer(0.3).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/name_editor_details_preview.png")
	panel.queue_free()
	await process_frame
	quit(1 if failed else 0)
