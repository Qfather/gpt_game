extends SceneTree
func _init() -> void:
	call_deferred("_schedule")
func _schedule() -> void:
	create_timer(5).timeout.connect(_run)
func _run() -> void:
	var preview: Control = load("res://addons/resource_editor/building_scene_preview.gd").new()
	root.add_child(preview)
	var count: int = 0
	for folder: String in ["res://Scene/unit/", "res://Scene/unit/boss/"]:
		for file: String in DirAccess.get_files_at(folder):
			if not file.ends_with("visual.tscn"): continue
			var scene: PackedScene = load(folder + file)
			var node: Node3D = scene.instantiate()
			assert(node.rotation.is_equal_approx(Vector3.ZERO))
			assert(node.scale.x > 0.0 and node.scale.y > 0.0 and node.scale.z > 0.0)
			var eye_count: int = 0
			for child: Node3D in node.get_children():
				if String(child.name).contains("Eye"):
					assert(child.position.z > 0.0)
					eye_count += 1
			assert(eye_count > 0)
			node.free()
			preview.show_scene(scene)
			assert(preview.mesh_count > 0)
			if DisplayServer.get_name() != "headless":
				await RenderingServer.frame_post_draw
				preview.viewport.get_texture().get_image().save_png("res://.godot/unit_facing_" + file.trim_suffix(".tscn") + ".png")
			count += 1
	assert(count == 13)
	preview.queue_free()
	await process_frame
	print("单位朝向测试通过：13个模型正面为+Z、根节点不含朝向补偿、图形预览完成")
	quit()
