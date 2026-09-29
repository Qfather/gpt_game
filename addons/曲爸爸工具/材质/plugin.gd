@tool
extends EditorPlugin

const ROOT_MENU := "曲爸爸工具"
const ACTION_ID := 1
const BRIDGE_TOOL_SCRIPT: Script = preload("res://addons/曲爸爸工具/桥接/空对象替换为GLB实例工具.gd")

var _dialog: ConfirmationDialog
var _resource_picker: EditorResourcePicker
var _selected_roots: Array[Node] = []
var _main_menu: PopupMenu
var _bridge_tool: Variant

func _enter_tree() -> void:
	_main_menu = PopupMenu.new()
	var material_menu := PopupMenu.new()
	material_menu.add_item("批量设置选中GLB材质", ACTION_ID)
	material_menu.id_pressed.connect(_on_material_menu_pressed)
	_main_menu.add_submenu_node_item("材质", material_menu)
	_bridge_tool = BRIDGE_TOOL_SCRIPT.new()
	_bridge_tool.add_to_menu(self, _main_menu)
	add_tool_submenu_item(ROOT_MENU, _main_menu)

func _exit_tree() -> void:
	remove_tool_menu_item(ROOT_MENU)
	if is_instance_valid(_main_menu):
		_main_menu.queue_free()
	if is_instance_valid(_dialog):
		_dialog.queue_free()
	if _bridge_tool != null:
		_bridge_tool.cleanup()

func _on_material_menu_pressed(id: int) -> void:
	if id == ACTION_ID:
		_open_material_dialog()

func _open_material_dialog() -> void:
	_selected_roots.clear()
	for node in EditorInterface.get_selection().get_selected_nodes():
		_selected_roots.append(node)
	if _selected_roots.is_empty():
		return
	if not is_instance_valid(_dialog):
		_dialog = ConfirmationDialog.new()
		_dialog.title = "批量设置 GLB 材质"
		_dialog.size = Vector2i(520, 120)
		_dialog.ok_button_text = "应用到选中 GLB"
		_dialog.confirmed.connect(_apply_material)
		_resource_picker = EditorResourcePicker.new()
		_resource_picker.base_type = "Material"
		_resource_picker.custom_minimum_size = Vector2(420, 36)
		_dialog.add_child(_resource_picker)
		add_child(_dialog)
	if _selected_roots.size() == 1:
		_dialog.dialog_text = "选择要应用到 1 个选中节点的材质："
	else:
		_dialog.dialog_text = "选择要应用到 %d 个选中节点的材质：" % _selected_roots.size()
	_dialog.popup_centered()

func _apply_material() -> void:
	var material := _resource_picker.edited_resource as Material
	if material == null:
		return
	var targets: Array[MeshInstance3D] = []
	var edited_scene_root := EditorInterface.get_edited_scene_root()
	for root in _selected_roots:
		if not is_instance_valid(root):
			continue
		if edited_scene_root != null and edited_scene_root != root and edited_scene_root.is_ancestor_of(root):
			edited_scene_root.set_editable_instance(root, true)
		_collect_mesh_instances(root, targets)
	if targets.is_empty():
		return
	var undo_redo := get_undo_redo()
	undo_redo.create_action("批量设置 GLB 材质")
	for mesh_instance in targets:
		undo_redo.add_do_property(mesh_instance, "material_override", material)
		undo_redo.add_undo_property(mesh_instance, "material_override", mesh_instance.material_override)
	undo_redo.commit_action()
	EditorInterface.mark_scene_as_unsaved()

func _collect_mesh_instances(node: Node, targets: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D and not targets.has(node):
		targets.append(node)
	for child in node.get_children():
		_collect_mesh_instances(child, targets)
