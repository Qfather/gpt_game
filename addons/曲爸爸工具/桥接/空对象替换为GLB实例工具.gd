@tool
extends RefCounted

const ACTION_ID := 1

var _plugin: EditorPlugin
var _dialog: Window
var _file_dialog: EditorFileDialog
var _group_rows: Array[Dictionary] = []
var _bridge_root: Node3D
var _groups: Array[Dictionary] = []
var _active_group_row := -1

func add_to_menu(plugin: EditorPlugin, parent_menu: PopupMenu) -> void:
	_plugin = plugin
	var bridge_menu := PopupMenu.new()
	bridge_menu.add_item("按组批量替换桥接空对象", ACTION_ID)
	bridge_menu.id_pressed.connect(_on_menu_item_pressed)
	parent_menu.add_submenu_node_item("桥接", bridge_menu)

func cleanup() -> void:
	if is_instance_valid(_dialog):
		_dialog.queue_free()
	if is_instance_valid(_file_dialog):
		_file_dialog.queue_free()

func _on_menu_item_pressed(id: int) -> void:
	if id != ACTION_ID:
		return
	var selection := EditorInterface.get_selection().get_selected_nodes()
	if selection.size() != 1 or not selection[0] is Node3D:
		push_warning("请只选择场景中的一个桥接 GLB 实例。")
		return
	_bridge_root = selection[0] as Node3D
	if _bridge_root.scene_file_path.get_extension().to_lower() != "glb":
		push_warning("所选节点不是 GLB 场景实例。")
		return
	_groups.clear()
	_collect_point_groups(_bridge_root, _groups)
	if _groups.is_empty():
		push_warning("所选节点中没有找到“父节点包含一批直接空对象”的组。")
		return
	_open_dialog()

func _open_dialog() -> void:
	if is_instance_valid(_dialog):
		_dialog.queue_free()
	_dialog = Window.new()
	_dialog.title = "按组替换桥接空对象"
	_dialog.size = Vector2i(680, max(250, 150 + _groups.size() * 50))
	_dialog.exclusive = false
	_dialog.close_requested.connect(_dialog.hide)
	_plugin.add_child(_dialog)
	_group_rows.clear()
	var panel := PanelContainer.new()
	_dialog.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin := MarginContainer.new()
	panel.add_child(margin)
	for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		margin.add_theme_constant_override(side, 16)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	margin.add_child(content)
	var total_points := 0
	for group_data in _groups:
		var points: Array = group_data.points
		total_points += points.size()
	var instructions := Label.new()
	instructions.text = "为每个父节点组选择一个模型 GLB（共 %d 个点位）：" % total_points
	content.add_child(instructions)
	for group_data in _groups:
		var points: Array = group_data.points
		var row := HBoxContainer.new()
		content.add_child(row)
		var label := Label.new()
		label.text = "%s（%d 个）" % [group_data.node.name, points.size()]
		label.custom_minimum_size = Vector2(210, 0)
		row.add_child(label)
		var path_label := Label.new()
		path_label.text = "未选择 GLB"
		path_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(path_label)
		var choose_button := Button.new()
		choose_button.text = "选择 GLB"
		row.add_child(choose_button)
		var row_index := _group_rows.size()
		choose_button.pressed.connect(_open_model_file_dialog.bind(row_index))
		_group_rows.append({"path_label": path_label, "group": group_data, "scene": null})
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(spacer)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_END
	content.add_child(buttons)
	var cancel_button := Button.new()
	cancel_button.text = "取消"
	cancel_button.custom_minimum_size = Vector2(90, 32)
	cancel_button.pressed.connect(_dialog.hide)
	buttons.add_child(cancel_button)
	var confirm_button := Button.new()
	confirm_button.text = "替换全部"
	confirm_button.custom_minimum_size = Vector2(100, 32)
	confirm_button.pressed.connect(_replace_all_groups)
	buttons.add_child(confirm_button)
	_dialog.popup_centered()

func _open_model_file_dialog(group_row_index: int) -> void:
	if not is_instance_valid(_file_dialog):
		_file_dialog = EditorFileDialog.new()
		_file_dialog.title = "选择模型 GLB"
		_file_dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
		_file_dialog.access = EditorFileDialog.ACCESS_RESOURCES
		_file_dialog.add_filter("*.glb; GLB 场景")
		_file_dialog.exclusive = false
		_file_dialog.file_selected.connect(_on_model_file_selected)
		_plugin.add_child(_file_dialog)
	_active_group_row = group_row_index
	_file_dialog.popup_centered(Vector2i(900, 600))

func _on_model_file_selected(path: String) -> void:
	if path.get_extension().to_lower() != "glb" or _active_group_row < 0 or _active_group_row >= _group_rows.size():
		return
	var model_scene := ResourceLoader.load(path) as PackedScene
	if model_scene == null:
		push_warning("无法读取 GLB 场景：%s" % path)
		return
	var preview := model_scene.instantiate()
	if not preview is Node3D:
		preview.free()
		push_warning("GLB 场景根节点不是 Node3D：%s" % path)
		return
	preview.free()
	_group_rows[_active_group_row]["scene"] = model_scene
	_group_rows[_active_group_row]["path_label"].text = path.get_file()

func _replace_all_groups() -> void:
	var edited_scene_root := EditorInterface.get_edited_scene_root()
	if edited_scene_root == null or not is_instance_valid(_bridge_root):
		return
	var models: Array[Dictionary] = []
	for row in _group_rows:
		var model_scene := row.scene as PackedScene
		if model_scene == null or model_scene.resource_path.get_extension().to_lower() != "glb":
			push_warning("请为组“%s”选择一个 GLB 场景。" % row.group.node.name)
			return
		var preview := model_scene.instantiate()
		if not preview is Node3D:
			preview.free()
			push_warning("组“%s”所选 GLB 的根节点不是 Node3D。" % row.group.node.name)
			return
		preview.free()
		models.append({"scene": model_scene, "group": row.group})
	var records: Array[Dictionary] = []
	for model in models:
		for point in model.group.points:
			if not is_instance_valid(point) or not point.is_inside_tree():
				continue
			var replacement := model.scene.instantiate() as Node3D
			replacement.name = point.name
			replacement.transform = point.transform * replacement.transform
			records.append({
				"parent": point.get_parent(),
				"point": point,
				"replacement": replacement,
				"owner": edited_scene_root,
				"old_owner": point.owner,
				"index": point.get_index(),
			})
	if records.is_empty():
		return
	_enable_source_instance_editing(_bridge_root, edited_scene_root)
	records.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a.parent == b.parent:
			return a.index > b.index
		return str(a.parent.get_path()) < str(b.parent.get_path())
	)
	var undo_redo := _plugin.get_undo_redo()
	undo_redo.create_action("按组批量替换桥接空对象")
	for record in records:
		undo_redo.add_do_method(self, "_do_replace", record)
		undo_redo.add_undo_method(self, "_undo_replace", record)
	undo_redo.commit_action()
	EditorInterface.mark_scene_as_unsaved()
	_dialog.hide()

func _collect_point_groups(node: Node, found: Array[Dictionary]) -> void:
	var children := node.get_children()
	if not children.is_empty() and _children_are_empty_points(children):
		found.append({"node": node, "points": children})
		return
	for child in children:
		_collect_point_groups(child, found)

func _children_are_empty_points(children: Array[Node]) -> bool:
	for child in children:
		if not child is Node3D or child.get_child_count() > 0:
			return false
		if child is MeshInstance3D:
			return false
	return true

func _enable_source_instance_editing(source: Node, edited_scene_root: Node) -> void:
	if source != edited_scene_root and edited_scene_root.is_ancestor_of(source):
		edited_scene_root.set_editable_instance(source, true)

func _do_replace(record: Dictionary) -> void:
	var parent: Node = record.parent
	var point: Node3D = record.point
	var replacement: Node3D = record.replacement
	parent.add_child(replacement)
	replacement.owner = record.owner
	parent.move_child(replacement, record.index)
	parent.remove_child(point)

func _undo_replace(record: Dictionary) -> void:
	var parent: Node = record.parent
	var point: Node3D = record.point
	var replacement: Node3D = record.replacement
	parent.add_child(point)
	point.owner = record.old_owner
	parent.move_child(point, record.index)
	parent.remove_child(replacement)
