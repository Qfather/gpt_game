@tool
extends EditorPlugin


# ============================================================
# Trait 数据目录
# ============================================================

const TRAIT_FOLDER = "res://data/traits/"


# ============================================================
# 主 UI
# ============================================================

var main_panel: Control
var trait_list: ItemList

var new_button: Button
var delete_button: Button
var refresh_button: Button

# 当前读取到的 TraitData
var trait_resources: Array = []

# 当前正在编辑的 TraitData
var current_trait_data: TraitData = null

# ============================================================
# 左侧筛选
# -1 = 全部
# ============================================================

var selected_rarity_filter: int = -1
var selected_category_filter: int = -1

var rarity_filter_group: ButtonGroup
var category_filter_group: ButtonGroup


# ============================================================
# 中文编辑区
# ============================================================

var editor_panel: VBoxContainer
var editor_scroll: ScrollContainer

var id_edit: LineEdit
var name_edit: LineEdit
var description_edit: TextEdit

var new_trait_dialog: Window
var new_trait_id_edit: LineEdit
var new_trait_name_edit: LineEdit
var new_trait_error_label: Label

var icon_preview: Button
var icon_dialog: EditorFileDialog

var type_option: OptionButton
var rarity_option: OptionButton
var category_option: OptionButton

var weight_spin: SpinBox

var save_button: Button

# ============================================================
# 等级效果编辑区
# ============================================================

var levels_container: VBoxContainer
var add_level_button: Button
var level_editor_rows: Array = []


# ============================================================
# 插件启动
# ============================================================

func _enter_tree():

	print("🏷️ Trait Editor 插件启动")

	_ensure_trait_folder()

	_create_main_panel()

	_create_icon_dialog()

	_refresh_trait_list()


# ============================================================
# 插件关闭
# ============================================================

func _exit_tree():

	print("🏷️ Trait Editor 插件关闭")

	if icon_dialog != null:
		icon_dialog.queue_free()
		icon_dialog = null

	if new_trait_dialog != null:
		new_trait_dialog.queue_free()
		new_trait_dialog = null

	if main_panel != null:

		remove_control_from_bottom_panel(main_panel)

		main_panel.queue_free()
		main_panel = null


# ============================================================
# 创建数据目录
# ============================================================

func _ensure_trait_folder():

	var absolute_path = ProjectSettings.globalize_path(
		TRAIT_FOLDER
	)

	var error = DirAccess.make_dir_recursive_absolute(
		absolute_path
	)

	if error != OK and error != ERR_ALREADY_EXISTS:

		push_error(
			"无法创建 Trait 数据目录，错误代码："
			+ str(error)
		)


# ============================================================
# 创建主面板
# ============================================================

func _create_main_panel():

	main_panel = VBoxContainer.new()

	main_panel.name = "TraitEditor"

	main_panel.custom_minimum_size = Vector2(
		0,
		420
	)


	# ========================================================
	# 顶部工具栏
	# ========================================================

	var toolbar = HBoxContainer.new()

	main_panel.add_child(toolbar)


	var title = Label.new()

	title.text = "Trait 标签数据库"

	title.add_theme_font_size_override(
		"font_size",
		20
	)

	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	toolbar.add_child(title)


	# --------------------------------------------------------
	# 保存修改
	# 固定在顶部工具栏，放在“刷新”左边
	# --------------------------------------------------------

	save_button = Button.new()
	save_button.text = "保存修改"
	save_button.disabled = true
	save_button.pressed.connect(
		_on_save_pressed
	)
	toolbar.add_child(save_button)


	# --------------------------------------------------------
	# 刷新
	# --------------------------------------------------------

	refresh_button = Button.new()

	refresh_button.text = "刷新"

	refresh_button.pressed.connect(
		_refresh_trait_list
	)

	toolbar.add_child(refresh_button)


	# --------------------------------------------------------
	# 新建
	# --------------------------------------------------------

	new_button = Button.new()

	new_button.text = "+ 新建标签"

	new_button.pressed.connect(
		_on_new_trait_pressed
	)

	toolbar.add_child(new_button)


	# --------------------------------------------------------
	# 删除
	# --------------------------------------------------------

	delete_button = Button.new()

	delete_button.text = "删除标签"

	delete_button.disabled = true

	delete_button.pressed.connect(
		_on_delete_trait_pressed
	)

	toolbar.add_child(delete_button)


	# ========================================================
	# 主体
	# ========================================================

	var body = HSplitContainer.new()

	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	main_panel.add_child(body)


	# ========================================================
	# 左侧
	# ========================================================

	var left_panel = VBoxContainer.new()

	left_panel.custom_minimum_size.x = 260

	body.add_child(left_panel)


	# ========================================================
	# 左侧筛选：第一行品级，第二行职业
	# ========================================================

	_create_filter_panel(left_panel)


	trait_list = ItemList.new()

	trait_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	trait_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	trait_list.item_selected.connect(
		_on_trait_selected
	)

	left_panel.add_child(trait_list)


	# ========================================================
	# 右侧编辑区域
	# ========================================================

	editor_scroll = ScrollContainer.new()

	editor_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	editor_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL

	body.add_child(editor_scroll)


	editor_panel = VBoxContainer.new()

	editor_panel.custom_minimum_size.x = 520

	editor_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	editor_scroll.add_child(editor_panel)


	_create_basic_editor()


	# ========================================================
	# 添加到底部
	# ========================================================

	add_control_to_bottom_panel(
		main_panel,
		"Trait Editor"
	)


# ============================================================
# 创建左侧筛选区域
# ============================================================

func _create_filter_panel(parent: VBoxContainer):

	rarity_filter_group = ButtonGroup.new()
	category_filter_group = ButtonGroup.new()

	# 第一行：品级
	var rarity_row = HBoxContainer.new()
	parent.add_child(rarity_row)

	_add_filter_button(
		rarity_row,
		"全部",
		-1,
		rarity_filter_group,
		true,
		_on_rarity_filter_pressed
	)

	_add_filter_button(rarity_row, "普通", TraitData.TraitRarity.COMMON, rarity_filter_group, false, _on_rarity_filter_pressed)
	_add_filter_button(rarity_row, "优良", TraitData.TraitRarity.UNCOMMON, rarity_filter_group, false, _on_rarity_filter_pressed)
	_add_filter_button(rarity_row, "稀有", TraitData.TraitRarity.RARE, rarity_filter_group, false, _on_rarity_filter_pressed)
	_add_filter_button(rarity_row, "史诗", TraitData.TraitRarity.EPIC, rarity_filter_group, false, _on_rarity_filter_pressed)
	_add_filter_button(rarity_row, "传奇", TraitData.TraitRarity.LEGENDARY, rarity_filter_group, false, _on_rarity_filter_pressed)

	# 第二行：职业
	var category_row = HBoxContainer.new()
	parent.add_child(category_row)

	_add_filter_button(
		category_row,
		"全部",
		-1,
		category_filter_group,
		true,
		_on_category_filter_pressed
	)

	_add_filter_button(category_row, "通用", TraitData.TraitCategory.GENERAL, category_filter_group, false, _on_category_filter_pressed)
	_add_filter_button(category_row, "剑士", TraitData.TraitCategory.SWORDSMAN, category_filter_group, false, _on_category_filter_pressed)
	_add_filter_button(category_row, "弓手", TraitData.TraitCategory.ARCHER, category_filter_group, false, _on_category_filter_pressed)


func _add_filter_button(
	parent: HBoxContainer,
	text_value: String,
	filter_value: int,
	group: ButtonGroup,
	pressed_by_default: bool,
	callback: Callable
):

	var button = Button.new()
	button.text = text_value
	button.toggle_mode = true
	button.button_group = group
	button.button_pressed = pressed_by_default
	button.set_meta("filter_value", filter_value)
	button.pressed.connect(callback.bind(button))
	parent.add_child(button)


func _on_rarity_filter_pressed(button: Button):

	selected_rarity_filter = int(button.get_meta("filter_value"))
	_apply_filters()


func _on_category_filter_pressed(button: Button):

	selected_category_filter = int(button.get_meta("filter_value"))
	_apply_filters()


func _trait_matches_filters(trait_data: TraitData) -> bool:

	if selected_rarity_filter != -1:
		if int(trait_data.rarity) != selected_rarity_filter:
			return false

	if selected_category_filter != -1:
		if int(trait_data.category) != selected_category_filter:
			return false

	return true


func _apply_filters():

	if trait_list == null:
		return

	trait_list.clear()

	for trait_data in trait_resources:

		if not _trait_matches_filters(trait_data):
			continue

		var index = trait_list.add_item(
			str(trait_data.trait_name)
		)

		# 保存真实 TraitData，避免筛选后 ItemList 索引与 trait_resources 错位
		trait_list.set_item_metadata(
			index,
			trait_data
		)

		if trait_data.icon != null:
			trait_list.set_item_icon(
				index,
				trait_data.icon
			)


# ============================================================
# 创建基础资料编辑器
# ============================================================

func _create_basic_editor():

	var header = HBoxContainer.new()
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	editor_panel.add_child(header)

	var title = Label.new()

	title.text = "标签基本资料"

	title.add_theme_font_size_override(
		"font_size",
		18
	)

	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	editor_panel.add_child(
		HSeparator.new()
	)


	# ========================================================
	# 图标 + 名称 + 描述
	# ========================================================

	var basic_info_row = HBoxContainer.new()

	basic_info_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	editor_panel.add_child(basic_info_row)


	icon_preview = Button.new()

	icon_preview.custom_minimum_size = Vector2(
		96,
		96
	)

	# 保留普通 Button 的主题边框，使 ICON 边缘更清晰。
	icon_preview.flat = false
	icon_preview.expand_icon = true
	icon_preview.alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_preview.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	icon_preview.tooltip_text = "点击选择标签图标"
	icon_preview.text = "?"
	icon_preview.pressed.connect(_on_icon_select_pressed)

	basic_info_row.add_child(icon_preview)


	var info_column = VBoxContainer.new()

	info_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_column.size_flags_vertical = Control.SIZE_EXPAND_FILL

	basic_info_row.add_child(info_column)


	# 永久 ID：创建后只读。
	id_edit = LineEdit.new()
	id_edit.placeholder_text = "标签 ID"
	id_edit.editable = false
	id_edit.tooltip_text = "永久 ID，由新建标签时确定，创建后不可修改"
	id_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_column.add_child(id_edit)


	name_edit = LineEdit.new()
	name_edit.placeholder_text = "标签名称，例如：飞毛腿"
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_column.add_child(name_edit)


	description_edit = TextEdit.new()
	description_edit.custom_minimum_size.y = 50
	description_edit.placeholder_text = "标签描述，例如：移动速度提高 10%"
	description_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	description_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	info_column.add_child(description_edit)


	# ========================================================
	# 标签性质
	# ========================================================

	var type_row = HBoxContainer.new()

	editor_panel.add_child(type_row)


	var type_label = Label.new()

	type_label.text = "标签性质"

	type_label.custom_minimum_size.x = 120

	type_row.add_child(type_label)


	type_option = OptionButton.new()

	type_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	type_option.add_item(
		"正面",
		TraitData.TraitType.POSITIVE
	)

	type_option.add_item(
		"负面",
		TraitData.TraitType.NEGATIVE
	)

	type_option.add_item(
		"混合",
		TraitData.TraitType.MIXED
	)

	type_row.add_child(type_option)


	# ========================================================
	# 标签品级
	# ========================================================

	var rarity_row = HBoxContainer.new()

	editor_panel.add_child(rarity_row)


	var rarity_label = Label.new()

	rarity_label.text = "标签品级"

	rarity_label.custom_minimum_size.x = 120

	rarity_row.add_child(rarity_label)


	rarity_option = OptionButton.new()

	rarity_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL


	rarity_option.add_item(
		"普通",
		TraitData.TraitRarity.COMMON
	)

	rarity_option.add_item(
		"优良",
		TraitData.TraitRarity.UNCOMMON
	)

	rarity_option.add_item(
		"稀有",
		TraitData.TraitRarity.RARE
	)

	rarity_option.add_item(
		"史诗",
		TraitData.TraitRarity.EPIC
	)

	rarity_option.add_item(
		"传奇",
		TraitData.TraitRarity.LEGENDARY
	)


	rarity_row.add_child(rarity_option)


	# ========================================================
	# 标签分类
	# ========================================================

	var category_row = HBoxContainer.new()

	editor_panel.add_child(category_row)


	var category_label = Label.new()

	category_label.text = "标签分类"

	category_label.custom_minimum_size.x = 120

	category_row.add_child(category_label)


	category_option = OptionButton.new()

	category_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL


	category_option.add_item(
		"通用",
		TraitData.TraitCategory.GENERAL
	)

	category_option.add_item(
		"剑士",
		TraitData.TraitCategory.SWORDSMAN
	)

	category_option.add_item(
		"弓手",
		TraitData.TraitCategory.ARCHER
	)


	category_row.add_child(category_option)


	# ========================================================
	# 抽取权重
	# ========================================================

	var weight_row = HBoxContainer.new()

	editor_panel.add_child(weight_row)


	var weight_label = Label.new()

	weight_label.text = "抽取权重"

	weight_label.custom_minimum_size.x = 120

	weight_row.add_child(weight_label)


	weight_spin = SpinBox.new()

	weight_spin.min_value = 0.0
	weight_spin.max_value = 1000.0
	weight_spin.step = 0.1

	weight_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	weight_row.add_child(weight_spin)


	var weight_help = Label.new()

	weight_help.text = "数值越高，被随机抽中的机会越大。"

	editor_panel.add_child(weight_help)


	# ========================================================
	# 等级效果
	# ========================================================

	editor_panel.add_child(HSeparator.new())

	var levels_header = HBoxContainer.new()
	levels_header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	editor_panel.add_child(levels_header)

	var levels_title = Label.new()
	levels_title.text = "等级效果"
	levels_title.add_theme_font_size_override("font_size", 18)
	levels_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	levels_header.add_child(levels_title)

	add_level_button = Button.new()
	add_level_button.text = "+ 添加等级"
	add_level_button.disabled = true
	add_level_button.pressed.connect(_on_add_level_pressed)
	levels_header.add_child(add_level_button)

	levels_container = VBoxContainer.new()
	levels_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	editor_panel.add_child(levels_container)




# ============================================================
# 等级效果编辑器
# ============================================================

func _clear_levels_editor():

	if levels_container == null:
		return

	for child in levels_container.get_children():
		child.queue_free()

	level_editor_rows.clear()


func _load_levels_editor():

	_clear_levels_editor()

	if current_trait_data == null:
		if add_level_button != null:
			add_level_button.disabled = true
		return

	add_level_button.disabled = false

	var sorted_levels: Array = []
	for level_data in current_trait_data.levels:
		if level_data != null:
			sorted_levels.append(level_data)

	sorted_levels.sort_custom(
		func(a, b):
			return int(a.level) < int(b.level)
	)

	for level_data in sorted_levels:
		_create_level_editor(level_data)


func _create_level_editor(level_data: TraitLevelData):

	var panel = PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	levels_container.add_child(panel)

	var column = VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_child(column)

	var header = HBoxContainer.new()
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(header)

	var level_label = Label.new()
	level_label.text = "Lv."
	header.add_child(level_label)

	var level_spin = SpinBox.new()
	level_spin.min_value = 1
	level_spin.max_value = 10
	level_spin.step = 1
	level_spin.value = level_data.level
	level_spin.custom_minimum_size.x = 80
	header.add_child(level_spin)

	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)

	var add_modifier_button = Button.new()
	add_modifier_button.text = "+ 添加属性效果"
	header.add_child(add_modifier_button)

	var delete_level_button = Button.new()
	delete_level_button.text = "删除等级"
	header.add_child(delete_level_button)

	var modifiers_container = VBoxContainer.new()
	modifiers_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(modifiers_container)

	var level_row = {
		"panel": panel,
		"level_data": level_data,
		"level_spin": level_spin,
		"modifiers_container": modifiers_container,
		"modifier_rows": []
	}
	level_editor_rows.append(level_row)

	add_modifier_button.pressed.connect(
		_on_add_modifier_pressed.bind(level_row)
	)
	delete_level_button.pressed.connect(
		_on_delete_level_pressed.bind(level_row)
	)

	for modifier in level_data.modifiers:
		if modifier != null:
			_create_modifier_editor(level_row, modifier)


func _create_modifier_editor(level_row: Dictionary, modifier: StatModifier):

	var row = HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	level_row["modifiers_container"].add_child(row)

	var stat_option = OptionButton.new()
	stat_option.custom_minimum_size.x = 150
	stat_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	stat_option.add_item("最大生命", StatModifier.StatType.MAX_HEALTH)
	stat_option.add_item("生命恢复速度", StatModifier.StatType.HEALTH_REGEN)
	stat_option.add_item("移动速度", StatModifier.StatType.MOVE_SPEED)
	stat_option.add_item("食物消耗", StatModifier.StatType.FOOD_CONSUMPTION)
	stat_option.add_item("工作效率", StatModifier.StatType.WORK_SPEED)
	stat_option.add_item("采集速度", StatModifier.StatType.GATHER_SPEED)
	stat_option.add_item("攻击力", StatModifier.StatType.ATTACK_DAMAGE)
	stat_option.add_item("攻击速度", StatModifier.StatType.ATTACK_SPEED)

	_select_option_by_id(stat_option, modifier.stat)
	row.add_child(stat_option)

	var modifier_option = OptionButton.new()
	modifier_option.custom_minimum_size.x = 110
	modifier_option.add_item("固定值", StatModifier.ModifierType.ADD)
	modifier_option.add_item("百分比", StatModifier.ModifierType.PERCENT)
	_select_option_by_id(modifier_option, modifier.modifier_type)
	row.add_child(modifier_option)

	var value_spin = SpinBox.new()
	value_spin.min_value = -10000.0
	value_spin.max_value = 10000.0
	value_spin.step = 0.1
	value_spin.value = modifier.value
	value_spin.custom_minimum_size.x = 120
	row.add_child(value_spin)

	var delete_button = Button.new()
	delete_button.text = "删除"
	row.add_child(delete_button)

	var modifier_row = {
		"row": row,
		"stat_option": stat_option,
		"modifier_option": modifier_option,
		"value_spin": value_spin
	}
	level_row["modifier_rows"].append(modifier_row)

	delete_button.pressed.connect(
		_on_delete_modifier_pressed.bind(level_row, modifier_row)
	)


func _on_add_level_pressed():

	print("➕ 点击添加等级")

	if current_trait_data == null:
		push_warning("请先选择一个标签")
		return

	var used_levels: Array[int] = []

	for level_row in level_editor_rows:
		used_levels.append(int(level_row["level_spin"].value))

	var new_level_number = 1

	while new_level_number in used_levels:
		new_level_number += 1

	if new_level_number > 10:
		push_warning("最多支持 10 个等级")
		return

	# TraitLevelData 自己已经有：
	# @export var modifiers: Array[StatModifier] = []
	# 这里不要再用普通 [] 给强类型数组赋值。
	var level_data := TraitLevelData.new()
	level_data.level = new_level_number

	# 这里只创建界面。
	# 真正的数据统一在“保存修改”时由 _write_levels_from_editor() 写回，
	# 避免编辑器 UI 和 Resource 同时修改导致状态不同步。
	_create_level_editor(level_data)

	print("✅ 已添加等级：Lv.", new_level_number)

	call_deferred("_ensure_last_level_visible")


func _on_delete_level_pressed(level_row: Dictionary):

	var panel = level_row["panel"]
	var level_data = level_row["level_data"]

	level_editor_rows.erase(level_row)
	if current_trait_data != null:
		current_trait_data.levels.erase(level_data)

	if is_instance_valid(panel):
		panel.queue_free()


func _scroll_to_levels_bottom():

	if editor_scroll == null:
		return

	editor_scroll.scroll_vertical = int(
		editor_scroll.get_v_scroll_bar().max_value
	)


func _ensure_last_level_visible():

	if editor_scroll == null or levels_container == null:
		return

	var children = levels_container.get_children()
	if children.is_empty():
		return

	editor_scroll.ensure_control_visible(children.back())
	_scroll_to_levels_bottom()


func _on_add_modifier_pressed(level_row: Dictionary):

	var modifier = StatModifier.new()
	modifier.stat = StatModifier.StatType.MOVE_SPEED
	modifier.modifier_type = StatModifier.ModifierType.PERCENT
	modifier.value = 0.0

	_create_modifier_editor(level_row, modifier)


func _on_delete_modifier_pressed(
	level_row: Dictionary,
	modifier_row: Dictionary
):

	level_row["modifier_rows"].erase(modifier_row)

	var row = modifier_row["row"]

	if is_instance_valid(row):
		row.queue_free()


func _write_levels_from_editor() -> bool:

	if current_trait_data == null:
		return false

	var new_levels: Array[TraitLevelData] = []
	var used_levels: Dictionary = {}

	for level_row in level_editor_rows:

		var level_number = int(level_row["level_spin"].value)

		if used_levels.has(level_number):
			push_warning("等级 Lv.%d 重复，请修改后再保存" % level_number)
			return false

		used_levels[level_number] = true

		var level_data = TraitLevelData.new()
		level_data.level = level_number

		var modifiers: Array[StatModifier] = []

		for modifier_row in level_row["modifier_rows"]:

			var modifier = StatModifier.new()

			modifier.stat = (
				modifier_row["stat_option"].get_selected_id()
			)

			modifier.modifier_type = (
				modifier_row["modifier_option"].get_selected_id()
			)

			modifier.value = (
				modifier_row["value_spin"].value
			)

			modifiers.append(modifier)

		level_data.modifiers = modifiers
		new_levels.append(level_data)

	new_levels.sort_custom(
		func(a, b):
			return int(a.level) < int(b.level)
	)

	current_trait_data.levels = new_levels
	return true


# ============================================================
# ICON 文件选择窗口
# ============================================================

func _create_icon_dialog():

	icon_dialog = EditorFileDialog.new()

	icon_dialog.title = "选择 Trait 图标"

	icon_dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE

	icon_dialog.access = EditorFileDialog.ACCESS_RESOURCES


	icon_dialog.add_filter(
		"*.png ; PNG 图片"
	)

	icon_dialog.add_filter(
		"*.webp ; WebP 图片"
	)

	icon_dialog.add_filter(
		"*.jpg, *.jpeg ; JPEG 图片"
	)


	icon_dialog.file_selected.connect(
		_on_icon_file_selected
	)


	get_editor_interface().get_base_control().add_child(
		icon_dialog
	)


# ============================================================
# 刷新 Trait
# ============================================================

func _refresh_trait_list():

	if trait_list == null:
		return


	trait_list.clear()

	trait_resources.clear()


	var dir = DirAccess.open(
		TRAIT_FOLDER
	)


	if dir == null:
		return


	dir.list_dir_begin()


	while true:

		var file_name = dir.get_next()


		if file_name == "":
			break


		if dir.current_is_dir():
			continue


		if file_name.get_extension().to_lower() != "tres":
			continue


		var file_path = (
			TRAIT_FOLDER
			+ file_name
		)


		var resource_data = ResourceLoader.load(
			file_path
		)


		if resource_data == null:
			continue


		if not resource_data is TraitData:
			continue


		trait_resources.append(
			resource_data
		)


	dir.list_dir_end()


	trait_resources.sort_custom(
		_sort_trait_by_name
	)


	_apply_filters()

	print(
		"🏷️ Trait 数据数量：",
		trait_resources.size()
	)


# ============================================================
# 排序
# ============================================================

func _sort_trait_by_name(a, b):

	return str(a.trait_name) < str(b.trait_name)


# ============================================================
# 新建 Trait
# ============================================================

func _on_new_trait_pressed():

	print("➕ 点击新建标签")

	# 懒加载：即使插件启动阶段没有成功创建弹窗，
	# 点击按钮时也会重新创建，避免“按钮有反应但没有窗口”。
	if new_trait_dialog == null or not is_instance_valid(new_trait_dialog):
		_create_new_trait_dialog()

	new_trait_id_edit.text = ""
	new_trait_name_edit.text = ""
	new_trait_error_label.text = ""

	new_trait_dialog.popup_centered(Vector2i(460, 300))
	new_trait_id_edit.grab_focus()


# ============================================================
# 新建 Trait 弹窗
# ============================================================

func _create_new_trait_dialog():

	if new_trait_dialog != null and is_instance_valid(new_trait_dialog):
		return

	# 不再使用 ConfirmationDialog 的内部布局。
	# 直接使用 Window + 自己的 VBox/HBox，避免编辑器版本差异。
	new_trait_dialog = Window.new()
	new_trait_dialog.title = "新建标签"
	new_trait_dialog.size = Vector2i(460, 300)
	new_trait_dialog.min_size = Vector2i(460, 300)
	new_trait_dialog.transient = true
	new_trait_dialog.exclusive = true
	new_trait_dialog.unresizable = true

	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	new_trait_dialog.add_child(margin)

	var content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(content)

	var id_label = Label.new()
	id_label.text = "标签 ID"
	content.add_child(id_label)

	new_trait_id_edit = LineEdit.new()
	new_trait_id_edit.placeholder_text = "例如：swift_feet"
	new_trait_id_edit.tooltip_text = "仅允许英文小写字母、数字和下划线"
	content.add_child(new_trait_id_edit)

	var id_help = Label.new()
	id_help.text = "仅允许 a-z、0-9、_；创建后 ID 与文件名保持不变。"
	content.add_child(id_help)

	var name_label = Label.new()
	name_label.text = "标签名称"
	content.add_child(name_label)

	new_trait_name_edit = LineEdit.new()
	new_trait_name_edit.placeholder_text = "例如：飞毛腿"
	content.add_child(new_trait_name_edit)

	new_trait_error_label = Label.new()
	new_trait_error_label.text = ""
	content.add_child(new_trait_error_label)

	var spacer = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(spacer)

	var buttons = HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_END
	content.add_child(buttons)

	var cancel_button = Button.new()
	cancel_button.text = "取消"
	cancel_button.pressed.connect(
		func():
			new_trait_dialog.hide()
	)
	buttons.add_child(cancel_button)

	var create_button = Button.new()
	create_button.text = "创建"
	create_button.pressed.connect(_on_new_trait_confirmed)
	buttons.add_child(create_button)

	# 回车也可以创建。
	new_trait_id_edit.text_submitted.connect(
		func(_text):
			_on_new_trait_confirmed()
	)
	new_trait_name_edit.text_submitted.connect(
		func(_text):
			_on_new_trait_confirmed()
	)

	get_editor_interface().get_base_control().add_child(new_trait_dialog)

	# Window 的右上角 X 默认只发出 close_requested，
	# 不会自动 hide/free，所以显式把它接成“取消”。
	new_trait_dialog.close_requested.connect(
		func():
			new_trait_dialog.hide()
	)

	print("✅ 新建标签弹窗创建完成")



func _normalize_trait_id(value: String) -> String:

	var result = value.strip_edges().to_lower()
	result = result.replace(" ", "_")
	return result


func _is_valid_trait_id(value: String) -> bool:

	if value.is_empty():
		return false

	for i in range(value.length()):
		var code = value.unicode_at(i)
		var is_lower = code >= 97 and code <= 122
		var is_digit = code >= 48 and code <= 57
		var is_underscore = code == 95

		if not is_lower and not is_digit and not is_underscore:
			return false

	return true


func _trait_id_exists(trait_id: String) -> bool:

	for trait_data in trait_resources:
		if trait_data == null:
			continue

		if str(trait_data.trait_id) == trait_id:
			return true

	return false


func _on_new_trait_confirmed():

	var trait_id = _normalize_trait_id(new_trait_id_edit.text)
	var trait_name = new_trait_name_edit.text.strip_edges()

	if trait_id.is_empty():
		_show_new_trait_error("标签 ID 不能为空")
		return

	if not _is_valid_trait_id(trait_id):
		_show_new_trait_error("ID 只能使用英文小写字母、数字和下划线")
		return

	if trait_name.is_empty():
		_show_new_trait_error("标签名称不能为空")
		return

	var file_path = TRAIT_FOLDER + trait_id + ".tres"

	if ResourceLoader.exists(file_path):
		_show_new_trait_error("文件已存在：" + trait_id + ".tres")
		return

	if _trait_id_exists(trait_id):
		_show_new_trait_error("标签 ID 已存在：" + trait_id)
		return

	var trait_data = TraitData.new()
	trait_data.trait_id = trait_id
	trait_data.trait_name = trait_name

	var error = ResourceSaver.save(trait_data, file_path)

	if error != OK:
		_show_new_trait_error("Trait 创建失败，错误代码：" + str(error))
		return

	print("✅ 创建 Trait：", file_path)

	# 创建成功后立即关闭新建窗口。
	if new_trait_dialog != null and is_instance_valid(new_trait_dialog):
		new_trait_dialog.hide()

	get_editor_interface().get_resource_filesystem().scan()
	_refresh_trait_list()

	for i in range(trait_list.item_count):
		var resource_data = trait_list.get_item_metadata(i)

		if resource_data == null:
			continue

		if resource_data.resource_path == file_path:
			trait_list.select(i)
			trait_list.ensure_current_is_visible()
			_load_trait_into_editor(resource_data)
			break


func _show_new_trait_error(message: String):

	new_trait_error_label.text = message



# ============================================================
# 点击 Trait
# ============================================================

func _on_trait_selected(index):

	if index < 0:
		return

	if index >= trait_list.item_count:
		return

	var trait_data = trait_list.get_item_metadata(index)

	if trait_data == null:
		return

	if not trait_data is TraitData:
		return

	_load_trait_into_editor(
		trait_data
	)


# ============================================================
# 将 Trait 数据载入中文编辑器
# ============================================================

func _load_trait_into_editor(trait_data):

	current_trait_data = trait_data


	if current_trait_data == null:

		save_button.disabled = true
		delete_button.disabled = true

		return


	# ========================================================
	# 基础信息
	# ========================================================

	id_edit.text = str(
		current_trait_data.trait_id
	)

	name_edit.text = str(
		current_trait_data.trait_name
	)


	description_edit.text = str(
		current_trait_data.description
	)


	# ========================================================
	# ICON
	# ========================================================

	icon_preview.icon = current_trait_data.icon
	icon_preview.text = "" if current_trait_data.icon != null else "?"


	# ========================================================
	# 枚举
	# ========================================================

	_select_option_by_id(
		type_option,
		current_trait_data.trait_type
	)


	_select_option_by_id(
		rarity_option,
		current_trait_data.rarity
	)


	_select_option_by_id(
		category_option,
		current_trait_data.category
	)


	# ========================================================
	# 权重
	# ========================================================

	weight_spin.value = (
		current_trait_data.weight
	)


	# ========================================================
	# 等级效果
	# ========================================================

	_load_levels_editor()


	save_button.disabled = false

	delete_button.disabled = false


	print(
		"🏷️ 编辑 Trait：",
		current_trait_data.trait_name
	)


# ============================================================
# OptionButton 根据 ID 选择
# ============================================================

func _select_option_by_id(
	option_button: OptionButton,
	target_id: int
):

	for i in range(
		option_button.item_count
	):

		if option_button.get_item_id(i) == target_id:

			option_button.select(i)

			return


# ============================================================
# 保存
# ============================================================

func _on_save_pressed():

	if current_trait_data == null:
		return


	# ========================================================
	# 名称
	# ========================================================

	var new_name = name_edit.text.strip_edges()


	if new_name.is_empty():

		push_warning(
			"标签名称不能为空"
		)

		return


	current_trait_data.trait_name = (
		new_name
	)


	# ========================================================
	# 描述
	# ========================================================

	current_trait_data.description = (
		description_edit.text
	)


	# ========================================================
	# 枚举
	# ========================================================

	current_trait_data.trait_type = (
		type_option.get_selected_id()
	)


	current_trait_data.rarity = (
		rarity_option.get_selected_id()
	)


	current_trait_data.category = (
		category_option.get_selected_id()
	)


	# ========================================================
	# 权重
	# ========================================================

	current_trait_data.weight = (
		weight_spin.value
	)


	# ========================================================
	# 等级效果
	# ========================================================

	if not _write_levels_from_editor():
		return


	# ========================================================
	# 保存 Resource
	# ========================================================

	var file_path = (
		current_trait_data.resource_path
	)


	var error = ResourceSaver.save(
		current_trait_data,
		file_path
	)


	if error != OK:

		push_error(
			"Trait 保存失败："
			+ str(error)
		)

		return


	print(
		"💾 Trait 已保存：",
		current_trait_data.trait_name
	)


	_refresh_trait_list()


	# ========================================================
	# 保存后重新选择当前 Trait
	# ========================================================

	for i in range(trait_list.item_count):

		var resource_data = trait_list.get_item_metadata(i)

		if resource_data == null:
			continue

		if resource_data.resource_path == file_path:

			trait_list.select(i)
			trait_list.ensure_current_is_visible()
			current_trait_data = resource_data
			break


# ============================================================
# 选择 ICON
# ============================================================

func _on_icon_select_pressed():

	if current_trait_data == null:
		return


	icon_dialog.popup_centered_ratio(
		0.7
	)


# ============================================================
# ICON 文件选择完成
# ============================================================

func _on_icon_file_selected(path):

	if current_trait_data == null:
		return


	var texture = ResourceLoader.load(
		path
	)


	if not texture is Texture2D:

		push_warning(
			"选择的文件不是有效的 Texture2D"
		)

		return


	current_trait_data.icon = texture

	icon_preview.icon = texture
	icon_preview.text = ""


# ============================================================
# 点击删除
# ============================================================

func _on_delete_trait_pressed():

	if current_trait_data == null:
		return


	var dialog = ConfirmationDialog.new()

	dialog.title = "删除标签"

	dialog.dialog_text = (
		"确定要删除标签：\n\n"
		+ str(current_trait_data.trait_name)
		+ "\n\n删除后对应的数据文件也会被移除。"
	)


	get_editor_interface().get_base_control().add_child(
		dialog
	)


	var data_to_delete = current_trait_data


	dialog.confirmed.connect(
		func():

			_delete_trait(
				data_to_delete
			)

			dialog.queue_free()
	)


	dialog.canceled.connect(
		func():

			dialog.queue_free()
	)


	dialog.popup_centered(
		Vector2i(
			420,
			220
		)
	)


# ============================================================
# 真正删除 Trait
# ============================================================

func _delete_trait(trait_data):

	if trait_data == null:
		return


	var file_path = trait_data.resource_path


	if file_path.is_empty():
		return


	var absolute_path = ProjectSettings.globalize_path(
		file_path
	)


	var error = DirAccess.remove_absolute(
		absolute_path
	)


	if error != OK:

		push_error(
			"Trait 删除失败："
			+ str(error)
		)

		return


	print(
		"🗑️ 已删除 Trait：",
		file_path
	)


	current_trait_data = null

	_clear_editor()


	get_editor_interface().get_resource_filesystem().scan()

	_refresh_trait_list()


# ============================================================
# 清空编辑区域
# ============================================================

func _clear_editor():

	id_edit.text = ""
	name_edit.text = ""

	description_edit.text = ""

	icon_preview.icon = null
	icon_preview.text = "?"

	weight_spin.value = 0.0

	_clear_levels_editor()

	if add_level_button != null:
		add_level_button.disabled = true

	save_button.disabled = true

	delete_button.disabled = true
