@tool
extends Node

var enabled := true
var _pending: Dictionary = {}
var _timer := Timer.new()

func _ready() -> void:
	_timer.one_shot = true
	_timer.wait_time = 0.5
	add_child(_timer)
	_timer.timeout.connect(flush)
	EditorInterface.get_inspector().property_edited.connect(_record)
	EditorInterface.get_inspector().edited_object_changed.connect(flush)

func _record(_property: String) -> void:
	if not enabled: return
	var object := EditorInterface.get_inspector().get_edited_object()
	if object is Resource or (object is Node and object.get_script() != null and object.get_script().resource_path.begins_with("res://addons/")):
		_pending[object] = true
		_timer.start()

func flush() -> void:
	_timer.stop()
	var root := EditorInterface.get_edited_scene_root()
	var save_scene := false
	for object in _pending:
		if not is_instance_valid(object): continue
		if object is Node:
			save_scene = save_scene or (root != null and (object == root or root.is_ancestor_of(object)))
			continue
		var path: String = object.resource_path.get_slice("::", 0)
		if path.ends_with(".tres") or path.ends_with(".res"):
			var resource: Resource = object if not object.resource_path.contains("::") else load(path)
			var error := ResourceSaver.save(resource, path)
			if error != OK: push_error("检查器参数自动保存失败：%s" % path)
		elif root != null and (path.is_empty() or path == root.scene_file_path):
			save_scene = true
	if save_scene and root != null and not root.scene_file_path.is_empty():
		EditorInterface.save_scene()
	_pending.clear()

func _exit_tree() -> void:
	flush()
