extends SceneTree

class MockConstructionSite:
	extends Node

	var delivery_priority: int
	var reserved_amount: float = 0.0

	func _init(priority_value: int) -> void:
		delivery_priority = priority_value

	func get_delivery_priority() -> int:
		return delivery_priority

	func get_max_construction_workers() -> int:
		return 1

	func get_construction_worker_limit() -> int:
		return 1

	func get_delivery_resource_type() -> int:
		return ResourceType.Type.WOOD

	func get_next_needed_resource() -> int:
		return ResourceType.Type.WOOD

	func get_still_needed(_resource_type: Variant) -> float:
		return 5.0 - reserved_amount

	func reserve_resource(_resource_type: Variant, amount: float) -> float:
		var accepted_amount: float = minf(amount, get_still_needed(ResourceType.Type.WOOD))
		reserved_amount += accepted_amount
		return accepted_amount

	func fill_waiting_workers() -> void:
		pass


class MockVillager:
	extends Node

	var current_task: GameTask

	func can_take_task(_task: Object) -> bool:
		return current_task == null

	func set_current_task(task: Object) -> void:
		current_task = task as GameTask


var _failed: bool = false


func _initialize() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	var storage: ResourceStorage = ResourceStorage.new()
	storage.starting_wood = 20.0
	root.add_child(storage)

	var manager: TaskManager = TaskManager.new()
	root.add_child(manager)

	var first_site: MockConstructionSite = MockConstructionSite.new(0)
	var second_site: MockConstructionSite = MockConstructionSite.new(1)
	root.add_child(first_site)
	root.add_child(second_site)

	manager.create_construction_delivery_tasks(first_site)
	manager.create_construction_delivery_tasks(second_site)

	_expect(_count_tasks_for_target(manager, first_site) == 1, "较早工地生成运输任务")
	_expect(_count_tasks_for_target(manager, second_site) == 1, "后续工地不会被顺序全局锁阻止")

	var villager: MockVillager = MockVillager.new()
	root.add_child(villager)
	villager.add_to_group("villagers")
	manager._dispatch_available_tasks()

	_expect(villager.current_task != null, "空闲居民可以领取运输任务")
	if villager.current_task != null:
		_expect(villager.current_task.target == first_site, "同时可执行时较早工地仍然优先")

	if _failed:
		printerr("多工地任务优先级测试失败")
		quit(1)
		return

	print("多工地任务优先级测试通过")
	quit()


func _count_tasks_for_target(manager: TaskManager, target: Node) -> int:
	var count: int = 0
	for task_variant: Variant in manager.tasks.values():
		var task: GameTask = task_variant as GameTask
		if task != null and task.target == target:
			count += 1
	return count


func _expect(condition: bool, description: String) -> void:
	if condition:
		print("[通过] ", description)
		return

	_failed = true
	printerr("[失败] ", description)
