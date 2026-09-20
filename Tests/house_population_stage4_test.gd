extends SceneTree

var _failed: bool = false
var _ready_count: int = 0
var _ready_group_size: int = 0


class FoodSource extends Node:
	var grain_amount: float = 50.0

	func get_total(resource_id: StringName) -> float:
		if resource_id == &"grain":
			return grain_amount
		return 0.0


class HousingSource extends Node:
	func get_housing_capacity() -> int:
		return 8


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
	manager.immigration_ready.connect(_on_immigration_ready)

	manager._process(0.1)
	_expect(
		manager.is_immigration_countdown_active(),
		"住房和粮食满足时开始移民倒计时"
	)
	_expect(
		manager.get_immigration_countdown_remaining() > 0.0,
		"移民倒计时有剩余时间"
	)

	food_source.grain_amount = 0.0
	manager._process(0.1)
	_expect(
		not manager.is_immigration_countdown_active(),
		"粮食不足时取消移民倒计时"
	)
	_expect(_ready_count == 0, "倒计时取消时不会触发移民准备信号")

	food_source.grain_amount = 50.0
	manager._process(0.1)
	manager._process(3.0)
	_expect(_ready_count == 1, "倒计时完成只触发一次移民准备信号")
	_expect(_ready_group_size == 2, "移民准备信号携带预计人数")
	manager._process(3.0)
	_expect(_ready_count == 1, "条件不变时不会每帧重复触发")

	food_source.grain_amount = 0.0
	manager._process(0.1)
	food_source.grain_amount = 50.0
	manager._process(0.1)
	_expect(
		manager.is_immigration_countdown_active(),
		"条件恢复后可以重新开始倒计时"
	)

	manager.free()
	food_source.free()
	housing_source.free()
	for villager: Node in villagers:
		villager.free()
	test_root.free()
	if _failed:
		printerr("House / Population V1 阶段 4 测试失败")
		quit(1)
		return

	print("House / Population V1 阶段 4 测试通过")
	quit()


func _on_immigration_ready(group_size: int) -> void:
	_ready_count += 1
	_ready_group_size = group_size


func _expect(condition: bool, description: String) -> void:
	if condition:
		print("[通过] ", description)
		return

	_failed = true
	printerr("[失败] ", description)
