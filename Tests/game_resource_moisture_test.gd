extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var main: Node3D = load("res://Scene/main.tscn").instantiate()
	main.level_preset = main.level_preset.duplicate(true)
	main.level_preset.layout_seed = 418
	main.level_preset.settlement_config.initial_villagers = 0
	main.level_preset.events.clear()
	root.add_child(main)
	current_scene = main
	var runtime: MapGenerateRuntime = main.get_node("Systems/MapGenerateRuntime")
	for frame in range(180):
		await process_frame
		if runtime.has_node("BuildingSurfaceDrying"): break
	assert(runtime.has_node("BuildingSurfaceDrying"))
	var entry: MapResourceEntry = main.level_preset.map_resources[0]
	assert(entry.moisture_min == 0.5 and entry.moisture_max == 1.0)
	var mask: Image = runtime.get_node("GeneratedTerrain")._surface_runtime.texture.get_image()
	var tree_count := 0
	var outside_range := 0
	var mud_dominant := 0
	var half_size := Vector2(runtime.map_data.map_size) * runtime.map_data.cell_size_m * 0.5
	for resource in runtime.get_node("GeneratedResources").get_children():
		if not resource is ResourceBase or resource.resource_id != &"wood": continue
		tree_count += 1
		if not entry.accepts_moisture(runtime.sample_moisture_world(resource.global_position)): outside_range += 1
		var local := runtime.to_local(resource.global_position)
		var uv := (Vector2(local.x, local.z) + half_size) / (half_size * 2.0)
		var pixel := Vector2i(clampi(int(uv.x * mask.get_width()), 0, mask.get_width() - 1), clampi(int(uv.y * mask.get_height()), 0, mask.get_height() - 1))
		if mask.get_pixelv(pixel).r > 0.5: mud_dominant += 1
	print("真实游戏树木检查：数量=", tree_count, " 湿润度范围外=", outside_range, " 泥土主导落点=", mud_dominant)
	assert(tree_count > 0 and outside_range == 0)
	quit()
