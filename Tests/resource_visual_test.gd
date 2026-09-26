extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var trees_failed: bool = await _test_scene("res://Scene/resource/tree.tscn")
	var stones_failed: bool = await _test_scene("res://Scene/resource/stone.tscn")
	quit(1 if trees_failed or stones_failed else 0)


func _test_scene(path: String) -> bool:
	var scene: PackedScene = load(path)
	var variants: Dictionary = {}
	var signatures: Array[String] = []
	var failed: bool = false
	for pass_index: int in range(2):
		for index: int in range(60):
			var tree: ResourceBase = scene.instantiate() as ResourceBase
			tree.visual_seed = index
			root.add_child(tree)
			await process_frame
			var visuals: Node3D = tree.get_node("meshs") as Node3D
			var size: float = visuals.scale.x
			failed = failed or visuals.get_child_count() != 1 or size < 0.5 or size > 1.5
			failed = failed or not visuals.scale.is_equal_approx(Vector3.ONE * size)
			var selected: Node3D = visuals.get_child(0) as Node3D
			failed = failed or not selected.visible
			variants[selected.name] = true
			var signature: String = str(selected.name, visuals.transform)
			if pass_index == 0:
				signatures.append(signature)
			else:
				failed = failed or signatures[index] != signature
			var collision: CollisionShape3D = tree.get_node("StaticBody3D/CollisionShape3D") as CollisionShape3D
			failed = failed or not collision.scale.is_equal_approx(Vector3.ONE)
			if collision.shape is CylinderShape3D:
				failed = failed or not is_equal_approx((collision.shape as CylinderShape3D).radius, 0.5)
			else:
				failed = failed or (collision.shape as BoxShape3D).size != Vector3(1, 0.5, 1)
			tree.free()
	failed = failed or variants.size() != 3
	print("资源外观测试", "失败" if failed else "通过", "：", path, " 三种候选、单个保留、缩放范围、碰撞不变、种子复现")
	return failed
