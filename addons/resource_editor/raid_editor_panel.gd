@tool
extends VBoxContainer

const DATABASE_PATH: String = "res://data/enemies/raid/RaidGroups.tres"
const LEVEL_FLOW_PATH: String = "res://data/levels/LevelFlow_V0.tres"
const RAID_UNIT_FOLDER: String = "res://data/enemies/raid/"
const RIFT_UNIT_FOLDER: String = "res://data/enemies/rift/"

var database: RaidGroupDatabase
var level_flow: LevelFlowData
var selected_group: RaidGroupData
var selected_event: LevelEventEntry

var timeline: Tree
var group_option: OptionButton
var name_edit: LineEdit
var type_option: OptionButton
var fixed_mode_button: Button
var random_mode_button: Button
var boss_group_check: CheckBox
var unit_rows: VBoxContainer
var add_unit_button: Button
var event_name_edit: LineEdit
var start_time_spin: SpinBox
var random_offset_spin: SpinBox
var random_total_spin: SpinBox
var repeat_check: CheckBox
var repeat_interval_spin: SpinBox
var rift_wave_count_spin: SpinBox
var rift_wave_interval_spin: SpinBox
var rift_countdown_spin: SpinBox
var config_rows: Array[Control] = []
var type_specific_rows: Array[Control] = []
var delete_group_dialog: ConfirmationDialog
var pending_delete_group: RaidGroupData
var preset_path: String = LEVEL_FLOW_PATH
var preset_path_label: Label
var environment_panel: Control
var preset_dialog: EditorFileDialog


func _ready() -> void:
	add_to_group("raid_editor_panels")
	custom_minimum_size = Vector2(900.0, 420.0)
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	_build_ui()
	_build_preset_tabs()
	_load_resources()


func _build_preset_tabs() -> void:
	var original_controls: Array[Node] = get_children()
	var toolbar := HBoxContainer.new()
	add_child(toolbar)
	_add_button(toolbar, "打开关卡预设", _open_preset)
	_add_button(toolbar, "保存关卡", _save_all)
	_add_button(toolbar, "另存为关卡预设", _save_preset_as)
	preset_path_label = Label.new()
	toolbar.add_child(preset_path_label)
	var tabs := TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(tabs)
	var events_panel := VBoxContainer.new()
	events_panel.name = "出怪事件"
	tabs.add_child(events_panel)
	for control: Node in original_controls:
		control.reparent(events_panel)
	environment_panel = preload("res://addons/resource_editor/level_environment_panel.gd").new()
	environment_panel.name = "地图与资源"
	tabs.add_child(environment_panel)
	preset_dialog = EditorFileDialog.new()
	preset_dialog.access = EditorFileDialog.ACCESS_RESOURCES
	preset_dialog.add_filter("*.tres", "关卡预设")
	preset_dialog.file_selected.connect(_preset_file_selected)
	add_child(preset_dialog)


func _open_preset() -> void:
	# 显式提醒，避免切换预设时悄悄丢弃未保存修改。
	var confirm := ConfirmationDialog.new()
	confirm.dialog_text = "打开其他预设将放弃当前未保存的修改，是否继续？"
	add_child(confirm)
	confirm.confirmed.connect(func() -> void:
		confirm.hide()
		confirm.queue_free()
		call_deferred("_show_open_preset")
	)
	confirm.canceled.connect(confirm.queue_free)
	confirm.popup_centered()


func _show_open_preset() -> void:
	preset_dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
	preset_dialog.popup_centered_ratio(0.7)


func _save_preset_as() -> void:
	preset_dialog.file_mode = EditorFileDialog.FILE_MODE_SAVE_FILE
	preset_dialog.current_dir = "res://data/levels"
	preset_dialog.current_file = "NewLevel.tres"
	preset_dialog.popup_centered_ratio(0.7)


func _preset_file_selected(path: String) -> void:
	if preset_dialog.file_mode == EditorFileDialog.FILE_MODE_OPEN_FILE:
		if not ResourceLoader.load(path) is LevelFlowData:
			push_error("所选文件不是关卡预设")
			return
		preset_path = path
		_load_resources()
	else:
		var previous_path: String = preset_path
		preset_path = path
		if not _save_all():
			preset_path = previous_path


func _build_ui() -> void:
	var toolbar := HBoxContainer.new()
	add_child(toolbar)
	var title := Label.new()
	title.text = "关卡怪物事件"
	title.add_theme_font_size_override("font_size", 20)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toolbar.add_child(title)
	_add_button(toolbar, "保存全部", _save_all)
	_add_button(toolbar, "刷新时间线", _refresh_pressed)
	delete_group_dialog = ConfirmationDialog.new()
	delete_group_dialog.title = "删除怪物组"
	delete_group_dialog.confirmed.connect(_on_delete_group_confirmed)
	add_child(delete_group_dialog)

	timeline = Tree.new()
	timeline.name = "EventTimeline"
	timeline.custom_minimum_size.y = 150.0
	timeline.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	timeline.hide_root = true
	timeline.columns = 5
	timeline.set_column_titles_visible(true)
	timeline.set_column_title(0, "出场时间名")
	timeline.set_column_title(1, "怪物组")
	timeline.set_column_title(2, "组模式")
	timeline.set_column_title(3, "出场时间")
	timeline.set_column_title(4, "BOSS定位")
	timeline.set_column_expand(0, true)
	timeline.set_column_expand(1, true)
	timeline.set_column_expand(2, false)
	timeline.set_column_expand(3, false)
	timeline.set_column_custom_minimum_width(1, 150)
	timeline.set_column_custom_minimum_width(2, 78)
	timeline.set_column_custom_minimum_width(3, 150)
	timeline.set_column_custom_minimum_width(4, 90)
	timeline.item_selected.connect(_on_timeline_selected)
	add_child(timeline)

	var body := HSplitContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(body)
	var group_panel := VBoxContainer.new()
	group_panel.custom_minimum_size.x = 420.0
	body.add_child(group_panel)
	var group_title := HBoxContainer.new()
	group_panel.add_child(group_title)
	var group_title_label := Label.new()
	group_title_label.text = "怪物组详情"
	group_title_label.add_theme_font_size_override("font_size", 16)
	group_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	group_title.add_child(group_title_label)
	var add_group_button := _add_button(group_title, "+", _add_group_pressed)
	add_group_button.name = "AddGroupButton"
	add_group_button.tooltip_text = "添加怪物组"
	var delete_group_button := _add_button(group_title, "−", _delete_group_pressed)
	delete_group_button.name = "DeleteGroupButton"
	delete_group_button.tooltip_text = "删除怪物组"
	group_option = OptionButton.new()
	group_option.item_selected.connect(_on_group_option_selected)
	group_panel.add_child(group_option)
	name_edit = LineEdit.new()
	name_edit.placeholder_text = "怪物组名称"
	_add_row(group_panel, "组名称", name_edit)
	type_option = OptionButton.new()
	type_option.add_item("袭扰", RaidGroupData.GroupType.RAID)
	type_option.add_item("裂缝", RaidGroupData.GroupType.RIFT)
	type_option.item_selected.connect(_on_group_type_selected)
	_add_row(group_panel, "组类型", type_option)
	var mode_row := HBoxContainer.new()
	group_panel.add_child(mode_row)
	boss_group_check = CheckBox.new()
	boss_group_check.text = "BOSS组（仅选择本阵营的BOSS单位）"
	boss_group_check.toggled.connect(_on_boss_group_toggled)
	group_panel.add_child(boss_group_check)
	var mode_label := Label.new()
	mode_label.text = "组模式"
	mode_label.custom_minimum_size.x = 100.0
	mode_row.add_child(mode_label)
	var mode_group := ButtonGroup.new()
	fixed_mode_button = Button.new()
	fixed_mode_button.text = "固定"
	fixed_mode_button.toggle_mode = true
	fixed_mode_button.button_group = mode_group
	fixed_mode_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fixed_mode_button.toggled.connect(_on_fixed_mode_toggled)
	mode_row.add_child(fixed_mode_button)
	random_mode_button = Button.new()
	random_mode_button.text = "随机"
	random_mode_button.toggle_mode = true
	random_mode_button.button_group = mode_group
	random_mode_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	random_mode_button.toggled.connect(_on_random_mode_toggled)
	mode_row.add_child(random_mode_button)
	var member_title := Label.new()
	member_title.text = "组内单位（固定：个数；随机：出现概率权重）"
	group_panel.add_child(member_title)
	var unit_scroll := ScrollContainer.new()
	unit_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	unit_scroll.custom_minimum_size.y = 180.0
	group_panel.add_child(unit_scroll)
	unit_rows = VBoxContainer.new()
	unit_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	unit_scroll.add_child(unit_rows)
	add_unit_button = _add_button(group_panel, "+ 添加单位", _add_unit_pressed)
	add_unit_button.name = "AddUnitButton"

	var config_scroll := ScrollContainer.new()
	config_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	config_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(config_scroll)
	var config_panel := VBoxContainer.new()
	config_panel.custom_minimum_size.x = 430.0
	config_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	config_scroll.add_child(config_panel)
	var config_title := HBoxContainer.new()
	config_panel.add_child(config_title)
	var config_title_label := Label.new()
	config_title_label.text = "出场事件配置"
	config_title_label.add_theme_font_size_override("font_size", 16)
	config_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	config_title.add_child(config_title_label)
	var add_event_button := _add_button(config_title, "+", _add_event_pressed)
	add_event_button.name = "AddEventButton"
	add_event_button.tooltip_text = "添加出场事件"
	var delete_event_button := _add_button(config_title, "−", _delete_event_pressed)
	delete_event_button.name = "DeleteEventButton"
	delete_event_button.tooltip_text = "删除出场事件"
	event_name_edit = LineEdit.new()
	event_name_edit.placeholder_text = "出场事件名称"
	_add_config_row(config_panel, "事件名称", event_name_edit, config_rows)
	start_time_spin = _make_spin(config_panel, "出现时间", 0.0, 36000.0, 1.0, config_rows, " 秒")
	random_offset_spin = _make_spin(config_panel, "摇摆时间", 0.0, 3600.0, 1.0, config_rows, " 秒")
	random_total_spin = _make_spin(config_panel, "怪物总数", 1.0, 100.0, 1.0, config_rows, " 个")
	repeat_check = CheckBox.new()
	repeat_check.text = "重复出场"
	_add_config_row(config_panel, "重复", repeat_check, config_rows)
	repeat_interval_spin = _make_spin(config_panel, "重复间隔", 1.0, 3600.0, 1.0, config_rows, " 秒")
	rift_wave_count_spin = _make_spin(config_panel, "裂缝波数", 1.0, 10.0, 1.0, type_specific_rows)
	rift_wave_interval_spin = _make_spin(config_panel, "波间隔", 0.0, 600.0, 0.5, type_specific_rows, " 秒")
	rift_countdown_spin = _make_spin(config_panel, "裂缝倒计时", 0.0, 120.0, 0.5, type_specific_rows, " 秒")


func _add_button(parent: Control, caption: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = caption
	button.pressed.connect(callback)
	parent.add_child(button)
	return button


func _add_row(parent: VBoxContainer, caption: String, control: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var label := Label.new()
	label.text = caption
	label.custom_minimum_size.x = 100.0
	row.add_child(label)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(control)
	return row


func _add_config_row(parent: VBoxContainer, caption: String, control: Control, rows: Array[Control]) -> void:
	rows.append(_add_row(parent, caption, control))


func _make_spin(parent: VBoxContainer, caption: String, minimum: float, maximum: float, step: float, rows: Array[Control], suffix: String = "") -> SpinBox:
	var spin := SpinBox.new()
	spin.min_value = minimum
	spin.max_value = maximum
	spin.step = step
	spin.suffix = suffix
	_add_config_row(parent, caption, spin, rows)
	return spin


func _load_resources() -> void:
	selected_event = null
	selected_group = null
	level_flow = ResourceLoader.load(preset_path, "", ResourceLoader.CACHE_MODE_IGNORE) as LevelFlowData
	var database_path: String = DATABASE_PATH
	if level_flow != null and level_flow.monster_database != null and not level_flow.monster_database.resource_path.is_empty():
		database_path = level_flow.monster_database.resource_path
	database = ResourceLoader.load(database_path, "", ResourceLoader.CACHE_MODE_IGNORE) as RaidGroupDatabase
	if database == null or level_flow == null:
		push_error("关卡插件：怪物组数据库或关卡资源加载失败")
		return
	level_flow.monster_database = database
	environment_panel.edit_preset(level_flow)
	preset_path_label.text = preset_path
	_ensure_group_ids()
	for event: LevelEventEntry in level_flow.events:
		if event == null:
			continue
		event.monster_database = database
		if event.monster_group_id.is_empty() and event.monster_group != null:
			event.monster_group_id = event.monster_group.id
			event.monster_group = null
		if event.event_name.strip_edges().is_empty():
			var event_group: RaidGroupData = event.get_monster_group()
			event.event_name = event_group.display_name if event_group != null else "出场事件"
	_refresh_group_options()
	_refresh_timeline()
	if timeline.get_root() != null and timeline.get_root().get_first_child() != null:
		timeline.get_root().get_first_child().select(0)
		_on_timeline_selected()


func _ensure_group_ids() -> void:
	var used_ids: Dictionary = {}
	for group: RaidGroupData in database.groups:
		if group == null:
			continue
		var id_string: String = str(group.id)
		if id_string.is_empty() or used_ids.has(id_string):
			group.id = _make_unique_group_id()
			id_string = str(group.id)
		used_ids[id_string] = true


func _refresh_pressed() -> void:
	_save_all()
	_load_resources()


func _refresh_group_options() -> void:
	var selected_id: StringName = selected_group.id if selected_group != null else &""
	group_option.clear()
	for group: RaidGroupData in database.groups:
		if group == null:
			continue
		var index: int = group_option.item_count
		group_option.add_item("%s  [%s]" % [group.display_name, group.id])
		group_option.set_item_metadata(index, group)
	var target_index: int = 0
	for index: int in range(group_option.item_count):
		var group: RaidGroupData = group_option.get_item_metadata(index) as RaidGroupData
		if group != null and group.id == selected_id:
			target_index = index
			break
	if group_option.item_count > 0:
		group_option.select(target_index)
		_on_group_option_selected(target_index)
	else:
		selected_group = null
		_render_group()


func _refresh_timeline() -> void:
	timeline.clear()
	if level_flow == null:
		return
	var root: TreeItem = timeline.create_item()
	var sorted_events: Array = level_flow.events.duplicate()
	var final_boss_event: LevelEventEntry = level_flow.get_final_rift_boss_event()
	sorted_events.sort_custom(func(a: LevelEventEntry, b: LevelEventEntry) -> bool:
		return a.start_time < b.start_time
	)
	var selected_item: TreeItem
	for event: LevelEventEntry in sorted_events:
		if event == null:
			continue
		var group: RaidGroupData = event.get_monster_group()
		if group == null:
			continue
		var item: TreeItem = timeline.create_item(root)
		var is_rift: bool = group.group_type == RaidGroupData.GroupType.RIFT
		item.set_text(0, event.event_name if not event.event_name.strip_edges().is_empty() else group.display_name)
		item.set_text(1, group.display_name)
		item.set_text(2, "随机" if group.spawn_mode == RaidGroupData.SpawnMode.RANDOM else "固定")
		item.set_text(3, "%d 秒 ± %d 秒" % [int(event.start_time), int(event.random_offset)])
		if group.is_boss_group:
			item.set_text(4, "关底BOSS" if event == final_boss_event else "BOSS")
		else:
			item.set_text(4, "普通")
		var row_color: Color = Color(0.72, 0.43, 1.0) if is_rift else Color(1.0, 0.60, 0.32)
		for column: int in range(timeline.columns):
			item.set_custom_color(column, row_color)
		item.set_metadata(0, event)
		if event == selected_event:
			selected_item = item
	if selected_item != null:
		selected_item.select(0)
		_on_timeline_selected()


func _on_timeline_selected() -> void:
	_write_event_editor()
	_write_group_editor()
	var item: TreeItem = timeline.get_selected()
	if item == null:
		return
	selected_event = item.get_metadata(0) as LevelEventEntry
	if selected_event == null:
		return
	start_time_spin.value = selected_event.start_time
	event_name_edit.text = selected_event.event_name
	random_offset_spin.value = selected_event.random_offset
	random_total_spin.value = selected_event.random_total_count
	repeat_check.button_pressed = selected_event.repeat
	repeat_interval_spin.value = selected_event.repeat_interval
	rift_wave_count_spin.value = selected_event.rift_wave_count
	rift_wave_interval_spin.value = selected_event.rift_wave_interval
	rift_countdown_spin.value = selected_event.rift_countdown
	var group: RaidGroupData = selected_event.get_monster_group()
	if group != null:
		_select_group(group)
	_update_config_visibility()


func _select_group(group: RaidGroupData) -> void:
	for index: int in range(group_option.item_count):
		var option_group: RaidGroupData = group_option.get_item_metadata(index) as RaidGroupData
		if option_group == group:
			group_option.select(index)
			selected_group = group
			_render_group()
			return


func _on_group_option_selected(index: int) -> void:
	_write_event_editor()
	_write_group_editor()
	selected_group = group_option.get_item_metadata(index) as RaidGroupData
	if selected_event != null and selected_group != null:
		selected_event.monster_database = database
		selected_event.monster_group = null
		selected_event.monster_group_id = selected_group.id
	_render_group()
	_refresh_timeline()


func _render_group() -> void:
	var enabled: bool = selected_group != null
	name_edit.editable = enabled
	type_option.disabled = not enabled
	fixed_mode_button.disabled = not enabled
	random_mode_button.disabled = not enabled
	boss_group_check.disabled = not enabled
	if not enabled:
		name_edit.text = ""
		boss_group_check.set_pressed_no_signal(false)
		for child: Node in unit_rows.get_children():
			child.queue_free()
		_update_config_visibility()
		return
	selected_group.ensure_unit_settings()
	name_edit.text = selected_group.display_name
	boss_group_check.set_pressed_no_signal(selected_group.is_boss_group)
	type_option.select(selected_group.group_type)
	fixed_mode_button.set_pressed_no_signal(selected_group.spawn_mode == RaidGroupData.SpawnMode.FIXED)
	random_mode_button.set_pressed_no_signal(selected_group.spawn_mode == RaidGroupData.SpawnMode.RANDOM)
	for child: Node in unit_rows.get_children():
		child.queue_free()
	for index: int in range(selected_group.unit_data.size()):
		var unit: EnemyData = selected_group.unit_data[index]
		if unit == null:
			continue
		var row := HBoxContainer.new()
		unit_rows.add_child(row)
		var unit_label := Label.new()
		unit_label.text = unit.display_name
		if not selected_group.is_unit_compatible(unit):
			unit_label.text = "⚠ %s（阵营或BOSS标记不匹配）" % unit.display_name
		unit_label.tooltip_text = str(unit.id)
		unit_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(unit_label)
		var amount := SpinBox.new()
		amount.min_value = 0.0
		amount.max_value = 100.0
		amount.step = 1.0
		if selected_group.spawn_mode == RaidGroupData.SpawnMode.FIXED:
			amount.value = selected_group.get_fixed_unit_count(index)
			amount.suffix = " 个"
			amount.value_changed.connect(_on_fixed_count_changed.bind(index, selected_group))
		else:
			amount.value = selected_group.get_unit_probability(index)
			amount.suffix = ""
			amount.value_changed.connect(_on_unit_probability_changed.bind(index, selected_group))
		row.add_child(amount)
		var remove_button := Button.new()
		remove_button.text = "移除"
		remove_button.pressed.connect(_remove_unit.bind(index, selected_group))
		row.add_child(remove_button)
	_update_config_visibility()


func _on_group_type_selected(index: int) -> void:
	if selected_group == null:
		return
	_write_group_editor()
	selected_group.group_type = type_option.get_item_id(index)
	_update_config_visibility()
	_refresh_timeline()
	_render_group()


func _on_boss_group_toggled(pressed: bool) -> void:
	if selected_group == null:
		return
	_write_group_editor()
	selected_group.is_boss_group = pressed
	_render_group()
	_refresh_timeline()


func _on_fixed_mode_toggled(pressed: bool) -> void:
	if pressed and selected_group != null:
		_write_group_editor()
		selected_group.spawn_mode = RaidGroupData.SpawnMode.FIXED
		_render_group()
		_refresh_timeline()


func _on_random_mode_toggled(pressed: bool) -> void:
	if pressed and selected_group != null:
		_write_group_editor()
		selected_group.spawn_mode = RaidGroupData.SpawnMode.RANDOM
		_render_group()
		_refresh_timeline()


func _on_fixed_count_changed(value: float, index: int, group: RaidGroupData) -> void:
	group.set_fixed_unit_count(index, int(value))


func _on_unit_probability_changed(value: float, index: int, group: RaidGroupData) -> void:
	group.set_unit_probability(index, value)


func _update_config_visibility() -> void:
	var group: RaidGroupData = selected_group
	var is_random: bool = group != null and group.spawn_mode == RaidGroupData.SpawnMode.RANDOM
	var is_rift: bool = group != null and group.group_type == RaidGroupData.GroupType.RIFT
	for row: Control in config_rows:
		row.visible = selected_event != null
	random_total_spin.get_parent().visible = selected_event != null and is_random
	repeat_check.get_parent().visible = selected_event != null and not is_rift
	repeat_interval_spin.get_parent().visible = selected_event != null and not is_rift and repeat_check.button_pressed
	for index: int in range(type_specific_rows.size()):
		var is_wave_setting: bool = index < 2
		type_specific_rows[index].visible = (
			selected_event != null
			and is_rift
			and (not is_wave_setting or not group.is_boss_group)
		)


func _add_group_pressed() -> void:
	if database == null:
		return
	var group := RaidGroupData.new()
	group.id = _make_unique_group_id()
	group.display_name = "新怪物组"
	group.group_type = RaidGroupData.GroupType.RAID
	group.spawn_mode = RaidGroupData.SpawnMode.FIXED
	group.unit_data.append(null)
	group.ensure_unit_settings()
	database.groups.append(group)
	_refresh_group_options()
	_select_group(group)


func _delete_group_pressed() -> void:
	if database == null or selected_group == null:
		return
	var dependent_events: Array[String] = []
	for event: LevelEventEntry in level_flow.events:
		var group: RaidGroupData = event.get_monster_group() if event != null else null
		if group != null and group.id == selected_group.id:
			var event_name: String = event.event_name.strip_edges()
			dependent_events.append(event_name if not event_name.is_empty() else "未命名事件")
	pending_delete_group = selected_group
	if dependent_events.is_empty():
		_on_delete_group_confirmed()
		return
	delete_group_dialog.dialog_text = "怪物组「%s」正在以下事件中使用：\n%s\n\n确认后将同时删除该怪物组及以上事件。" % [
		selected_group.display_name,
		"、".join(dependent_events)
	]
	delete_group_dialog.popup_centered(Vector2i(480, 240))


func _on_delete_group_confirmed() -> void:
	if database == null or not is_instance_valid(pending_delete_group):
		return
	var group_id: StringName = pending_delete_group.id
	for index: int in range(level_flow.events.size() - 1, -1, -1):
		var event: LevelEventEntry = level_flow.events[index]
		var event_group: RaidGroupData = event.get_monster_group() if event != null else null
		if event_group != null and event_group.id == group_id:
			level_flow.events.remove_at(index)
	if selected_event != null:
		var selected_event_group: RaidGroupData = selected_event.get_monster_group()
		if selected_event_group != null and selected_event_group.id == group_id:
			selected_event = null
	database.groups.erase(pending_delete_group)
	selected_group = null
	pending_delete_group = null
	_refresh_group_options()
	_refresh_timeline()
	_update_config_visibility()


func _make_unique_group_id() -> StringName:
	var index: int = 1
	while database.get_group(StringName("monster_group_%02d" % index)) != null:
		index += 1
	return StringName("monster_group_%02d" % index)


func _add_unit_pressed() -> void:
	if selected_group == null:
		return
	_write_group_editor()
	var popup := PopupMenu.new()
	popup.name = "UnitSelectionPopup"
	for unit: EnemyData in _get_available_units_for_group(selected_group):
		var menu_id: int = popup.item_count
		popup.add_item("%s  [%s]" % [unit.display_name, unit.id], menu_id)
		popup.set_item_metadata(menu_id, unit)
	if popup.item_count == 0:
		var empty_message: String = "该阵营暂无可选BOSS单位" if selected_group.is_boss_group else "该阵营暂无可添加单位"
		popup.add_item(empty_message)
		popup.set_item_disabled(0, true)
	popup.id_pressed.connect(_on_unit_chosen.bind(popup, selected_group))
	add_child(popup)
	popup.position = Vector2i(add_unit_button.get_screen_position() + Vector2(0.0, add_unit_button.size.y))
	popup.popup()


func _get_available_units_for_group(group: RaidGroupData) -> Array[EnemyData]:
	var result: Array[EnemyData] = []
	if group == null:
		return result
	var folder: String = RIFT_UNIT_FOLDER if group.group_type == RaidGroupData.GroupType.RIFT else RAID_UNIT_FOLDER
	var faction: int = EnemyData.Faction.RIFT if group.group_type == RaidGroupData.GroupType.RIFT else EnemyData.Faction.RAID
	var files: PackedStringArray = DirAccess.get_files_at(folder)
	files.sort()
	for file_name: String in files:
		if not file_name.ends_with(".tres"):
			continue
		var unit: EnemyData = ResourceLoader.load(folder + file_name, "", ResourceLoader.CACHE_MODE_REUSE) as EnemyData
		if unit == null or _group_has_unit(group, unit):
			continue
		if int(unit.faction) != faction or unit.is_boss != group.is_boss_group:
			continue
		result.append(unit)
	return result


func _group_has_unit(group: RaidGroupData, candidate: EnemyData) -> bool:
	for unit: EnemyData in group.unit_data:
		if unit == candidate:
			return true
		if unit != null and not unit.resource_path.is_empty() and unit.resource_path == candidate.resource_path:
			return true
	return false


func _on_unit_chosen(menu_id: int, popup: PopupMenu, group: RaidGroupData) -> void:
	var item_index: int = popup.get_item_index(menu_id)
	var unit: EnemyData = popup.get_item_metadata(item_index) as EnemyData if item_index >= 0 else null
	if is_instance_valid(group) and is_instance_valid(unit) and not _group_has_unit(group, unit):
		group.unit_data.append(unit)
		group.ensure_unit_settings()
		selected_group = group
		call_deferred("_render_group")
		print("怪物组添加单位：", unit.display_name, " -> ", group.display_name)
	popup.queue_free()


func _remove_unit(index: int, group: RaidGroupData) -> void:
	if index < 0 or index >= group.unit_data.size():
		return
	group.unit_data.remove_at(index)
	group.ensure_unit_settings()
	_render_group()


func _add_event_pressed() -> void:
	if level_flow == null or selected_group == null or selected_group.id.is_empty():
		return
	_write_event_editor()
	var event := LevelEventEntry.new()
	event.monster_database = database
	event.monster_group_id = selected_group.id
	event.event_name = "新出场事件 %02d" % (level_flow.events.size() + 1)
	event.start_time = 120.0
	event.random_offset = 0.0
	event.random_total_count = 3
	level_flow.events.append(event)
	selected_event = null
	_refresh_timeline()
	var item: TreeItem = timeline.get_root().get_first_child()
	while item != null:
		if item.get_metadata(0) == event:
			item.select(0)
			_on_timeline_selected()
			break
		item = item.get_next()


func _delete_event_pressed() -> void:
	if level_flow == null or selected_event == null:
		return
	level_flow.events.erase(selected_event)
	selected_event = null
	_refresh_timeline()
	_update_config_visibility()


func _write_event_editor() -> void:
	if selected_event == null:
		return
	selected_event.event_name = event_name_edit.text.strip_edges()
	selected_event.start_time = start_time_spin.value
	selected_event.random_offset = random_offset_spin.value
	selected_event.random_total_count = int(random_total_spin.value)
	selected_event.repeat = repeat_check.button_pressed
	selected_event.repeat_interval = repeat_interval_spin.value
	selected_event.rift_wave_count = int(rift_wave_count_spin.value)
	selected_event.rift_wave_interval = rift_wave_interval_spin.value
	selected_event.rift_countdown = rift_countdown_spin.value


func _save_all() -> bool:
	if database == null or level_flow == null:
		return false
	for entry: MapResourceEntry in level_flow.map_resources:
		if entry != null and entry.enabled and not entry.validation_error().is_empty():
			push_error("无法保存关卡：" + entry.display_name + "：" + entry.validation_error())
			return false
	_write_group_editor()
	_write_event_editor()
	level_flow.monster_database = database
	for event: LevelEventEntry in level_flow.events:
		if event != null:
			event.monster_database = database
	var database_error: Error = ResourceSaver.save(database, database.resource_path)
	if database_error != OK:
		push_error("怪物组保存失败：%s" % database_error)
		return false
	var flow_error: Error = ResourceSaver.save(level_flow, preset_path)
	if flow_error != OK:
		push_error("关卡时间线保存失败：%s" % flow_error)
		return false
	_refresh_group_options()
	_refresh_timeline()
	get_tree().call_group("raid_editor_refresh", "refresh")
	preset_path_label.text = preset_path
	print("关卡预设已保存（地图、资源分布、出怪事件）：", preset_path)
	return true


func _write_group_editor() -> void:
	if selected_group == null or name_edit == null:
		return
	selected_group.display_name = name_edit.text.strip_edges()
	selected_group.ensure_unit_settings()
