extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var panel_script: Script = load("res://addons/resource_editor/raid_editor_panel.gd") as Script
	_expect(panel_script != null, "可加载关卡事件编辑器脚本")
	var panel: Control = panel_script.new() as Control
	_expect(panel != null, "可实例化关卡事件编辑器")
	root.add_child(panel)
	await process_frame
	_expect(panel.get_child_count() > 0, "事件编辑器完成界面构建")
	var timeline: Tree = panel.find_child("EventTimeline", true, false) as Tree
	_expect(timeline != null, "时间线控件已建立")
	_expect(timeline.columns == 5, "时间线为五列表头")
	_expect(timeline.get_column_title(0) == "出场时间名", "第一列为出场事件名")
	_expect(timeline.get_column_title(1) == "怪物组", "第二列为怪物组")
	_expect(timeline.get_column_title(2) == "组模式", "第三列为组模式")
	_expect(timeline.get_column_title(3) == "出场时间", "第四列为出场时间")
	_expect(timeline.get_column_title(4) == "BOSS定位", "第五列为BOSS定位")
	_expect(panel.find_child("AddGroupButton", true, false) != null, "怪物组增删按钮位于详情标题行")
	_expect(panel.find_child("AddEventButton", true, false) != null, "事件增删按钮位于事件配置标题行")
	var item: TreeItem = timeline.get_root().get_first_child()
	var previous_time: float = -1.0
	var event_count: int = 0
	while item != null:
		var event: LevelEventEntry = item.get_metadata(0) as LevelEventEntry
		_expect(event != null, "时间线项目关联关卡事件")
		_expect(event.start_time >= previous_time, "时间线按基础出现时间排序")
		previous_time = event.start_time
		_expect(not item.get_text(0).is_empty(), "时间线显示出场事件名")
		_expect(item.get_text(2) in ["固定", "随机"], "时间线单独显示组模式列")
		_expect(item.get_text(4) in ["普通", "BOSS", "关底BOSS"], "时间线显示BOSS定位且自动标出关底BOSS")
		var group: RaidGroupData = event.get_monster_group()
		var expected_color: Color = Color(0.72, 0.43, 1.0) if group.group_type == RaidGroupData.GroupType.RIFT else Color(1.0, 0.60, 0.32)
		for column: int in range(timeline.columns):
			_expect(item.get_custom_color(column).is_equal_approx(expected_color), "整行按袭扰/裂缝使用阵营颜色")
		event_count += 1
		item = item.get_next()
	var flow: LevelFlowData = panel.get("level_flow") as LevelFlowData
	_expect(event_count == flow.events.filter(func(event: LevelEventEntry) -> bool: return event != null and event.get_monster_group() != null).size(), "时间线显示所有有效引用的事件")
	panel.call("_add_group_pressed")
	var unit_group: RaidGroupData = panel.get("selected_group") as RaidGroupData
	_expect(unit_group.unit_data.size() == 1 and unit_group.unit_data[0] == null, "新建怪物组时初始化一个空单位槽")
	var candidates: Array[EnemyData] = panel.call("_get_available_units_for_group", unit_group)
	_expect(not candidates.is_empty(), "新袭扰组可从袭扰阵营单位资源中选择")
	for candidate: EnemyData in candidates:
		_expect(candidate.faction == EnemyData.Faction.RAID and not candidate.is_boss, "袭扰普通组候选仅来自袭扰普通单位")
	var rift_group := RaidGroupData.new()
	rift_group.group_type = RaidGroupData.GroupType.RIFT
	var rift_candidates: Array[EnemyData] = panel.call("_get_available_units_for_group", rift_group)
	_expect(not rift_candidates.is_empty(), "裂缝组可以列出裂缝阵营怪物")
	for candidate: EnemyData in rift_candidates:
		_expect(candidate.faction == EnemyData.Faction.RIFT and not candidate.is_boss, "裂缝普通组候选仅来自裂缝普通单位")
	panel.call("_add_unit_pressed")
	var popup: PopupMenu = panel.find_child("UnitSelectionPopup", true, false) as PopupMenu
	_expect(popup != null and popup.item_count == candidates.size(), "添加单位弹出本阵营尚未加入组内的候选列表")
	panel.call("_on_unit_chosen", popup.get_item_id(0), popup, unit_group)
	await process_frame
	_expect(unit_group.unit_data.has(candidates[0]), "选择单位后写入当前怪物组")
	_expect((panel.get("unit_rows") as VBoxContainer).get_child_count() == 1, "添加后立即显示组内单位行")
	panel.call("_add_event_pressed")
	var added_event: LevelEventEntry = panel.get("selected_event") as LevelEventEntry
	_expect(added_event != null and not added_event.event_name.is_empty(), "新增事件自动命名")
	panel.call("_delete_group_pressed")
	var confirmation: ConfirmationDialog = panel.get("delete_group_dialog") as ConfirmationDialog
	_expect(confirmation.dialog_text.contains(unit_group.display_name) and confirmation.dialog_text.contains(added_event.event_name), "删除被引用怪物组时列出相关事件并请求确认")
	confirmation.confirmed.emit()
	_expect(not (panel.get("database") as RaidGroupDatabase).groups.has(unit_group), "确认后删除怪物组")
	_expect(not flow.events.has(added_event), "确认后同时删除引用事件")
	print("关卡事件编辑器加载测试通过")
	quit()

func _expect(condition: bool, message: String) -> void:
	if not condition:
		push_error("失败：" + message)
		quit(1)
