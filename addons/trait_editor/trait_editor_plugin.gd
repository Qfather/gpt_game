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

var name_edit: LineEdit
var description_edit: TextEdit

var icon_preview: TextureRect
var icon_path_edit: LineEdit
var icon_select_button: Button
var icon_dialog: EditorFileDialog

var type_option: OptionButton
var rarity_option: OptionButton
var category_option: OptionButton

var weight_spin: SpinBox

var save_button: Button


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

	var scroll = ScrollContainer.new()

	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL

	body.add_child(scroll)


	editor_panel = VBoxContainer.new()

	editor_panel.custom_minimum_size.x = 520

	editor_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	scroll.add_child(editor_panel)


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

	save_button = Button.new()
	save_button.text = "保存修改"
	save_button.disabled = true
	save_button.custom_minimum_size = Vector2(110, 34)
	save_button.pressed.connect(
		_on_save_pressed
	)
	header.add_child(save_button)

	editor_panel.add_child(
		HSeparator.new()
	)


	# ========================================================
	# 名称
	# ========================================================

	var name_label = Label.new()

	name_label.text = "标签名称"

	editor_panel.add_child(name_label)


	name_edit = LineEdit.new()

	name_edit.placeholder_text = "例如：飞毛腿"

	editor_panel.add_child(name_edit)


	# ========================================================
	# 描述
	# ========================================================

	var description_label = Label.new()

	description_label.text = "标签描述"

	editor_panel.add_child(description_label)


	description_edit = TextEdit.new()

	description_edit.custom_minimum_size.y = 75

	description_edit.placeholder_text = "填写这个标签的说明……"

	editor_panel.add_child(description_edit)


	# ========================================================
	# ICON
	# ========================================================

	var icon_label = Label.new()

	icon_label.text = "标签图标"

	editor_panel.add_child(icon_label)


	var icon_row = HBoxContainer.new()

	editor_panel.add_child(icon_row)


	icon_preview = TextureRect.new()

	icon_preview.custom_minimum_size = Vector2(
		64,
		64
	)

	icon_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE

	icon_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

	icon_row.add_child(icon_preview)


	var icon_controls = VBoxContainer.new()

	icon_controls.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	icon_row.add_child(icon_controls)


	icon_path_edit = LineEdit.new()

	icon_path_edit.editable = false

	icon_path_edit.placeholder_text = "尚未选择图标"

	icon_controls.add_child(icon_path_edit)


	icon_select_button = Button.new()

	icon_select_button.text = "选择图标"

	icon_select_button.pressed.connect(
		_on_icon_select_pressed
	)

	icon_controls.add_child(icon_select_button)


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

	var trait_data = TraitData.new()

	trait_data.trait_name = "新标签"


	var number = 1

	var file_path = (
		TRAIT_FOLDER
		+ "trait_"
		+ str(number)
		+ ".tres"
	)


	while ResourceLoader.exists(
		file_path
	):

		number += 1

		file_path = (
			TRAIT_FOLDER
			+ "trait_"
			+ str(number)
			+ ".tres"
		)


	var error = ResourceSaver.save(
		trait_data,
		file_path
	)


	if error != OK:

		push_error(
			"Trait 创建失败："
			+ str(error)
		)

		return


	print(
		"✅ 创建 Trait：",
		file_path
	)


	get_editor_interface().get_resource_filesystem().scan()

	_refresh_trait_list()


	# --------------------------------------------------------
	# 自动选中新标签
	# --------------------------------------------------------

	for i in range(trait_list.item_count):

		var resource_data = trait_list.get_item_metadata(i)

		if resource_data == null:
			continue

		if resource_data.resource_path == file_path:

			trait_list.select(i)
			trait_list.ensure_current_is_visible()
			_load_trait_into_editor(resource_data)
			break


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

	name_edit.text = str(
		current_trait_data.trait_name
	)


	description_edit.text = str(
		current_trait_data.description
	)


	# ========================================================
	# ICON
	# ========================================================

	icon_preview.texture = (
		current_trait_data.icon
	)


	if current_trait_data.icon != null:

		icon_path_edit.text = (
			current_trait_data.icon.resource_path
		)

	else:

		icon_path_edit.text = ""


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

	icon_preview.texture = texture

	icon_path_edit.text = path


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

	name_edit.text = ""

	description_edit.text = ""

	icon_preview.texture = null

	icon_path_edit.text = ""

	weight_spin.value = 0.0

	save_button.disabled = true

	delete_button.disabled = true
