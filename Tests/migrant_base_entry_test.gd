extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var main: Node = load("res://Scene/main.tscn").instantiate()
	main.level_preset = main.level_preset.duplicate(true)
	main.level_preset.events.clear()
	main.get_node("Systems/MapGenerateRuntime").settlement_seed = 42
	root.add_child(main)
	current_scene = main
	for frame: int in range(10): await process_frame
	var base: Node3D = get_first_node_in_group("bases")
	var manager: PopulationManager = get_first_node_in_group("population_manager")
	manager.set_process(false)
	for resident: Node in get_nodes_in_group("villagers"):
		resident.set_physics_process(false)
	var camera: GameCameraController = main.get_node("Systems/Camera3D")
	camera.orbit_yaw = 0
	camera.orbit_distance = 9.0
	camera.focus_on_position(base.global_position)
	for speed: float in [1.0, 3.0, 10.0]:
		Engine.time_scale = speed
		manager.refresh_population()
		var initial_population: int = manager.current_population
		var migrant: Migrant = load("res://Scene/unit/migrant.tscn").instantiate()
		main.get_node("Migrants").add_child(migrant)
		migrant.character_name = "门口测试移民"
		var entrance: Vector3 = base.get_migrant_entrance_position()
		migrant.global_position = NavigationServer3D.map_get_closest_point(root.world_3d.navigation_map, entrance + Vector3(0, 0, 5))
		manager.pending_migrant_count = 1
		var joined: Array[bool] = [false]
		migrant.arrived.connect(func(unit: Node3D, destination: Node3D) -> void:
			assert(unit.global_position.is_equal_approx(base.get_migrant_interior_position()))
			assert(manager.current_population == initial_population)
			joined[0] = true
			manager._on_migrant_arrived(unit, destination)
		)
		migrant.setup(base)
		var entry_image_saved: bool = false
		var saw_entry: bool = false
		for frame: int in range(900):
			await physics_frame
			if joined[0]: break
			assert(manager.current_population == initial_population)
			assert(manager.pending_migrant_count == 1)
			if migrant._entering_base:
				saw_entry = true
				if speed == 1.0 and not entry_image_saved and DisplayServer.get_name() != "headless" and base.to_local(migrant.global_position).z < 1.8:
					await RenderingServer.frame_post_draw
					root.get_texture().get_image().save_png("res://.godot/migrant-entering-base.png")
					entry_image_saved = true
			assert(not migrant._arrival_notified)
		assert(joined[0] and saw_entry, "移民必须先走进正门再加入")
		assert(manager.pending_migrant_count == 0)
		assert(manager.current_population == initial_population + 1)
		var newcomer: UnitBase
		for resident: Node in get_nodes_in_group("villagers"):
			if resident.character_name == "门口测试移民": newcomer = resident
		assert(newcomer != null and newcomer.leaving_immigration_base)
		assert(not newcomer.is_idle(), "出门前不能派去施工或工作")
		var saw_exit: bool = false
		for frame: int in range(180):
			await physics_frame
			if not newcomer.leaving_immigration_base: break
			saw_exit = true
			assert(not newcomer.is_idle())
		assert(saw_exit and not newcomer.leaving_immigration_base)
		assert(newcomer.global_position.distance_to(entrance) < 0.4)
		assert(newcomer.collision_layer == 2 and newcomer.collision_mask == 3)
		assert(newcomer.is_idle())
		print("移民进门转换并走出：倍速=", speed, " 人口=", manager.current_population, " 门外居民位置=", newcomer.global_position)
		if speed == 1.0 and DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://.godot/migrant-base-exit.png")
		newcomer.queue_free()
		await process_frame
	Engine.time_scale = 1.0
	main.queue_free()
	await process_frame
	print("移民进入据点后转换、居民出门、正式人口时机、出门前任务禁用与碰撞恢复验证通过")
	quit()
