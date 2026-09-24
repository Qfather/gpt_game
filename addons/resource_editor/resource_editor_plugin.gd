@tool
extends EditorPlugin

const CATEGORY_LABELS: Array[String] = [
	"原材料",
	"建筑材料",
	"食物",
	"金属",
	"工具",
	"商品",
	"奢侈品",
	"燃料",
]

var main_panel: Control
var resource_list: ItemList
var resource_items: Array[ResourceData] = []
var current_resource: ResourceData

var category_filter: OptionButton
var tier_filter: SpinBox
var tag_filter: LineEdit

var id_edit: LineEdit
var name_edit: LineEdit
var icon_button: Button
var category_option: OptionButton
var tier_spin: SpinBox
var tags_edit: LineEdit
var stack_size_spin: SpinBox
var food_enabled: CheckBox
var nutrition_spin: SpinBox
var quality_spin: SpinBox
var variety_group_edit: LineEdit

var save_button: Button
var delete_button: Button
var icon_dialog: EditorFileDialog
var new_resource_window: Window
var new_id_edit: LineEdit
var new_name_edit: LineEdit
var new_error_label: Label


func _enter_tree() -> void:
	_create_main_panel()
	_create_icon_dialog()
	_refresh_resource_list()
	print("Resource Editor 插件启动")


func _exit_tree() -> void:
	if icon_dialog != null:
		icon_dialog.queue_free()
		icon_dialog = null
	if new_resource_window != null:
		new_resource_window.queue_free()
		new_resource_window = null
	if main_panel != null:
		remove_control_from_bottom_panel(main_panel)
		main_panel.queue_free()
		main_panel = null


func _create_main_panel() -> void:
	main_panel = VBoxContainer.new()
	main_panel.name = "ResourceEditor"
	main_panel.custom_minimum_size = Vector2(0.0, 460.0)

	var toolbar: HBoxContainer = HBoxContainer.new()
	main_panel.add_child(toolbar)

	var title: Label = Label.new()
	title.text = "资源数据库"
	title.add_theme_font_size_override("font_size", 20)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toolbar.add_child(title)

	save_button = Button.new()
	save_button.text = "保存修改"
	save_button.disabled = true
	save_button.pressed.connect(_on_save_pressed)
	toolbar.add_child(save_button)

	var refresh_button: Button = Button.new()
	refresh_button.text = "刷新"
	refresh_button.pressed.connect(_refresh_resource_list)
	toolbar.add_child(refresh_button)


	var new_button: Button = Button.new()
	new_button.text = "+ 新建资源"
	new_button.pressed.connect(_on_new_resource_pressed)
	toolbar.add_child(new_button)

	delete_button = Button.new()
	delete_button.text = "删除资源"
	delete_button.disabled = true
	delete_button.pressed.connect(_on_delete_pressed)
	toolbar.add_child(delete_button)

	var body: HSplitContainer = HSplitContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_panel.add_child(body)

	var left_panel: VBoxContainer = VBoxContainer.new()
	left_panel.custom_minimum_size.x = 330.0
	body.add_child(left_panel)
	_create_filters(left_panel)

	resource_list = ItemList.new()
	resource_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	resource_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	resource_list.item_selected.connect(_on_resource_selected)
	left_panel.add_child(resource_list)

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(scroll)

	var editor: VBoxContainer = VBoxContainer.new()
	editor.custom_minimum_size.x = 520.0
	editor.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(editor)
	_create_editor(editor)

	add_control_to_bottom_panel(main_panel, "资源")


func _create_filters(parent: VBoxContainer) -> void:
	var first_row: HBoxContainer = HBoxContainer.new()
	parent.add_child(first_row)

	category_filter = OptionButton.new()
	category_filter.add_item("全部分类", -1)
	for index: int in range(CATEGORY_LABELS.size()):
		category_filter.add_item(CATEGORY_LABELS[index], index)
	category_filter.item_selected.connect(_on_filter_changed)
	category_filter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	first_row.add_child(category_filter)

	var tier_label: Label = Label.new()
	tier_label.text = "Tier"
	first_row.add_child(tier_label)

	tier_filter = SpinBox.new()
	tier_filter.min_value = 0.0
	tier_filter.max_value = 100.0
	tier_filter.step = 1.0
	tier_filter.value = 0.0
	tier_filter.tooltip_text = "0 表示全部 Tier"
	tier_filter.value_changed.connect(_on_filter_value_changed)
	first_row.add_child(tier_filter)

	tag_filter = LineEdit.new()
	tag_filter.placeholder_text = "按 Tags 筛选，多个标签用逗号分隔"
	tag_filter.text_changed.connect(_on_filter_text_changed)
	parent.add_child(tag_filter)


func _create_editor(parent: VBoxContainer) -> void:
	var title: Label = Label.new()
	title.text = "资源资料"
	title.add_theme_font_size_override("font_size", 18)
	parent.add_child(title)
	parent.add_child(HSeparator.new())

	var basic_info_row: HBoxContainer = HBoxContainer.new()
	basic_info_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(basic_info_row)

	icon_button = Button.new()
	icon_button.text = "选择\n图标"
	icon_button.custom_minimum_size = Vector2(96.0, 96.0)
	icon_button.expand_icon = true
	icon_button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_button.tooltip_text = "点击选择资源图标"
	icon_button.pressed.connect(_on_icon_pressed)
	basic_info_row.add_child(icon_button)

	var basic_info_column: VBoxContainer = VBoxContainer.new()
	basic_info_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	basic_info_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	basic_info_row.add_child(basic_info_column)

	id_edit = LineEdit.new()
	id_edit.editable = false
	id_edit.placeholder_text = "资源 ID"
	id_edit.tooltip_text = "稳定 ID 创建后只读"
	id_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	basic_info_column.add_child(id_edit)

	name_edit = LineEdit.new()
	name_edit.placeholder_text = "显示名称"
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	basic_info_column.add_child(name_edit)

	category_option = OptionButton.new()
	for index: int in range(CATEGORY_LABELS.size()):
		category_option.add_item(CATEGORY_LABELS[index], index)
	_add_form_row(parent, "Category", category_option)

	tier_spin = SpinBox.new()
	tier_spin.min_value = 1.0
	tier_spin.max_value = 100.0
	tier_spin.step = 1.0
	_add_form_row(parent, "Tier", tier_spin)

	tags_edit = LineEdit.new()
	tags_edit.placeholder_text = "wood, raw, construction"
	_add_form_row(parent, "Tags", tags_edit)

	stack_size_spin = SpinBox.new()
	stack_size_spin.min_value = 1.0
	stack_size_spin.max_value = 1000000.0
	stack_size_spin.step = 1.0
	_add_form_row(parent, "堆叠上限", stack_size_spin)

	parent.add_child(HSeparator.new())
	food_enabled = CheckBox.new()
	food_enabled.text = "启用 FoodProperties"
	food_enabled.toggled.connect(_on_food_enabled_toggled)
	parent.add_child(food_enabled)

	nutrition_spin = SpinBox.new()
	nutrition_spin.min_value = 0.0
	nutrition_spin.max_value = 1000000.0
	nutrition_spin.step = 0.1
	_add_form_row(parent, "营养值", nutrition_spin)

	quality_spin = SpinBox.new()
	quality_spin.min_value = 0.0
	quality_spin.max_value = 1000000.0
	quality_spin.step = 0.1
	_add_form_row(parent, "食物品质", quality_spin)

	variety_group_edit = LineEdit.new()
	variety_group_edit.placeholder_text = "grain / meat"
	_add_form_row(parent, "多样性分组", variety_group_edit)

	_set_editor_enabled(false)


func _add_form_row(parent: VBoxContainer, label_text: String, control: Control) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	parent.add_child(row)

	var label: Label = Label.new()
	label.text = label_text
	label.custom_minimum_size.x = 120.0
	row.add_child(label)

	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(control)


func _create_icon_dialog() -> void:
	icon_dialog = EditorFileDialog.new()
	icon_dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
	icon_dialog.access = EditorFileDialog.ACCESS_RESOURCES
	icon_dialog.filters = PackedStringArray([
		"*.png, *.jpg, *.jpeg, *.webp, *.svg ; 图片文件"
	])
	icon_dialog.file_selected.connect(_on_icon_selected)
	get_editor_interface().get_base_control().add_child(icon_dialog)


func _create_new_resource_window() -> void:
	new_resource_window = Window.new()
	new_resource_window.title = "新建资源"
	new_resource_window.size = Vector2i(460, 300)
	new_resource_window.min_size = Vector2i(460, 300)
	new_resource_window.transient = true
	new_resource_window.exclusive = true
	new_resource_window.unresizable = true
	new_resource_window.close_requested.connect(new_resource_window.hide)

	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	new_resource_window.add_child(margin)

	var content: VBoxContainer = VBoxContainer.new()
	margin.add_child(content)

	var id_label: Label = Label.new()
	id_label.text = "稳定资源 ID"
	content.add_child(id_label)
	new_id_edit = LineEdit.new()
	new_id_edit.placeholder_text = "仅允许 a-z、0-9、_"
	content.add_child(new_id_edit)

	var name_label: Label = Label.new()
	name_label.text = "显示名称"
	content.add_child(name_label)
	new_name_edit = LineEdit.new()
	content.add_child(new_name_edit)

	new_error_label = Label.new()
	content.add_child(new_error_label)

	var spacer: Control = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(spacer)

	var buttons: HBoxContainer = HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_END
	content.add_child(buttons)
	var cancel_button: Button = Button.new()
	cancel_button.text = "取消"
	cancel_button.pressed.connect(new_resource_window.hide)
	buttons.add_child(cancel_button)
	var create_button: Button = Button.new()
	create_button.text = "创建"
	create_button.pressed.connect(_on_new_resource_confirmed)
	buttons.add_child(create_button)

	new_id_edit.text_submitted.connect(_on_new_id_submitted)
	new_name_edit.text_submitted.connect(_on_new_id_submitted)
	get_editor_interface().get_base_control().add_child(new_resource_window)


func _refresh_resource_list() -> void:
	var selected_id: StringName = current_resource.id if current_resource != null else &""
	resource_items = ResourceEditorDataService.scan_resources()
	current_resource = null
	_apply_filters()
	_clear_editor()

	if selected_id != &"":
		_select_resource_by_id(selected_id)


func _apply_filters() -> void:
	resource_list.clear()
	var selected_category: int = category_filter.get_selected_id()
	var selected_tier: int = int(tier_filter.value)
	var required_tags: Array[StringName] = _parse_tags(tag_filter.text)

	for resource_data: ResourceData in resource_items:
		if selected_category >= 0 and int(resource_data.category) != selected_category:
			continue
		if selected_tier > 0 and resource_data.tier != selected_tier:
			continue

		var matches_tags: bool = true
		for tag: StringName in required_tags:
			if not resource_data.has_tag(tag):
				matches_tags = false
				break
		if not matches_tags:
			continue

		var item_index: int = resource_list.add_item(
			"%s  [%s]  T%d" % [resource_data.display_name, resource_data.id, resource_data.tier]
		)
		resource_list.set_item_metadata(item_index, resource_data)
		if resource_data.icon != null:
			resource_list.set_item_icon(item_index, resource_data.icon)


func _on_filter_changed(_index: int) -> void:
	_apply_filters()


func _on_filter_value_changed(_value: float) -> void:
	_apply_filters()


func _on_filter_text_changed(_value: String) -> void:
	_apply_filters()


func _on_resource_selected(index: int) -> void:
	var metadata: Variant = resource_list.get_item_metadata(index)
	var resource_data: ResourceData = metadata as ResourceData
	if resource_data != null:
		_load_resource(resource_data)


func _load_resource(resource_data: ResourceData) -> void:
	current_resource = resource_data
	id_edit.text = str(resource_data.id)
	name_edit.text = resource_data.display_name
	icon_button.icon = resource_data.icon
	icon_button.text = "选择\n图标" if resource_data.icon == null else ""
	_select_option_by_id(category_option, int(resource_data.category))
	tier_spin.value = float(resource_data.tier)
	var tag_strings: PackedStringArray = []
	for tag: StringName in resource_data.tags:
		tag_strings.append(str(tag))
	tags_edit.text = ", ".join(tag_strings)
	stack_size_spin.value = float(resource_data.stack_size)

	food_enabled.button_pressed = resource_data.food_properties != null
	if resource_data.food_properties != null:
		nutrition_spin.value = resource_data.food_properties.nutrition
		quality_spin.value = resource_data.food_properties.food_quality
		variety_group_edit.text = str(resource_data.food_properties.variety_group)
	else:
		nutrition_spin.value = 0.0
		quality_spin.value = 0.0
		variety_group_edit.text = ""

	_set_editor_enabled(true)
	_update_food_fields()


func _clear_editor() -> void:
	id_edit.text = ""
	name_edit.text = ""
	icon_button.icon = null
	icon_button.text = "选择\n图标"
	tier_spin.value = 1.0
	tags_edit.text = ""
	stack_size_spin.value = 100.0
	food_enabled.button_pressed = false
	nutrition_spin.value = 0.0
	quality_spin.value = 0.0
	variety_group_edit.text = ""
	_set_editor_enabled(false)


func _set_editor_enabled(enabled: bool) -> void:
	name_edit.editable = enabled
	icon_button.disabled = not enabled
	category_option.disabled = not enabled
	tier_spin.editable = enabled
	tags_edit.editable = enabled
	stack_size_spin.editable = enabled
	food_enabled.disabled = not enabled
	save_button.disabled = not enabled
	delete_button.disabled = not enabled
	_update_food_fields()


func _update_food_fields() -> void:
	var enabled: bool = current_resource != null and food_enabled.button_pressed
	nutrition_spin.editable = enabled
	quality_spin.editable = enabled
	variety_group_edit.editable = enabled


func _on_food_enabled_toggled(_enabled: bool) -> void:
	_update_food_fields()


func _on_icon_pressed() -> void:
	if current_resource != null:
		icon_dialog.popup_centered_ratio(0.7)


func _on_icon_selected(path: String) -> void:
	var loaded_resource: Resource = ResourceLoader.load(path)
	var texture: Texture2D = loaded_resource as Texture2D
	if texture == null:
		_show_message("图标无效", "选择的文件不是 Texture2D。")
		return
	icon_button.icon = texture
	icon_button.text = ""


func _on_save_pressed() -> void:
	if current_resource == null:
		return

	var display_name: String = name_edit.text.strip_edges()
	if display_name.is_empty():
		_show_message("无法保存", "显示名称不能为空。")
		return

	current_resource.display_name = display_name
	current_resource.icon = icon_button.icon
	current_resource.category = category_option.get_selected_id()
	current_resource.tier = int(tier_spin.value)
	current_resource.tags = _parse_tags(tags_edit.text)
	current_resource.stack_size = int(stack_size_spin.value)

	if food_enabled.button_pressed:
		if current_resource.food_properties == null:
			current_resource.food_properties = FoodProperties.new()
		current_resource.food_properties.nutrition = float(nutrition_spin.value)
		current_resource.food_properties.food_quality = float(quality_spin.value)
		current_resource.food_properties.variety_group = StringName(
			variety_group_edit.text.strip_edges().to_lower()
		)
	else:
		current_resource.food_properties = null

	var save_error: Error = ResourceSaver.save(current_resource, current_resource.resource_path)
	if save_error != OK:
		_show_message("保存失败", "错误代码：%s" % save_error)
		return

	current_resource.emit_changed()
	get_editor_interface().get_resource_filesystem().scan()
	_refresh_resource_list()
	print("Resource Editor 已保存：", current_resource.id if current_resource != null else id_edit.text)


func _on_new_resource_pressed() -> void:
	if new_resource_window == null or not is_instance_valid(new_resource_window):
		_create_new_resource_window()

	new_id_edit.text = ""
	new_name_edit.text = ""
	new_error_label.text = ""
	new_resource_window.popup_centered(Vector2i(460, 300))
	new_id_edit.grab_focus()


func _on_new_id_submitted(_value: String) -> void:
	_on_new_resource_confirmed()


func _on_new_resource_confirmed() -> void:
	var normalized_id: String = ResourceEditorDataService.normalize_id(new_id_edit.text)
	var display_name: String = new_name_edit.text.strip_edges()

	if not ResourceEditorDataService.is_valid_id(normalized_id):
		new_error_label.text = "ID 只能使用英文小写字母、数字和下划线。"
		return
	if display_name.is_empty():
		new_error_label.text = "显示名称不能为空。"
		return
	if ResourceEditorDataService.resource_id_exists(StringName(normalized_id), resource_items):
		new_error_label.text = "资源 ID 已存在：%s" % normalized_id
		return

	var file_path: String = ResourceEditorDataService.RESOURCE_FOLDER + normalized_id + ".tres"
	if ResourceLoader.exists(file_path):
		new_error_label.text = "资源文件已存在：%s.tres" % normalized_id
		return

	var resource_data: ResourceData = ResourceData.new()
	resource_data.id = StringName(normalized_id)
	resource_data.display_name = display_name
	var save_error: Error = ResourceSaver.save(resource_data, file_path)
	if save_error != OK:
		new_error_label.text = "资源创建失败，错误代码：%s" % save_error
		return

	var loaded_resource: Resource = ResourceLoader.load(
		file_path,
		"",
		ResourceLoader.CACHE_MODE_REPLACE
	)
	var saved_data: ResourceData = loaded_resource as ResourceData
	var database_error: Error = ResourceEditorDataService.register_in_database(saved_data)
	if database_error != OK:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(file_path))
		new_error_label.text = "写入 ResourceDatabase 失败，错误代码：%s" % database_error
		return

	new_resource_window.hide()
	get_editor_interface().get_resource_filesystem().scan()
	current_resource = saved_data
	_refresh_resource_list()
	_select_resource_by_id(saved_data.id)
	print("Resource Editor 已创建：", saved_data.id)


func _on_delete_pressed() -> void:
	if current_resource == null:
		return

	var references: PackedStringArray = ResourceEditorDataService.find_database_references(
		current_resource
	)
	if not references.is_empty():
		_show_message(
			"无法删除资源",
			"资源仍被以下数据引用：\n\n" + "\n".join(references)
		)
		return

	var dialog: ConfirmationDialog = ConfirmationDialog.new()
	dialog.title = "删除资源"
	dialog.dialog_text = "确定删除 %s [%s]？" % [
		current_resource.display_name,
		current_resource.id,
	]
	get_editor_interface().get_base_control().add_child(dialog)
	var resource_to_delete: ResourceData = current_resource
	dialog.confirmed.connect(_delete_resource.bind(resource_to_delete, dialog))
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered(Vector2i(420, 220))


func _delete_resource(resource_data: ResourceData, dialog: ConfirmationDialog) -> void:
	var file_path: String = resource_data.resource_path
	var remove_error: Error = DirAccess.remove_absolute(ProjectSettings.globalize_path(file_path))
	dialog.queue_free()
	if remove_error != OK:
		_show_message("删除失败", "错误代码：%s" % remove_error)
		return

	current_resource = null
	get_editor_interface().get_resource_filesystem().scan()
	_refresh_resource_list()
	print("Resource Editor 已删除：", file_path)


func _show_message(title_text: String, message: String) -> void:
	var dialog: AcceptDialog = AcceptDialog.new()
	dialog.title = title_text
	dialog.dialog_text = message
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)
	get_editor_interface().get_base_control().add_child(dialog)
	dialog.popup_centered(Vector2i(520, 260))


func _parse_tags(value: String) -> Array[StringName]:
	var result: Array[StringName] = []
	for raw_tag: String in value.split(",", false):
		var normalized_tag: StringName = StringName(raw_tag.strip_edges().to_lower())
		if normalized_tag != &"" and not result.has(normalized_tag):
			result.append(normalized_tag)
	return result


func _select_option_by_id(option: OptionButton, target_id: int) -> void:
	for index: int in range(option.item_count):
		if option.get_item_id(index) == target_id:
			option.select(index)
			return


func _select_resource_by_id(resource_id: StringName) -> void:
	for index: int in range(resource_list.item_count):
		var metadata: Variant = resource_list.get_item_metadata(index)
		var resource_data: ResourceData = metadata as ResourceData
		if resource_data != null and resource_data.id == resource_id:
			resource_list.select(index)
			resource_list.ensure_current_is_visible()
			_load_resource(resource_data)
			return
