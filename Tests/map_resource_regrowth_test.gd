extends SceneTree

var failed: bool = false

func _init() -> void:
	call_deferred("_run")

func _expect(value: bool, message: String) -> void:
	print("[", "通过" if value else "失败", "] ", message)
	if not value:
		failed = true
		push_error(message)

func _run() -> void:
	var scene: Node3D = load("res://Scene/main.tscn").instantiate()
	scene.level_preset = scene.level_preset.duplicate(true)
	scene.level_preset.layout_seed = 418
	scene.level_preset.map_config.seed_value = 418
	scene.level_preset.events.clear()
	scene.level_preset.camp_config.enabled = false
	scene.level_preset.settlement_config.initial_villagers = 0
	for entry: MapResourceEntry in scene.level_preset.map_resources:
		entry.count = 24
		entry.regrowth_wait_min = 0.1
		entry.regrowth_wait_max = 0.1
		entry.growth_time_min = 1.0
		entry.growth_time_max = 1.0
	root.add_child(scene)
	current_scene = scene
	await process_frame
	await process_frame
	var runtime: MapGenerateRuntime = scene.get_node("Systems/MapGenerateRuntime")
	var resources: Node = runtime.get_node("GeneratedResources")
	var original_count: int = resources.get_child_count()
	_expect(original_count > 24, "真实地图生成树林与石群")
	for cycle: int in range(3):
		var removed_ids: Dictionary = {&"wood": 0, &"stone": 0}
		for node: ResourceBase in resources.get_children():
			if node.can_gather() and removed_ids[node.resource_id] < 4:
				removed_ids[node.resource_id] += 1
				node.gather(node.resource_amount)
		await process_frame
		runtime.set_process(false)
		_expect(runtime._pending_regrowth.size() == 8, "树林与石群耗尽产生八个再生空缺")
		for attempt: int in range(30):
			runtime._process(5.1)
			runtime.set_process(false)
			if runtime._pending_regrowth.is_empty(): break
		_expect(resources.get_child_count() == original_count and runtime._resource_points.size() == original_count, "连续再生循环%d不增加资源总数量且同步占地记录" % (cycle + 1))
		var growing: int = 0
		for node: ResourceBase in resources.get_children():
			if not node.is_mature():
				growing += 1
				_expect(not runtime._overlaps_regrowth_building(runtime._point_geometry[node.global_position]), "再生资源不与真实地图建筑重叠")
				node._process(1.1)
		_expect(growing == 8, "树林与石头再生都经过生长阶段")
		var all: Array[Vector3] = runtime._resource_points
		var spacing_valid: bool = true
		for i: int in range(all.size()):
			for j: int in range(i + 1, all.size()):
				var required: float = maxf(runtime._point_spacings[all[i]], runtime._point_spacings[all[j]])
				spacing_valid = spacing_valid and runtime._edge_gap(runtime._point_geometry[all[i]], runtime._point_geometry[all[j]]) >= required
		_expect(spacing_valid, "再生仍遵守资源边缘间距")
	scene.queue_free()
	await process_frame
	quit(1 if failed else 0)
