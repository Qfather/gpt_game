extends Node3D

# 直接挂载时随机显示一个子模型；生成入口调用 instantiate_model 时复用单模型模板。
# 模板首次构建仍会短暂创建全部候选，缓存命中后只实例化选中的模型。
func _ready() -> void:
	if get_meta("junction_variant_preselected", false):
		return
	var selected := randi_range(0, get_child_count() - 1)
	for i in range(get_child_count()):
		get_child(i).visible = i == selected

static var _scene_cache: Dictionary = {}

static func instantiate_model(scene: PackedScene) -> Node3D:
	var template: Node3D
	if not _scene_cache.has(scene):
		template = scene.instantiate() as Node3D
		var discovered_groups: Array[Dictionary] = []
		_collect_groups(template, template, discovered_groups)
		_scene_cache[scene] = {"groups": discovered_groups, "variants": {}}
	var record: Dictionary = _scene_cache[scene]
	var groups: Array[Dictionary] = record.groups
	if groups.is_empty():
		return template if template != null else scene.instantiate() as Node3D
	# 与各接壤节点原来的 ready 顺序一致，每组仍消费一次全局随机数。
	var choices: Array[int] = []
	for group: Dictionary in groups:
		choices.append(randi_range(0, int(group.count) - 1))
	var key: String = str(choices)
	var variants: Dictionary = record.variants
	if not variants.has(key):
		if template == null: template = scene.instantiate() as Node3D
		for index: int in range(groups.size()):
			var junction: Node3D = template.get_node(groups[index].path) as Node3D
			var candidates: Array[Node] = junction.get_children()
			for candidate_index: int in range(candidates.size()):
				var candidate: Node3D = candidates[candidate_index] as Node3D
				if candidate_index == choices[index]:
					candidate.show()
				else:
					junction.remove_child(candidate)
					candidate.free()
			junction.set_meta("junction_variant_preselected", true)
		var variant := PackedScene.new()
		variant.pack(template)
		variants[key] = variant
		template.free()
	return (variants[key] as PackedScene).instantiate() as Node3D

static func _collect_groups(node: Node, scene_root: Node, groups: Array[Dictionary]) -> void:
	for child: Node in node.get_children():
		_collect_groups(child, scene_root, groups)
	if node.get_script() != null and node.get_script().resource_path == "res://Script/world/随机显示自己模型.gd":
		groups.append({"path": scene_root.get_path_to(node), "count": node.get_child_count()})
