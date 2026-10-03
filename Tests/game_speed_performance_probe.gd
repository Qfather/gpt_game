extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _sample(label: String) -> void:
	for i in range(20): await process_frame
	var samples: Array[float] = []
	var previous: int = Time.get_ticks_usec()
	var start: int = previous
	for i in range(180):
		await process_frame
		var now: int = Time.get_ticks_usec()
		samples.append(float(now - previous) / 1000.0)
		previous = now
	var fps: float = 180000000.0 / float(previous - start)
	samples.sort()
	print("性能采样 ", label, " FPS=%.1f P50=%.2fms P95=%.2fms 最大=%.2fms" % [fps, samples[90], samples[171], samples.back()])

func _run() -> void:
	var main: Node3D = load("res://Scene/main.tscn").instantiate()
	main.level_preset = main.level_preset.duplicate(true)
	main.level_preset.layout_seed = 418
	main.level_preset.events.clear()
	main.level_preset.camp_config.enabled = false
	root.add_child(main)
	current_scene = main
	for i in range(30): await physics_frame
	var base: Node3D = get_first_node_in_group("bases")
	for i in range(13 - get_nodes_in_group("villagers").size()):
		var unit: Node3D = load("res://Scene/unit/villager.tscn").instantiate()
		main.add_child(unit)
		unit.global_position = base.global_position + Vector3((i % 4) * 1.5 - 3, 0, (i / 4) * 1.5 + 3)
	main.get_node("Systems/PopulationManager").set_process(false)
	var fog: Node = get_first_node_in_group("fog_of_war")
	print("性能场景：固定种子418，人口=", get_nodes_in_group("villagers").size(), " 资源=", get_nodes_in_group("resources").size(), " 敌人=", get_nodes_in_group("enemies").size(), " 渲染器=", DisplayServer.get_name())
	Engine.time_scale = 1.0
	await _sample("1倍速")
	Engine.time_scale = 3.0
	await _sample("3倍速")
	var start: int = Time.get_ticks_usec()
	for i in range(5): fog.refresh_visibility()
	print("迷雾单次刷新平均=%.2fms" % (float(Time.get_ticks_usec() - start) / 5000.0))
	fog.set_process(false)
	await _sample("3倍速仅停用迷雾刷新以定位开销")
	Engine.time_scale = 1.0
	main.queue_free()
	await process_frame
	quit()
