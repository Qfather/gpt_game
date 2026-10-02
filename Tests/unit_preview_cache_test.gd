extends SceneTree
func _init() -> void:
	call_deferred("_run")
func _run() -> void:
	var path: String = "res://.godot/unit_preview_cache_model.tscn"
	var old_text: String = FileAccess.get_file_as_string("res://Scene/unit/imp_visual.tscn")
	# 用反向根节点模拟编辑器已经加载的旧版模型，随后直接更新磁盘文件。
	var start: int = old_text.find("[node ")
	var declaration: String = old_text.substr(start, old_text.find("\n", start) - start)
	old_text = old_text.replace(declaration, declaration + "\nrotation_degrees = Vector3(0, 180, 0)")
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(old_text)
	file.close()
	var cached: PackedScene = load(path)
	file = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(FileAccess.get_file_as_string("res://Scene/unit/imp_visual.tscn"))
	file.close()
	var source: Node3D = cached.instantiate()
	assert((source.transform * source.get_node("Eye-1").position).z < 0.0)
	source.free()
	var preview: Control = load("res://addons/resource_editor/building_scene_preview.gd").new()
	root.add_child(preview)
	preview.show_scene(cached)
	var eye_visible_in_front: bool = false
	for mesh: MeshInstance3D in preview.model.get_children():
		if mesh.position.is_equal_approx(Vector3(0.095, 1.04, 0.24)): eye_visible_in_front = true
	assert(eye_visible_in_front)
	print("单位预览缓存测试通过：持有旧场景时，更新文件后仍显示新版正面")
	preview.queue_free()
	await process_frame
	quit(0 if eye_visible_in_front else 1)
