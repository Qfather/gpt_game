extends SceneTree

class TestRuntime extends MapGenerateRuntime:
	func _ready() -> void:
		set_process(false)

var failed := false

func _initialize() -> void:
	call_deferred("_run")

func _expect(value: bool, message: String) -> void:
	print("[", "通过" if value else "失败", "] ", message)
	if not value: failed = true

func _make_runtime() -> MapGenerateRuntime:
	var runtime := TestRuntime.new()
	root.add_child(runtime)
	runtime._resource_rng.seed = 418
	runtime._visual_rng.seed = 418
	runtime._regrowth_rng.seed = 418
	runtime.map_data = WFCMapData.new()
	runtime.map_data.map_size = Vector2i(40, 40)
	for y in range(40):
		for x in range(40):
			runtime.map_data.occupied_cells.append(Vector2i(x, y))
	runtime.height_field = runtime.map_data.create_height_field()
	var wet := WFCMoistureMap.new()
	wet.resolution = 40
	wet.map_size = runtime.map_data.map_size
	wet.occupied_cells.assign(runtime.map_data.occupied_cells)
	wet.values.resize(1600)
	for y in range(40):
		for x in range(40): wet.values[y * 40 + x] = 51 if x < 20 else 204
	runtime.map_data.moisture = wet
	return runtime

func _entry(distribution: int) -> MapResourceEntry:
	var entry := MapResourceEntry.new()
	entry.scene = load("res://Scene/resource/tree.tscn") if distribution == 0 else load("res://Scene/resource/stone.tscn")
	entry.distribution = distribution
	entry.count = 20
	entry.spacing_version = 1
	entry.minimum_spacing = 0.1
	entry.neighbor_distance_max = 0.8
	entry.far_distance_min = 10.0
	entry.moisture_min = 0.5
	entry.moisture_max = 0.9
	entry.regrowth_mode = 0
	entry.regrowth_wait_min = 0.0
	entry.regrowth_wait_max = 0.0
	return entry

func _run() -> void:
	var entry := _entry(0)
	_expect(entry.accepts_moisture(0.5) and entry.accepts_moisture(0.9) and not entry.accepts_moisture(0.49) and not entry.accepts_moisture(0.91), "湿润度上下限包含边界，范围外严格拒绝")
	entry.moisture_min = 0.95
	_expect(not entry.validation_error().is_empty(), "反向范围无法保存")
	entry.moisture_min = 0.5
	var path := "res://.godot/map_resource_moisture_test.tres"
	_expect(ResourceSaver.save(entry, path) == OK, "湿润度资源配置保存")
	var reloaded: MapResourceEntry = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	_expect(reloaded.moisture_min == 0.5 and reloaded.moisture_max == 0.9, "范围保存后可重新读取")
	for distribution in [0, 1]:
		var runtime := _make_runtime()
		var settings := _entry(distribution)
		settings.regrowth_mode = distribution
		runtime.resource_entries.append(settings)
		runtime._spawn_resources()
		var resources := runtime.get_node("GeneratedResources")
		_expect(resources.get_child_count() > 0, "分布模式 %d 在适宜区域生成资源" % distribution)
		var all_suitable := true
		for resource in resources.get_children():
			all_suitable = all_suitable and settings.accepts_moisture(runtime.sample_moisture_world(resource.global_position))
		_expect(all_suitable, "每个实际落点满足范围（含簇内扩散和随机偏移）")
		var original: ResourceBase = resources.get_child(0)
		original.gather(original.resource_amount)
		await process_frame
		runtime.set_process(false)
		var count := resources.get_child_count()
		runtime.map_data.moisture.values.fill(51)
		runtime._process(0.1)
		runtime.set_process(false)
		_expect(resources.get_child_count() == count and runtime._pending_regrowth.size() == 1, "地面变干阻止再生，保留待重试记录")
		runtime.map_data.moisture.values.fill(204)
		runtime._process(5.1)
		runtime.set_process(false)
		_expect(resources.get_child_count() == count + 1 and runtime._pending_regrowth.is_empty(), "湿润度恢复后自动重试并再生")
		runtime.queue_free()
		await process_frame
	var legacy := MapResourceEntry.new()
	_expect(legacy.accepts_moisture(-1.0), "默认 0～1 兼容没有湿润数据的旧地图")
	_expect(not entry.accepts_moisture(-1.0), "限定范围时无数据不强行生成")
	entry.moisture_outside_probability = 0.1
	_expect(entry.moisture_spawn_probability(0.45) > entry.moisture_spawn_probability(0.1) and entry.moisture_spawn_probability(0.45) <= 0.1, "范围外概率随湿润度差距降低")
	_expect(entry.moisture_spawn_probability(0.0) == 0.0 and entry.moisture_spawn_probability(-1.0) == 0.0, "差距达到 0.5 或没有数据时不生成")
	_expect(ResourceSaver.save(entry, path) == OK, "范围外概率保存")
	reloaded = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	_expect(reloaded.moisture_outside_probability == 0.1, "范围外概率重新读取")
	for distribution in [0, 1]:
		var runtime := _make_runtime()
		# 全图湿润度 0.4，在 0.5～0.9 范围外，可验证实际生成路径。
		runtime.map_data.moisture.values.fill(102)
		var settings := _entry(distribution)
		settings.moisture_outside_probability = 0.5
		settings.regrowth_mode = distribution
		runtime.resource_entries.append(settings)
		runtime._spawn_resources()
		var resources := runtime.get_node("GeneratedResources")
		_expect(resources.get_child_count() > 0 and resources.get_child_count() <= settings.count, "树林／石群可以少量生成到范围外，总数不增加")
		var original: ResourceBase = resources.get_child(0)
		original.gather(original.resource_amount)
		await process_frame
		runtime.set_process(false)
		var count := resources.get_child_count()
		for attempt in range(80):
			runtime._process(5.1)
			runtime.set_process(false)
			if runtime._pending_regrowth.is_empty(): break
		_expect(resources.get_child_count() == count + 1 and runtime._pending_regrowth.is_empty(), "原地／簇内再生也使用范围外概率并可以重试")
		runtime.queue_free()
		await process_frame
	quit(1 if failed else 0)
