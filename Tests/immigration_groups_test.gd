extends SceneTree
func _init() -> void:
	call_deferred("_run")
func _run() -> void:
	var main: Node3D = load("res://Scene/main.tscn").instantiate()
	main.level_preset = main.level_preset.duplicate(true)
	main.level_preset.layout_seed = 418
	main.level_preset.events.clear()
	main.level_preset.camp_config.enabled = false
	root.add_child(main)
	current_scene = main
	for index in range(20):
		await physics_frame
		await process_frame
	var manager: PopulationManager = get_first_node_in_group("population_manager")
	manager.set_process(false)
	var rules: ImmigrationRules = manager.level_config.immigration_rules
	assert(rules.groups.size() == 7 and rules.validation_error().is_empty())
	var base: Node3D = get_first_node_in_group("bases")
	var storage: ResourceStorage = base.get_node("ResourceStorage")
	var meat_group: ImmigrationGroup = rules.groups[3]
	for index in range(3):
		main.add_child(load("res://Scene/unit/villager.tscn").instantiate())
	manager.refresh_population()
	manager.current_immigration_group = meat_group
	assert(not manager.can_start_immigration())
	storage.set_capacity(&"meat", 100)
	storage.add(&"meat", 25)
	assert(not manager.can_start_immigration()) # 有肉，但缺住宅。
	var house: House = load("res://Scene/building/game/house.tscn").instantiate()
	house.building_data = load("res://data/buildings/HouseData.tres")
	main.add_child(house)
	house.global_position = base.global_position + Vector3(5,0,5)
	manager.refresh_population()
	assert(manager.can_start_immigration())
	house.demolition_state = BuildingBase.DemolitionState.WAITING_FOR_WORKER
	assert(not manager.can_start_immigration())
	house.demolition_state = BuildingBase.DemolitionState.NONE
	manager._reset_immigration_countdown()
	manager._update_immigration_countdown(1)
	assert(manager.immigration_countdown_active)
	storage.take(&"meat", 25)
	manager._update_immigration_countdown(1)
	assert(not manager.immigration_countdown_active)
	storage.add(&"meat", 25)
	manager._update_immigration_countdown(1)
	main.get_node("UI/HUD" ).immigration_refresh_button.pressed.emit()
	assert(manager.current_immigration_group != meat_group and not manager.immigration_countdown_active)
	assert(manager.refresh_cooldown_remaining == 60 and not manager.refresh_immigration_requirements())
	manager.set_process(true)
	paused = true
	for frame in range(5): await process_frame
	assert(manager.refresh_cooldown_remaining == 60)
	paused = false
	manager.set_process(false)
	manager.current_immigration_group = meat_group
	storage.take(&"meat", 25)
	manager._process(59)
	assert(manager.refresh_cooldown_remaining == 1 and not manager.refresh_immigration_requirements())
	manager._process(1)
	assert(manager.refresh_cooldown_remaining == 0)
	assert(manager.current_population == 6)
	manager.current_immigration_group = meat_group
	manager._reset_immigration_countdown()
	storage.add(&"meat", 25)
	manager._update_immigration_countdown(45)
	assert(manager.pending_migrant_count == 2)
	var migrants: Array[Node] = get_nodes_in_group("migrants")
	assert(migrants.size() == 2)
	for migrant: Migrant in migrants:
		assert(migrant.resident_traits[0].get_trait_id() == "likes_meat")
		assert(migrant.global_position.distance_to(base.global_position) >= 30)
	assert(manager.refresh_immigration_requirements())
	var refreshed_group: ImmigrationGroup = manager.current_immigration_group
	assert(manager.pending_migrant_count == 2 and get_nodes_in_group("migrants").size() == 2)
	if DisplayServer.get_name() != "headless":
		main.get_node("UI/HUD")._refresh_immigration_display()
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/immigration_runtime_preview.png")
	# 加速实际导航行走，验证入住后的标签不被刷新覆盖。
	Engine.time_scale = 10
	for frame in range(2400):
		await physics_frame
		if manager.pending_migrant_count == 0: break
	Engine.time_scale = 1
	assert(manager.pending_migrant_count == 0 and get_nodes_in_group("villagers").size() == 8)
	assert(manager.current_immigration_group == refreshed_group)
	var resident: Node
	for unit: Node in get_nodes_in_group("villagers"):
		if not unit.traits.is_empty() and unit.traits.back().get_trait_id() == "likes_meat": resident = unit
	assert(resident != null)
	resident.set_process(false)
	resident.set_physics_process(false)
	assert(resident.choose_food(storage) == &"meat")
	resident.hunger = 50
	resident.target_base = base
	resident.selected_food_id = &"meat"
	resident.eating_timer = 0
	var before_meal: float = storage.get_amount(&"meat")
	resident.eat_food(5)
	assert(storage.get_amount(&"meat") == before_meal - 1)
	assert(resident.hunger == 40 and resident.preferred_food_effect_remaining == 60)
	var initial: float = resident.hunger
	resident.state = resident.State.IDLE
	resident.update_needs(10)
	assert(is_equal_approx(resident.hunger - initial, resident.hunger_rate * 10 * 0.8))
	resident.preferred_food_effect_remaining = 1
	initial = resident.hunger
	resident.update_needs(2)
	assert(is_equal_approx(resident.hunger - initial, resident.hunger_rate * 1.8))
	var plain: Node = get_nodes_in_group("villagers")[0]
	plain.hunger = 50
	plain._apply_food_nutrition(load("res://data/resources/meat.tres"))
	assert(plain.hunger == 42 and plain.preferred_food_effect_remaining == 0)
	storage.take(&"meat", 100)
	assert(resident.choose_food(storage) == &"grain")
	if DisplayServer.get_name() != "headless":
		manager.refresh_cooldown_remaining = 0
		manager.current_immigration_group = meat_group
		main.get_node("UI/HUD")._refresh_immigration_display()
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/immigration_meat_requirement_preview.png")
	# 人口下降跨档时，旧高阶需求自动回退，手动刷新冷却保持。
	for index in range(6):
		main.add_child(load("res://Scene/unit/villager.tscn").instantiate())
	manager.refresh_population()
	assert(manager.current_population == 14 and manager.current_immigration_group.unlock_population == 12)
	manager.refresh_cooldown_remaining = 37
	manager.immigration_countdown_active = true
	var units: Array[Node] = get_nodes_in_group("villagers")
	for index in range(11):
		units[index].take_damage(100000)
	manager.refresh_population()
	assert(manager.current_population == 3 and manager.current_immigration_group.unlock_population == 0)
	assert(manager.refresh_cooldown_remaining == 37 and not manager.immigration_countdown_active)
	var survivors: Array[Node] = get_nodes_in_group("villagers")
	survivors[0].set_combat_role(CombatRole.Type.ARCHER)
	var hud: GameHUD = main.get_node("UI/HUD")
	hud._refresh_population_display(3, manager.housing_capacity)
	assert(hud.resident_label.text == "居民：2" and hud.archer_label.text == "弓箭手：1")
	assert(hud.resident_label.get_index() == hud.population_label.get_index() + 1)
	if DisplayServer.get_name() != "headless":
		hud._refresh_immigration_display()
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/population_decline_preview.png")
	main.queue_free()
	await process_frame
	print("阶段移民完整测试通过：库存与建筑、条件中断、60秒刷新、当前人口、实际导航、标签保留、喜好饮食效果")
	quit()
