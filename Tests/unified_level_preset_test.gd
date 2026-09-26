extends SceneTree

var failed: bool = false


func _initialize() -> void:
	call_deferred("_run")


func _expect(value: bool, message: String) -> void:
	if not value:
		failed = true
		push_error(message)


func _run() -> void:
	var original: LevelFlowData = load("res://data/levels/LevelFlow_V0.tres") as LevelFlowData
	var preset: LevelFlowData = original.duplicate(true) as LevelFlowData
	preset.layout_seed = 42
	preset.map_config.seed_value = 1234
	preset.rift_min_base_distance = 35.0
	preset.map_resources[0].enabled = false
	preset.map_resources[1].count = 12
	preset.map_resources[1].minimum_spacing = 3.0
	preset.map_resources[1].neighbor_distance_max = 3.4
	var path: String = "res://.godot/unified_level_test.tres"
	_expect(ResourceSaver.save(preset, path) == OK, "关卡保存失败")
	var restored: LevelFlowData = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as LevelFlowData
	_expect(restored != null and restored.map_config.cell_size_m == 3.0, "地图配置重载失败")
	_expect(restored.map_config.seed_value == 1234, "修改后的地形种子未保存")
	_expect(restored.rift_min_base_distance == 35.0, "裂缝距据点配置未保存")
	_expect(restored.events.size() == original.events.size(), "出怪事件丢失")
	_expect(restored.events[0].start_time == original.events[0].start_time, "出怪时间改变")
	_expect(not restored.map_resources[0].enabled and restored.map_resources[1].count == 12, "资源启停或数量保存失败")
	_expect(original.map_resources[0].enabled and original.map_resources[1].count == 48, "编辑副本污染原预设")
	await _check_generation(restored, 12, 3.0)
	var trees_only: LevelFlowData = original.duplicate(true) as LevelFlowData
	trees_only.layout_seed = 42
	trees_only.map_resources[0].count = 20
	trees_only.map_resources[1].enabled = false
	await _check_generation(trees_only, 20, 1.1)
	var empty: LevelFlowData = original.duplicate(true) as LevelFlowData
	empty.map_resources.clear()
	await _check_generation(empty, 0, 0.0)
	# 新的场景资源引用走同一套生成代码，不依赖树/石头常量分支。
	var custom: LevelFlowData = original.duplicate(true) as LevelFlowData
	custom.map_resources.clear()
	var entry := MapResourceEntry.new()
	entry.scene = load("res://Scene/resource/tree.tscn").duplicate() as PackedScene
	entry.count = 6
	custom.map_resources.append(entry)
	custom.layout_seed = 42
	await _check_generation(custom, 6, 1.45)
	print("统一关卡预设测试", "失败" if failed else "通过", "：保存重载、出怪保留、资源启停、空列表、间距、新场景引用")
	quit(1 if failed else 0)


func _check_generation(preset: LevelFlowData, count: int, spacing: float) -> void:
	var scene: Node = load("res://Scene/main.tscn").instantiate()
	scene.level_preset = preset
	root.add_child(scene)
	await process_frame
	await process_frame
	var generator: MapGenerateRuntime = scene.get_node("Systems/MapGenerateRuntime") as MapGenerateRuntime
	var director: EncounterDirector = scene.get_node("Systems/EncounterDirector") as EncounterDirector
	_expect(director.level_flow == preset and generator.level_config == preset.map_config, "地图与出怪没有读取同一预设")
	_expect(scene.get_node("Systems/RiftManager").minimum_base_distance == preset.rift_min_base_distance, "裂缝距离未读取关卡预设")
	_expect(generator.map_data.generation_seed == preset.map_config.seed_value, "地形没有使用预设种子")
	var nodes: Array[Node] = generator.get_node("GeneratedResources").get_children()
	_expect(nodes.size() == count, "资源启停/数量未生效：" + str(nodes.size(), "/", count))
	for i: int in range(nodes.size()):
		for j: int in range(i):
			var a: Vector3 = (nodes[i] as Node3D).global_position
			var b: Vector3 = (nodes[j] as Node3D).global_position
			_expect(Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z)) >= spacing - 0.001, "资源间距配置未生效")
	scene.queue_free()
	await process_frame
	await process_frame
