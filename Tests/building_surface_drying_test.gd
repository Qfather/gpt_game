extends SceneTree

var failed := false
func _initialize() -> void:
	call_deferred("_run")

func _expect(condition: bool, message: String) -> void:
	print("[", "通过" if condition else "失败", "] ", message)
	if not condition:
		failed = true
		push_error(message)

func _capture(path: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)

func _run() -> void:
	var main: Node3D = load("res://Scene/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	var generator: MapGenerateRuntime = main.get_node("Systems/MapGenerateRuntime")
	for i in range(150):
		await process_frame
		if generator.has_node("BuildingSurfaceDrying"):
			break
	_expect(generator.has_node("BuildingSurfaceDrying"), "游戏地图已接入干燥适配器")
	var adapter: Node = generator.get_node("BuildingSurfaceDrying")
	var demo: Node = generator.get_node("GeneratedTerrain")
	var runtime = demo._surface_runtime
	_expect(generator.map_data.surface.enabled and runtime.applied_surface_count > 0, "游戏地形实际应用湿润度地表材质")
	var source_texture: Texture2D = generator.map_data.surface.layers[0].texture
	if source_texture != null:
		_expect(runtime.material.get_shader_parameter("texture_0") == source_texture, "草贴图实际绑定到游戏地表材质")
	var base: BuildingBase = get_first_node_in_group("bases")
	var natural: WFCMoistureMap = runtime.natural_moisture
	var local := generator.to_local(base.global_position)
	var position := Vector2(local.x, local.z) + Vector2(generator.map_data.map_size) * generator.map_data.cell_size_m * 0.5
	_expect(generator.sample_moisture_world(base.global_position) < natural.sample_map(position) - 0.2, "已建成据点降低实际湿润度")
	var before := generator.map_data.moisture.values.duplicate()
	var natural_before := natural.values.duplicate()
	var camera := Camera3D.new()
	main.add_child(camera)
	camera.global_position = base.global_position + Vector3(0, 16, 5)
	camera.look_at(base.global_position)
	camera.make_current()
	await _capture("res://.godot/building_drying_surface.png")
	runtime.material.set_shader_parameter("preview_channel", 4)
	await _capture("res://.godot/building_drying_moisture.png")
	runtime.material.set_shader_parameter("preview_channel", -1)
	base.building_data = base.building_data.duplicate(true)
	base.building_data.surface_drying_enabled = false
	adapter.refresh()
	_expect(generator.map_data.moisture.values == natural_before, "关闭建筑影响精确恢复自然湿润度")
	await _capture("res://.godot/building_drying_before.png")
	base.building_data.surface_drying_enabled = true
	adapter.refresh()
	_expect(generator.map_data.moisture.values == before, "恢复影响结果稳定")
	# 使用实际占地与变换，验证待建建筑、登记建成、搬迁和退出。
	var building := BuildingBase.new()
	building.building_data = BuildingData.new()
	building.building_data.surface_drying_strength = 0.7
	main.add_child(building)
	building.global_position = base.global_position
	building.set_build_grid_occupancy(base.build_grid_position + Vector2i(1, 0), Vector2i(2, 2), 0)
	adapter.refresh()
	var placed := generator.map_data.moisture.values.duplicate()
	_expect(placed != before, "新建建筑增加局部干燥区域")
	building.set_build_grid_occupancy(base.build_grid_position + Vector2i(-1, 0), Vector2i(2, 2), 1)
	adapter.refresh()
	_expect(generator.map_data.moisture.values != placed, "搬迁及旋转登记后更新区域")
	building.queue_free()
	adapter.refresh()
	_expect(generator.map_data.moisture.values == before, "拆除建筑恢复旧区域并保留其他建筑影响")
	var site := ConstructionSite.new()
	site.building_data = BuildingData.new()
	main.add_child(site)
	site.set_build_grid_occupancy(base.build_grid_position + Vector2i(4, 0), Vector2i(2, 2), 0)
	adapter.refresh()
	_expect(generator.map_data.moisture.values == before, "施工中的建筑不施加干燥")
	_expect(natural.values == natural_before, "建筑影响不改写自然底图")
	main.queue_free()
	await process_frame
	print("建筑干燥游戏接入测试", "失败" if failed else "通过")
	quit(1 if failed else 0)
