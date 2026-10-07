extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var main: Node = load("res://Scene/main.tscn").instantiate()
	main.level_preset = main.level_preset.duplicate(true)
	main.level_preset.layout_seed = 418
	main.level_preset.events.clear()
	main.level_preset.camp_config.enabled = false
	main.level_preset.fog_of_war_enabled = false
	root.add_child(main)
	current_scene = main
	for frame in range(60): await physics_frame
	var manager: Node = main.get_node("Systems/WildlifeManager")
	var expected: Dictionary = {}
	for data: Resource in manager.config.prey_pool: expected[data.id] = data.meat_yield
	print("当前游戏关卡猎物产肉配置：", expected)
	manager.refill()
	assert(not get_nodes_in_group("wildlife").is_empty(), "真实关卡生成了猎物")
	for animal: Node in get_nodes_in_group("wildlife"):
		assert(animal.data.meat_yield == expected[animal.data.id])
		print("游戏中猎物：", animal.data.id, " 产肉=", animal.data.meat_yield)
	manager.set_process(false)
	for unit: Node in get_nodes_in_group("villagers"): unit.set_physics_process(false)
	var house: Node3D = load("res://Scene/building/game/hunter_hut.tscn").instantiate()
	main.add_child(house)
	house.set_process(false)
	var hunter: Node3D = load("res://Scene/unit/villager.tscn").instantiate()
	main.add_child(hunter)
	hunter.set_physics_process(false)
	await process_frame
	hunter.assign_job(hunter.Job.HUNTER, house)
	var base: Node3D = get_first_node_in_group("bases")
	var point: Vector3 = NavigationServer3D.map_get_closest_point(hunter.navigation_agent.get_navigation_map(), base.global_position + Vector3(4, 0, 3))
	hunter.global_position = point - Vector3.UP * hunter.navigation_agent.path_height_offset
	var total_meat: float = 0
	for data: Resource in manager.config.prey_pool:
		var animal: Node3D = data.scene.instantiate()
		animal.data = data
		main.add_child(animal)
		animal.global_position = point
		animal.claim(hunter)
		animal.health = 0
		hunter.hunting.target = animal
		hunter.hunting.process(hunter, 0.016)
		total_meat += data.meat_yield
	assert(hunter.hunting.prey_count == 3 and hunter.hunting.raw_meat == total_meat)
	var panel: VillagerPanel = main.get_node("UI/VillagerPanel")
	panel.open_unit(hunter)
	panel.refresh()
	assert(panel.carry_label.text == "携带猎物：3 / 3只\n处理后产肉：%.0f" % total_meat)
	print("关卡实际收尸后的肉量与携带栏两行显示通过：3只猎物，产肉=", total_meat)
	if DisplayServer.get_name() != "headless":
		await create_timer(0.35).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/wildlife_level_yield_preview.png")
	main.queue_free()
	await process_frame
	quit()
