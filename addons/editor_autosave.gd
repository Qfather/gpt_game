@tool
extends Node

# 各面板共用延迟保存；载入数据时暂停，保存时产生的 UI 刷新不会再次触发保存。
var enabled := true
var suspended := false
var pending := false
var _saving := false
var _callback: Callable
var _timer := Timer.new()
var _watched := {}

func configure(owner_node: Node, callback: Callable, controls: Node) -> void:
	_callback = callback
	owner_node.add_child(self)
	_timer.one_shot = true
	_timer.wait_time = 0.5
	add_child(_timer)
	_timer.timeout.connect(flush)
	watch(controls)

func request(_value: Variant = null) -> void:
	if not enabled or suspended or _saving or not is_inside_tree():
		return
	pending = true
	_timer.start()

func flush() -> bool:
	if not pending or _saving:
		return true
	_timer.stop()
	_saving = true
	var result: Variant = _callback.call()
	_saving = false
	if result is bool and not result:
		return false
	pending = false
	return true

func pause() -> bool:
	if not flush():
		return false
	suspended = true
	return true

func cancel() -> void:
	pending = false
	_timer.stop()

func _exit_tree() -> void:
	flush()

func watch(node: Node) -> void:
	if not is_instance_valid(node) or _watched.has(node.get_instance_id()):
		return
	var id := node.get_instance_id()
	_watched[id] = true
	node.tree_exited.connect(func(): _watched.erase(id))
	node.child_entered_tree.connect(func(child: Node): _watch_id.call_deferred(child.get_instance_id()))
	if node is EditorInspector:
		node.property_edited.connect(request)
	else:
		var parent := node.get_parent()
		while parent != null and not parent is EditorInspector:
			parent = parent.get_parent()
		if parent == null:
			if node is SpinBox: node.value_changed.connect(request)
			elif node is LineEdit: node.text_changed.connect(request)
			elif node is TextEdit: node.text_changed.connect(request)
			elif node is OptionButton: node.item_selected.connect(request)
			elif node is CheckBox: node.toggled.connect(request)
			elif node is ColorPickerButton: node.color_changed.connect(request)
			elif node is EditorResourcePicker: node.resource_changed.connect(request)
			elif node is PopupMenu: node.id_pressed.connect(request)
			elif node is Button and node.toggle_mode: node.toggled.connect(request)
			elif node is Button and ("添加" in node.text or "删除" in node.text or "移除" in node.text or "复制" in node.text):
				node.pressed.connect(request)
	for child in node.get_children():
		watch(child)

func _watch_id(id: int) -> void:
	var node = instance_from_id(id)
	if is_instance_valid(node): watch(node)
