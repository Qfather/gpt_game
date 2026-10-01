extends PanelContainer

const RESOURCE_DATABASE: ResourceDatabase = preload("res://data/resources/resource_database.tres")

signal closed

var camp: TreasureCamp
var title: Label
var details: Label
var unit_option: OptionButton
var add_button: Button
var participants_box: VBoxContainer
var refresh_timer: float = 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	offset_left = -410.0
	offset_right = -20.0
	offset_top = 80.0
	offset_bottom = 560.0
	custom_minimum_size = Vector2(390.0, 480.0)
	var margin := MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 14)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	margin.add_child(column)
	var heading := HBoxContainer.new()
	column.add_child(heading)
	title = Label.new()
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 20)
	heading.add_child(title)
	var close := Button.new()
	close.text = "关闭"
	close.pressed.connect(func() -> void:
		hide()
		closed.emit()
	)
	heading.add_child(close)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(350.0, 220.0)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	details = Label.new()
	details.custom_minimum_size.x = 340.0
	details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	scroll.add_child(details)
	var unit_title := Label.new()
	unit_title.text = "分配战斗单位寻宝"
	column.add_child(unit_title)
	var assignment := HBoxContainer.new()
	column.add_child(assignment)
	unit_option = OptionButton.new()
	unit_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	assignment.add_child(unit_option)
	add_button = Button.new()
	add_button.text = "添加"
	add_button.pressed.connect(_add_unit)
	assignment.add_child(add_button)
	var participant_scroll := ScrollContainer.new()
	participant_scroll.custom_minimum_size.y = 90.0
	column.add_child(participant_scroll)
	participants_box = VBoxContainer.new()
	participants_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	participant_scroll.add_child(participants_box)
	hide()


func open_camp(value: TreasureCamp) -> void:
	camp = value
	refresh()
	show()


func _process(delta: float) -> void:
	if not visible:
		return
	if not is_instance_valid(camp) or camp.is_queued_for_deletion():
		hide()
		closed.emit()
		return
	refresh_timer += delta
	if refresh_timer >= 0.5 and not unit_option.get_popup().visible:
		refresh_timer = 0.0
		refresh()


func refresh() -> void:
	if not is_instance_valid(camp):
		return
	title.text = camp.display_name
	var lines: PackedStringArray = ["状态：" + camp.get_status_text(), "", "宝箱物资（营地剩余）："]
	for id: StringName in camp.resources:
		var resource: ResourceData = RESOURCE_DATABASE.get_resource_data(id)
		lines.append("%s × %.0f" % [resource.display_name if resource != null else str(id), camp.resources[id]])
	lines.append("\n守卫：")
	var living: Array[EnemyBase] = camp.get_living_guards()
	for guard: EnemyBase in living:
		lines.append("%s  生命 %.0f/%.0f  攻击 %.0f" % [guard.get_display_name(), guard.current_health, guard.max_health, guard.damage])
	if living.is_empty():
		lines.append("已全部清除，居民自动领取搬运任务")
	details.text = "\n".join(lines)
	var previous: Node = unit_option.get_item_metadata(unit_option.selected) as Node if unit_option.selected >= 0 else null
	unit_option.clear()
	for unit: Node in get_tree().get_nodes_in_group("combat_units"):
		if unit.has_method("can_accept_treasure_hunt") and unit.can_accept_treasure_hunt():
			unit_option.add_item(_unit_name(unit))
			unit_option.set_item_metadata(unit_option.item_count - 1, unit)
			if unit == previous:
				unit_option.select(unit_option.item_count - 1)
	if unit_option.item_count == 0:
		unit_option.add_item("暂无可分配的战斗单位")
		unit_option.set_item_metadata(0, null)
	add_button.disabled = camp.cleared or unit_option.get_item_metadata(unit_option.selected) == null
	for child: Node in participants_box.get_children():
		participants_box.remove_child(child)
		child.queue_free()
	for unit: Node in camp.participants:
		if not is_instance_valid(unit):
			continue
		var row := HBoxContainer.new()
		participants_box.add_child(row)
		var label := Label.new()
		label.text = _unit_name(unit)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		var remove := Button.new()
		remove.text = "撤回"
		remove.pressed.connect(_remove_unit.bind(unit))
		row.add_child(remove)


func _unit_name(unit: Node) -> String:
	if unit.has_method("get_display_name"):
		return str(unit.get_display_name())
	var role: String = CombatRole.get_display_name(unit.get_combat_role()) if unit.has_method("get_combat_role") else "未知"
	if role == "未知":
		role = "战斗单位"
	return "角色 %d · %s" % [get_tree().get_nodes_in_group("combat_units").find(unit) + 1, role]


func _add_unit() -> void:
	var unit: Node = unit_option.get_item_metadata(unit_option.selected) as Node
	var selected_camp: TreasureCamp = camp
	get_tree().current_scene.execute_game_command(func() -> void:
		if is_instance_valid(selected_camp) and is_instance_valid(unit):
			selected_camp.add_participant(unit)
			refresh()
	)


func _remove_unit(unit: Node) -> void:
	var selected_camp: TreasureCamp = camp
	get_tree().current_scene.execute_game_command(func() -> void:
		if is_instance_valid(selected_camp):
			selected_camp.remove_participant(unit)
			refresh()
	)
