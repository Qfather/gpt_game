extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var main = load("res://Scene/main.tscn").instantiate()
	main.level_preset = main.level_preset.duplicate(true)
	main.level_preset.layout_seed = 418
	main.level_preset.events.clear()
	main.level_preset.camp_config.first_spawn_time = 86400
	main.level_preset.camp_config.camp_pool[0].camp.minimum_guards = 2
	main.level_preset.camp_config.camp_pool[0].camp.maximum_guards = 2
	root.add_child(main)
	current_scene = main
	for i in range(20):
		await physics_frame
		await process_frame
	for unit in get_nodes_in_group("villagers"): unit.set_physics_process(false)
	var manager = get_first_node_in_group("camp_spawn_manager")
	manager.set_process(false)
	manager.rng.seed = 1234
	var camp: TreasureCamp = manager.try_spawn(0.0)
	assert(camp != null)
	var fog = get_first_node_in_group("fog_of_war")
	fog.set_process(false)
	fog.refresh_visibility()
	assert(not fog.is_visible_at(camp.global_position))
	for guard in camp.guards: guard.set_physics_process(false)
	assert(camp.guards.size() == 2)
	camp.guards[0].take_damage(100000.0)
	camp._process(0.0)
	fog.refresh_visibility()
	assert(not camp.cleared and not fog.is_visible_at(camp.global_position))
	camp.guards[1].take_damage(100000.0)
	camp._process(0.0)
	fog.refresh_visibility()
	assert(camp.cleared and fog.is_visible_at(camp.global_position))
	assert(camp.get_node("ClickArea").input_ray_pickable)
	fog.refresh_visibility()
	assert(fog.is_visible_at(camp.global_position))
	var position: Vector3 = camp.global_position
	camp.queue_free()
	fog.refresh_visibility()
	assert(not fog.is_visible_at(position))
	assert(fog.explored.get_pixelv(fog._pixel(position)).r > 0.0)
	print("营地视野测试通过：存活守卫不授予视野，全灭后持续可见可点击，营地删除后保留探索记录")
	main.queue_free()
	await process_frame
	quit()
