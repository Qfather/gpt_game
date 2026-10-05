extends SceneTree

const FACTORY: Script = preload("res://Script/world/随机显示自己模型.gd")
const JUNCTION: Script = preload("res://Script/world/随机显示自己模型.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	for path: String in ["res://Scene/env/island/悬崖.tscn", "res://Scene/env/island/悬崖双面.tscn", "res://Scene/env/island/悬崖拐角2.tscn", "res://assets/modles/env/平面.glb"]:
		var scene: PackedScene = load(path)
		for seed_value: int in range(30):
			seed(seed_value)
			var original: Node3D = scene.instantiate() as Node3D
			root.add_child(original)
			var expected_random: int = randi()
			var original_signature: Array = _visible_signature(original)
			seed(seed_value)
			var cached: Node3D = FACTORY.instantiate_model(scene)
			root.add_child(cached)
			assert(randi() == expected_random, "接壤随机数消费发生变化")
			assert(_visible_signature(cached) == original_signature, "接壤可见外观发生变化")
			var expected_groups: int = 0 if path.ends_with("平面.glb") else 1 if path.ends_with("悬崖.tscn") else 2
			assert(_check_groups(cached) == expected_groups, "场景未正确加载随机模型脚本")
			original.free()
			cached.free()
		var started: int = Time.get_ticks_usec()
		for index: int in range(500):
			var original: Node3D = scene.instantiate() as Node3D
			root.add_child(original)
			original.free()
		var original_ms: float = (Time.get_ticks_usec() - started) / 1000.0
		started = Time.get_ticks_usec()
		for index: int in range(500):
			var cached: Node3D = FACTORY.instantiate_model(scene)
			root.add_child(cached)
			cached.free()
		print(path, " 500次生成与释放毫秒：原始=", original_ms, " 缓存=", (Time.get_ticks_usec() - started) / 1000.0)
	print("悬崖接壤缓存验证通过：120组对照、可见模型与材质、变换、随机数顺序、单候选保留、普通模型兼容")
	quit()

func _check_groups(node: Node) -> int:
	var count: int = 0
	if node.get_script() == JUNCTION:
		count = 1
		assert(node.get_child_count() == 1)
		assert(node.get_child(0).visible)
	for child: Node in node.get_children(): count += _check_groups(child)
	return count

func _visible_signature(node: Node) -> Array:
	var result: Array = [node.get_class()]
	if node is Node3D:
		result.append(node.transform)
	if node is MeshInstance3D:
		result.append(node.mesh)
		result.append(node.material_override)
		for surface: int in range(node.mesh.get_surface_count()):
			result.append(node.get_surface_override_material(surface))
	for child: Node in node.get_children():
		if child is Node3D and not child.visible: continue
		result.append([child.name, _visible_signature(child)])
	return result
