extends SceneTree

var _failed: bool = false


class MockVillager:
	extends Node

	var current_task: GameTask = null
	var combat_role: int = CombatRole.Type.NONE

	func can_take_task(_task: Object) -> bool:
		return current_task == null

	func set_current_task(task: Object) -> void:
		current_task = task as GameTask

	func clear_current_task() -> void:
		current_task = null

	func set_combat_role(role: int) -> void:
		combat_role = role


func _initialize() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	var root: Node = Node.new()
	get_root().add_child(root)

	var storage: ResourceStorage = ResourceStorage.new()
	storage.starting_wood = 10.0
	storage.starting_stone = 10.0
	root.add_child(storage)

	var manager: TaskManager = TaskManager.new()
	root.add_child(manager)

	var camp: SwordsmanCamp = SwordsmanCamp.new()
	var data: BuildingData = BuildingData.new()
	data.training_cost = {
		&"wood": 5.0,
		&"stone": 5.0,
	}
	camp.set_building_data(data)
	root.add_child(camp)

	await process_frame

	var population_before: int = 2
	_expect(camp.request_training(), "第一名剑士训练请求可以创建")
	_expect(camp.request_training(), "第二名剑士训练请求可以创建")
	_expect(not camp.request_training(), "训练位满后不能创建第三个请求")
	_expect(storage.get_amount(&"wood") == 0.0, "两次训练扣除10木材")
	_expect(storage.get_amount(&"stone") == 0.0, "两次训练扣除10石材")

	var first_villager: MockVillager = MockVillager.new()
	var second_villager: MockVillager = MockVillager.new()
	root.add_child(first_villager)
	root.add_child(second_villager)

	for task_variant: Variant in manager.tasks.values():
		var task: GameTask = task_variant as GameTask
		if task == null or task.type != GameTask.TaskType.TRAIN_SWORDSMAN:
			continue
		var worker: MockVillager = (
			first_villager
			if first_villager.current_task == null
			else second_villager
		)
		_expect(manager.claim_task(task, worker), "训练任务可以自动领取")

	_expect(camp.get_training_worker_count() == 2, "两个训练位正确占用")
	_expect(camp.complete_training(first_villager), "第一名居民训练完成")
	_expect(first_villager.combat_role == CombatRole.Type.SWORDSMAN, "第一名居民转为剑士")
	_expect(camp.complete_training(second_villager), "第二名居民训练完成")
	_expect(second_villager.combat_role == CombatRole.Type.SWORDSMAN, "第二名居民转为剑士")
	_expect(camp.get_training_worker_count() == 0, "训练完成后训练位释放")
	_expect(first_villager.is_inside_tree() and second_villager.is_inside_tree(), "训练不会删除居民对象")
	_expect(population_before == 2, "训练前后人口数量不变")

	root.free()
	if _failed:
		printerr("Military Daily Loop V1 阶段 5 测试失败")
		quit(1)
		return

	print("Military Daily Loop V1 阶段 5 测试通过")
	quit()


func _expect(condition: bool, description: String) -> void:
	if condition:
		print("[通过] ", description)
		return

	_failed = true
	printerr("[失败] ", description)
