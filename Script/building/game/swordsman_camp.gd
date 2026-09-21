class_name SwordsmanCamp
extends BuildingBase


@export_category("训练")
@export var training_slots: int = 2
@export var training_time: float = 10.0

var training_workers: Array[Node] = []
var training_requests: int = 0


func get_training_slots() -> int:
	return training_slots


func get_training_time() -> float:
	return maxf(training_time, 0.1)


func get_training_cost() -> Dictionary[StringName, float]:
	if building_data != null and not building_data.training_cost.is_empty():
		return building_data.training_cost.duplicate()
	return {
		&"wood": 5.0,
		&"stone": 5.0
	}


func get_training_worker_count() -> int:
	return training_workers.size() + training_requests


func get_training_slot_status_text() -> String:
	var lines: PackedStringArray = []
	for slot_index: int in range(training_slots):
		if slot_index < training_workers.size():
			var worker: Node = training_workers[slot_index]
			var progress_text: String = "训练中"
			if is_instance_valid(worker) and worker.has_method("get_training_progress"):
				progress_text = "%d%%" % int(round(worker.get_training_progress() * 100.0))
			lines.append("槽位 %d：%s" % [slot_index + 1, progress_text])
		elif slot_index < get_training_worker_count():
			lines.append("槽位 %d：等待居民" % (slot_index + 1))
		else:
			lines.append("槽位 %d：空闲" % (slot_index + 1))
	return "\n".join(lines)


func can_request_training() -> bool:
	return (
		get_training_worker_count() < training_slots
		and _has_training_cost()
	)


func request_training() -> bool:
	if not can_request_training():
		return false
	if not _take_training_cost():
		return false
	var managers: Array[Node] = get_tree().get_nodes_in_group("task_manager")
	if managers.is_empty() or not managers[0].has_method("create_task"):
		_return_training_cost(get_training_cost())
		return false
	var task: GameTask = managers[0].create_task(
		GameTask.TaskType.TRAIN_SWORDSMAN,
		self,
		self,
		10
	)
	if task == null:
		_return_training_cost(get_training_cost())
		return false
	task.data["training_cost"] = get_training_cost()
	training_requests += 1
	print("剑士营创建训练任务：", task.id)
	return true


func get_training_position(worker: Node) -> Vector3:
	var worker_index: int = training_workers.find(worker)
	if worker_index < 0:
		worker_index = training_workers.size()
	var side: float = -1.0 if worker_index % 2 == 0 else 1.0
	return global_position + Vector3(side * 1.2, 0.0, 1.0)


func begin_training(worker: Node) -> bool:
	if worker == null or not training_workers.has(worker):
		return false
	worker.state = worker.State.TRAINING
	return true


func complete_training(worker: Node) -> bool:
	if worker == null or not training_workers.has(worker):
		return false
	if not worker.has_method("set_combat_role"):
		return false
	var task: GameTask = worker.get("current_task") as GameTask
	var managers: Array[Node] = get_tree().get_nodes_in_group("task_manager")
	if task == null or managers.is_empty() or not managers[0].has_method("complete_task"):
		return false
	if not managers[0].complete_task(task):
		return false
	var previous_workplace: Node = worker.get("workplace") as Node
	worker.set_combat_role(CombatRole.Type.SWORDSMAN)
	if worker.has_method("assign_job"):
		worker.assign_job(worker.Job.NONE)
	if (
		is_instance_valid(previous_workplace)
		and previous_workplace.has_method("remove_worker")
	):
		previous_workplace.remove_worker(worker)
	return true


func register_training_worker(worker: Node) -> bool:
	if worker == null or training_workers.has(worker):
		return true
	if training_workers.size() >= training_slots:
		return false
	training_workers.append(worker)
	training_requests = maxi(training_requests - 1, 0)
	return true


func on_training_task_released(task: GameTask) -> void:
	if task != null and is_instance_valid(task.assigned_worker):
		training_workers.erase(task.assigned_worker)
	if task != null:
		_return_training_cost(task.data.get("training_cost", get_training_cost()))
	training_requests = maxi(training_requests - 1, 0)


func on_training_task_completed(task: GameTask) -> void:
	if task != null and is_instance_valid(task.assigned_worker):
		training_workers.erase(task.assigned_worker)
	training_requests = maxi(training_requests - 1, 0)


func _has_training_cost() -> bool:
	for resource_key: StringName in get_training_cost().keys():
		var required_amount: float = float(get_training_cost()[resource_key])
		var available_amount: float = 0.0
		for storage_node: Node in get_tree().get_nodes_in_group("resource_storages"):
			var storage: ResourceStorage = storage_node as ResourceStorage
			if storage != null:
				available_amount += storage.get_amount(resource_key)
		if available_amount < required_amount:
			return false
	return true


func _take_training_cost() -> bool:
	if not _has_training_cost():
		return false
	var taken_resources: Dictionary[StringName, float] = {}
	for resource_key: StringName in get_training_cost().keys():
		var remaining: float = float(get_training_cost()[resource_key])
		for storage_node: Node in get_tree().get_nodes_in_group("resource_storages"):
			var storage: ResourceStorage = storage_node as ResourceStorage
			if storage == null or remaining <= 0.0:
				continue
			var taken_amount: float = storage.take(resource_key, remaining)
			remaining -= taken_amount
			taken_resources[resource_key] = (
				float(taken_resources.get(resource_key, 0.0)) + taken_amount
			)
		if remaining > 0.0:
			_return_training_cost(taken_resources)
			return false
	return true


func _return_training_cost(cost: Dictionary) -> void:
	if cost.is_empty():
		return
	var bases: Array[Node] = get_tree().get_nodes_in_group("bases")
	if bases.is_empty() or not bases[0].has_method("add_resource"):
		return
	for resource_key: Variant in cost.keys():
		var amount: float = float(cost[resource_key])
		if amount > 0.0:
			bases[0].add_resource(resource_key, amount)
