class_name SwordsmanCamp
extends BuildingBase


@export_category("训练")
@export_enum("无", "剑士", "弓箭手", "民兵") var training_role: int = CombatRole.Type.SWORDSMAN
@export var training_slots: int = 2
@export var training_time: float = 10.0

var training_workers: Array[Node] = []
var training_requests: int = 0


func get_training_slots() -> int:
	return building_data.training_slots if building_data != null and not building_data.training_recipes.is_empty() else training_slots


func get_training_time(worker: Node = null) -> float:
	if is_instance_valid(worker) and worker.current_task != null:
		return float(worker.current_task.data.get("training_time", training_time))
	var recipe := get_recipe()
	return recipe.time_seconds if recipe != null else maxf(training_time, 0.1)


func get_recipe(index: int = 0) -> TrainingRecipe:
	if building_data == null or index < 0 or index >= building_data.training_recipes.size(): return null
	return building_data.training_recipes[index]


func get_training_name(index: int = 0) -> String:
	var recipe := get_recipe(index)
	var catalog := BuildingCatalog.for_tree(get_tree())
	if recipe != null and catalog != null and catalog.units.has(recipe.unit_id):
		return catalog.units[recipe.unit_id].display_name
	return CombatRole.get_display_name(training_role)


func get_training_cost(index: int = 0) -> Dictionary[StringName, float]:
	var recipe := get_recipe(index)
	if recipe != null: return recipe.cost.duplicate()
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
	for slot_index: int in range(get_training_slots()):
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


func can_request_training(index: int = 0) -> bool:
	if is_destroyed() or is_demolition_in_progress() or is_instance_valid(upgrade_site): return false
	var recipe := get_recipe(index)
	if building_data != null and not building_data.training_recipes.is_empty():
		var catalog := BuildingCatalog.for_tree(get_tree())
		if recipe == null or not recipe.enabled or catalog == null or not catalog.units.has(recipe.unit_id): return false
		if catalog.units[recipe.unit_id].combat_role == CombatRole.Type.NONE: return false
	return (
		get_training_worker_count() < get_training_slots()
		and _has_training_cost(index)
	)


func request_training(index: int = 0) -> bool:
	if not can_request_training(index):
		return false
	if not _take_training_cost(index):
		return false
	var managers: Array[Node] = get_tree().get_nodes_in_group("task_manager")
	if managers.is_empty() or not managers[0].has_method("create_task"):
		_return_training_cost(get_training_cost(index))
		return false
	var task: GameTask = managers[0].create_task(
		GameTask.TaskType.TRAIN_SWORDSMAN,
		self,
		self,
		10
	)
	if task == null:
		_return_training_cost(get_training_cost(index))
		return false
	task.data["training_cost"] = get_training_cost(index)
	training_requests += 1
	var recipe := get_recipe(index)
	task.data["training_role"] = training_role
	task.data["training_time"] = get_training_time()
	if recipe != null:
		task.data["unit_id"] = recipe.unit_id
		task.data["training_time"] = recipe.time_seconds
	return true


func get_training_position(worker: Node) -> Vector3:
	return get_entrance_position()


func get_sheltered_training_worker() -> Node:
	var fallback: Node = null
	for resident: Node in get_tree().get_nodes_in_group("villagers"):
		if resident.state != resident.State.SHELTERED or resident.is_dead() or resident.current_task != null or resident.has_combat_role(): continue
		if resident.shelter_target == self: return resident
		if fallback == null: fallback = resident
	return fallback


func begin_training(worker: Node) -> bool:
	if worker == null or not training_workers.has(worker):
		return false
	worker.state = worker.State.TRAINING
	worker.visible = false
	worker.velocity = Vector3.ZERO
	worker.collision_layer = 0
	worker.collision_mask = 0
	worker.global_position = get_interior_position()
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
	var unit_id: StringName = task.data.get("unit_id", &"")
	var catalog := BuildingCatalog.for_tree(get_tree())
	var data: UnitData = catalog.units.get(unit_id) if catalog != null else null
	if data != null:
		worker.set_combat_role(data.combat_role)
		worker.set_unit_data(data)
	else:
		worker.set_combat_role(int(task.data.get("training_role", training_role)))
	if worker.has_method("assign_job"):
		worker.assign_job(worker.Job.NONE)
	if (
		is_instance_valid(previous_workplace)
		and previous_workplace.has_method("remove_worker")
	):
		previous_workplace.remove_worker(worker)
	worker.state = worker.State.IDLE
	worker.leave_completed_training(self)
	return true


func register_training_worker(worker: Node) -> bool:
	if worker == null or training_workers.has(worker):
		return true
	if training_workers.size() >= get_training_slots() or (get_shelter_occupants().size() >= get_training_slots() and not get_shelter_occupants().has(worker)):
		return false
	training_workers.append(worker)
	training_requests = maxi(training_requests - 1, 0)
	return true


func on_training_task_released(task: GameTask) -> void:
	var registered: bool = task != null and is_instance_valid(task.assigned_worker) and training_workers.has(task.assigned_worker)
	if registered:
		training_workers.erase(task.assigned_worker)
	else:
		training_requests = maxi(training_requests - 1, 0)
	if task != null and not task.data.get("training_refunded", false):
		_return_training_cost(task.data.get("training_cost", get_training_cost()))
		task.data["training_refunded"] = true


func on_training_task_requeued(task: GameTask) -> void:
	if task != null and is_instance_valid(task.assigned_worker) and training_workers.has(task.assigned_worker):
		training_workers.erase(task.assigned_worker)
		training_requests += 1


func on_training_task_completed(task: GameTask) -> void:
	if task != null and is_instance_valid(task.assigned_worker):
		training_workers.erase(task.assigned_worker)


func _has_training_cost(index: int = 0) -> bool:
	for resource_key: StringName in get_training_cost(index).keys():
		var required_amount: float = float(get_training_cost(index)[resource_key])
		var available_amount: float = 0.0
		for storage_node: Node in get_tree().get_nodes_in_group("resource_storages"):
			var storage: ResourceStorage = storage_node as ResourceStorage
			if storage != null:
				available_amount += storage.get_amount(resource_key)
		if available_amount < required_amount:
			return false
	return true


func _take_training_cost(index: int = 0) -> bool:
	if not _has_training_cost(index):
		return false
	var taken_resources: Dictionary[StringName, float] = {}
	for resource_key: StringName in get_training_cost(index).keys():
		var remaining: float = float(get_training_cost(index)[resource_key])
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
