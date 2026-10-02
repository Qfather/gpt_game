extends SceneTree
func _init() -> void:
	call_deferred("_run")
func _run() -> void:
	var main: Node3D = load("res://Scene/main.tscn").instantiate()
	main.level_preset = main.level_preset.duplicate(true)
	main.level_preset.layout_seed = 418
	main.level_preset.events.clear()
	main.level_preset.camp_config.enabled = false
	var config: LevelConfig = main.level_preset.settlement_config
	config.initial_wood = 321
	config.initial_stone = 123
	config.initial_grain = 456
	config.initial_villagers = 4
	config.immigration_rules.arrival_interval = 120
	root.add_child(main)
	current_scene = main
	for index in range(20):
		await physics_frame
		await process_frame
	var manager: Node = get_first_node_in_group("resource_manager")
	assert(manager.get_total(&"wood") == 321)
	assert(manager.get_total(&"stone") == 123)
	assert(manager.get_total(&"grain") == 456)
	assert(get_nodes_in_group("villagers").size() == 4)
	var population: PopulationManager = get_first_node_in_group("population_manager")
	assert(population.level_config == config and main.level_config == config)
	assert(population._get_immigration_rules().arrival_interval == 120)
	assert(population.get_population() == 4 and population.get_housing_capacity() == 5)
	main.queue_free()
	await process_frame
	print("关卡统一初始配置运行测试通过：三种资源、四名居民、移民规则与住房容量")
	quit()
