extends SceneTree

var _failed: bool = false


class FoodSource extends Node:
	var grain_amount: float = 0.0

	func get_total(resource_id: StringName) -> float:
		if resource_id == &"grain":
			return grain_amount
		return 0.0


func _initialize() -> void:
	var test_root: Node = Node.new()
	get_root().add_child(test_root)

	var food_source: FoodSource = FoodSource.new()
	food_source.add_to_group("resource_manager")
	test_root.add_child(food_source)

	var manager: PopulationManager = PopulationManager.new()
	var rules: ImmigrationRules = ImmigrationRules.new()
	rules.minimum_food_reserve = 30.0
	rules.food_per_migrant = 10.0
	rules.required_free_housing = 1
	rules.min_group_size = 1
	rules.max_group_size = 2
	manager.level_config = LevelConfig.new()
	manager.level_config.immigration_rules = rules
	test_root.add_child(manager)
	await process_frame
	manager.current_population = 5
	manager.housing_capacity = 5

	_expect(
		manager.get_free_housing() == 0,
		"没有空房时住房容量为零"
	)
	_expect(
		not manager.can_start_immigration(),
		"没有空房时不能开始移民"
	)

	manager.housing_capacity = 8
	_expect(
		manager.get_free_housing() == 3,
		"增加住房后可以计算空余容量"
	)

	_expect(
		manager.get_immigration_group_size() == 0,
		"只有住房但没有粮食时预计移民人数为零"
	)
	food_source.grain_amount = 50.0
	_expect(
		manager.get_immigration_group_size() == 2,
		"规则允许的最大移民人数为二"
	)
	_expect(
		manager.can_start_immigration(),
		"住房和粮食条件满足时可以开始移民"
	)

	manager.free()
	food_source.free()
	test_root.free()
	if _failed:
		printerr("House / Population V1 阶段 3 测试失败")
		quit(1)
		return

	print("House / Population V1 阶段 3 测试通过")
	quit()


func _expect(condition: bool, description: String) -> void:
	if condition:
		print("[通过] ", description)
		return

	_failed = true
	printerr("[失败] ", description)
