extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var runtime := MapGenerateRuntime.new()
	for path: String in ["res://Scene/resource/tree.tscn", "res://Scene/resource/stone.tscn"]:
		var scene: PackedScene = load(path)
		var entry := MapResourceEntry.new()
		entry.scene = scene
		assert(runtime._prepare_resource_spec(entry))
		for seed_value: int in range(60):
			var original: ResourceBase = scene.instantiate() as ResourceBase
			var cached: ResourceBase = runtime._instantiate_resource(scene, seed_value)
			original.visual_seed = seed_value
			cached.visual_seed = seed_value
			root.add_child(original)
			root.add_child(cached)
			await process_frame
			var original_visual: Node3D = original.get_node("meshs")
			var cached_visual: Node3D = cached.get_node("meshs")
			assert(original_visual.get_child_count() == 1 and cached_visual.get_child_count() == 1)
			assert(original_visual.transform.is_equal_approx(cached_visual.transform))
			assert(_visual_signature(original_visual) == _visual_signature(cached_visual))
			assert(original.get_build_obstacle_bounds().is_equal_approx(cached.get_build_obstacle_bounds()))
			original.free()
			cached.free()
		# 缓存命中后不再实例化全部候选，比较同样数量的实例化和释放耗时。
		var started: int = Time.get_ticks_usec()
		for index: int in range(200):
			var original: Node = scene.instantiate()
			original.free()
		var original_ms: float = (Time.get_ticks_usec() - started) / 1000.0
		started = Time.get_ticks_usec()
		for index: int in range(200):
			var cached: Node = runtime._instantiate_resource(scene, index % 60)
			cached.free()
		var cached_ms: float = (Time.get_ticks_usec() - started) / 1000.0
		print(path, " 200次实例化与释放毫秒：原始=", original_ms, " 缓存=", cached_ms)
	var tree: ResourceBase = runtime._instantiate_resource(MapGenerateRuntime.TREE_SCENE, 42)
	tree.visual_seed = 42
	tree.growth_duration = 0.01
	root.add_child(tree)
	assert(tree.growth_progress == 0.0 and tree.get_node("meshs").scale == Vector3.ZERO)
	for frame: int in range(5): await process_frame
	assert(tree.is_mature() and tree.get_node("meshs").scale.length() > 0.0)
	tree.free()
	runtime.free()
	print("资源外观缓存验证通过：120组种子、模型与材质、随机旋转缩放、碰撞范围、再生生长")
	quit()

func _visual_signature(node: Node) -> Array:
	var result: Array = [node.name, node.get_class()]
	if node is Node3D:
		result.append(node.transform)
		result.append(node.visible)
	if node is MeshInstance3D:
		result.append(node.mesh)
		result.append(node.material_override)
		for surface: int in range(node.mesh.get_surface_count()):
			result.append(node.get_surface_override_material(surface))
	for child: Node in node.get_children(): result.append(_visual_signature(child))
	return result
