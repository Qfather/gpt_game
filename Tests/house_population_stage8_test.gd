extends SceneTree

var _failed: bool = false


class FoodSource extends Node:
	var grain_amount: float = 50.0

	func get_total(resource_id: StringName) -> float:
		if resource_id == &"grain":
			return grain_amount
		return 0.0


class HousingSource extends Node:
	var capacity: int = 8

	func get_housing_capacity() -> int:
		return capacity


func _initialize() -> void:
	var test_root: Node = Node.new()
	get_root().add_child(test_root)

	var food_source: FoodSource = FoodSource.new()
	food_source.add_to_group("resource_manager")
	test_root.add_child(food_source)

	var housing_source: HousingSource = HousingSource.new()
	housing_source.add_to_group("bases")
	test_root.add_child(housing_source)

	var villagers: Array[Node] = []
	for _index: int in range(5):
		var villager: Node = Node.new()
		villager.add_to_group("villagers")
		test_root.add_child(villager)
		villagers.append(villager)

	var manager: PopulationManager = PopulationManager.new()
	var rules: ImmigrationRules = ImmigrationRules.new()
	rules.minimum_food_reserve = 30.0
	rules.food_per_migrant = 10.0
	rules.required_free_housing = 1
	rules.arrival_interval = 3.0
	rules.min_group_size = 1
	rules.max_group_size = 2
	manager.level_config = LevelConfig.new()
	manager.level_config.immigration_rules = rules
	test_root.add_child(manager)
	await process_frame

	manager._process(0.1)
	_expect(
		manager.is_immigration_countdown_active(),
		"满足条件时可以开始新一批移民倒计时"
	)
	_expect(
		int(manager.get_immigration_status()["required_housing"]) == 2,
		"本批预计来两人时需要两个空房"
	)

	food_source.grain_amount = 0.0
	manager._process(0.1)
	_expect(
		not manager.is_immigration_countdown_active(),
		"在移民出发前粮食不足会取消倒计时"
	)

	manager.pending_migrant_count = 2
	manager._immigration_ready_emitted = true
	manager._process(0.1)
	_expect(
		manager.pending_migrant_count == 2,
		"粮食不足时已经出发的移民仍保留在途状态"
	)
	_expect(
		manager._immigration_ready_emitted,
		"在途移民存在时不会清除本批次状态"
	)

	manager.pending_migrant_count = 0
	manager._immigration_ready_emitted = false
	food_source.grain_amount = 50.0
	manager._process(0.1)
	_expect(
		manager.is_immigration_countdown_active(),
		"上一批移民结束后条件满足即可开始下一批"
	)

	for _index: int in range(4):
		var villager: Node = Node.new()
		villager.add_to_group("villagers")
		test_root.add_child(villager)

	manager._process(0.1)
	_expect(
		manager.get_free_housing() < rules.required_free_housing,
		"正式人口超过住房容量时没有可用空房"
	)
	_expect(
		not manager.can_start_immigration(),
		"人口超过住房容量时阻止新一批移民"
	)

	manager.free()
	food_source.free()
	housing_source.free()
	for villager: Node in villagers:
		villager.free()
	test_root.free()
	if _failed:
		printerr("House / Population V1 阶段 8 测试失败")
		quit(1)
		return

	print("House / Population V1 阶段 8 测试通过")
	quit()


func _expect(condition: bool, description: String) -> void:
	if condition:
		print("[通过] ", description)
		return

	_failed = true
	printerr("[失败] ", description)
