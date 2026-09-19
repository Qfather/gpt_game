class_name TaskManager
extends Node

@export_category("临时调试")
@export var enable_debug_input: bool = true
@export var debug_task_type: int = GameTask.TaskType.BUILD

var tasks: Dictionary = {}
var next_task_number: int = 1
var debug_task: GameTask


func _ready() -> void:

	add_to_group("task_manager")


func _process(_delta: float) -> void:

	_dispatch_available_tasks()


func _dispatch_available_tasks() -> void:

	var villagers = get_tree().get_nodes_in_group("villagers")

	for task_variant in tasks.values():

		var task: GameTask = task_variant as GameTask
		if task == null or task.state != GameTask.State.AVAILABLE:
			continue

		for villager: Node in villagers:

			if claim_task(task, villager):
				break


func _unhandled_input(event: InputEvent) -> void:

	if not enable_debug_input:
		return

	if not (
		event is InputEventKey
		and event.pressed
		and not event.echo
	):
		return

	var key_event := event as InputEventKey

	match key_event.keycode:
		KEY_T:
			_debug_create_task()
		KEY_C:
			_debug_claim_task()
		KEY_R:
			_debug_release_task()
		KEY_F:
			_debug_complete_task()
		_:
			return

	get_viewport().set_input_as_handled()


func create_task(
	task_type: int,
	requester: Node = null,
	target: Node = null,
	priority: int = 0
) -> GameTask:

	var task := GameTask.new(
		StringName("task_%d" % next_task_number),
		task_type
	)
	next_task_number += 1
	task.requester = requester
	task.target = target
	task.priority = priority

	register_task(task)
	return task


func register_task(task: GameTask) -> bool:

	if task == null or tasks.has(task.id):
		return false

	tasks[task.id] = task
	return true


func find_task(task_id: StringName) -> GameTask:

	return tasks.get(task_id) as GameTask


func create_construction_delivery_task(
	site: Node,
	preferred_worker: Node = null
) -> GameTask:

	if site == null:
		return null

	if not site.has_method("get_next_needed_resource"):
		return null

	var resource_type: int = site.get_next_needed_resource()
	if resource_type < 0:
		return null

	var amount: float = minf(
		float(site.get_still_needed(resource_type)),
		5.0
	)
	if amount <= 0.0:
		return null

	if not site.has_method("reserve_resource"):
		return null

	var reserved_amount: float = site.reserve_resource(
		resource_type,
		amount
	)
	if reserved_amount <= 0.0:
		return null

	var task := create_task(
		GameTask.TaskType.DELIVER_CONSTRUCTION_RESOURCE,
		site,
		site
	)
	task.data = {
		"resource_type": resource_type,
		"amount": reserved_amount,
		"preferred_worker": preferred_worker
	}
	_print_task(task, "created")
	return task


func create_construction_delivery_tasks(
	site: Node,
	preferred_worker: Node = null
) -> void:

	if site == null or not site.has_method("get_max_construction_workers"):
		return

	var max_workers: int = site.get_max_construction_workers()
	if site.has_method("get_construction_worker_limit"):
		max_workers = site.get_construction_worker_limit()
	var active_count: int = 0
	var preferred_assigned: bool = false

	for task_variant in tasks.values():
		var existing_task: GameTask = task_variant as GameTask
		if existing_task == null or existing_task.target != site:
			continue

		if (
			existing_task.state == GameTask.State.AVAILABLE
			or existing_task.state == GameTask.State.CLAIMED
			or existing_task.state == GameTask.State.IN_PROGRESS
		):
			active_count += 1

	while active_count < max_workers:
		var task: GameTask = create_construction_delivery_task(
			site,
			preferred_worker if not preferred_assigned else null
		)
		if task == null:
			break
		active_count += 1
		preferred_assigned = true


func create_construction_build_tasks(
	site: Node,
	preferred_workers: Array[Node]
) -> void:

	if site == null or not site.has_method("get_max_construction_workers"):
		return

	var active_count: int = 0
	for task_variant in tasks.values():
		var existing_task: GameTask = task_variant as GameTask
		if existing_task == null or existing_task.target != site:
			continue
		if existing_task.type != GameTask.TaskType.BUILD:
			continue
		if (
			existing_task.state == GameTask.State.AVAILABLE
			or existing_task.state == GameTask.State.CLAIMED
			or existing_task.state == GameTask.State.IN_PROGRESS
		):
			active_count += 1

	var max_workers: int = site.get_max_construction_workers()
	if site.has_method("get_construction_worker_limit"):
		max_workers = site.get_construction_worker_limit()
	var assigned_workers: Array[Node] = []
	for task_variant in tasks.values():
		var existing_task: GameTask = task_variant as GameTask
		if existing_task == null or existing_task.target != site:
			continue
		if existing_task.type != GameTask.TaskType.BUILD:
			continue
		if (
			existing_task.state == GameTask.State.AVAILABLE
			or existing_task.state == GameTask.State.CLAIMED
			or existing_task.state == GameTask.State.IN_PROGRESS
		):
			var assigned_worker: Node = existing_task.data.get("preferred_worker") as Node
			if is_instance_valid(assigned_worker):
				assigned_workers.append(assigned_worker)

	var worker_index: int = 0
	while active_count < max_workers:
		var preferred_worker: Node = null
		while worker_index < preferred_workers.size():
			var candidate: Node = preferred_workers[worker_index]
			worker_index += 1
			if is_instance_valid(candidate) and not assigned_workers.has(candidate):
				preferred_worker = candidate
				break

		var task: GameTask = create_task(
			GameTask.TaskType.BUILD,
			site,
			site
		)
		task.data = {"preferred_worker": preferred_worker}
		_print_task(task, "created")
		active_count += 1
		if preferred_worker != null:
			assigned_workers.append(preferred_worker)
		elif preferred_workers.is_empty():
			break


func claim_task(task: GameTask, worker: Node) -> bool:

	if not _is_registered(task):
		return false

	if task.state != GameTask.State.AVAILABLE:
		return false

	if worker == null or not worker.has_method("can_take_task"):
		return false

	var preferred_worker: Node = task.data.get("preferred_worker") as Node
	if is_instance_valid(preferred_worker) and preferred_worker != worker:
		return false

	if not worker.can_take_task(task):
		return false

	task.state = GameTask.State.CLAIMED
	task.assigned_worker = worker
	if task.target != null and task.target.has_method("register_construction_worker"):
		task.target.register_construction_worker(worker)

	if worker.has_method("set_current_task"):
		worker.set_current_task(task)

	_print_task(task, "claimed")
	return true


func cancel_one_build_task(site: Node) -> bool:
	for task_variant in tasks.values():
		var task: GameTask = task_variant as GameTask
		if task == null or task.target != site or task.type != GameTask.TaskType.BUILD:
			continue
		if task.state == GameTask.State.AVAILABLE or task.state == GameTask.State.CLAIMED or task.state == GameTask.State.IN_PROGRESS:
			return cancel_task(task)

	return false


func cancel_one_delivery_task(site: Node) -> bool:
	for task_variant in tasks.values():
		var task: GameTask = task_variant as GameTask
		if task == null or task.target != site:
			continue
		if task.type != GameTask.TaskType.DELIVER_CONSTRUCTION_RESOURCE:
			continue
		if (
			task.state == GameTask.State.AVAILABLE
			or task.state == GameTask.State.CLAIMED
			or task.state == GameTask.State.IN_PROGRESS
		):
			return cancel_task(task)

	return false


func release_task(task: GameTask) -> bool:

	if not _is_registered(task):
		return false

	if (
		task.state != GameTask.State.CLAIMED
		and task.state != GameTask.State.IN_PROGRESS
	):
		return false

	if (
		task.type == GameTask.TaskType.DELIVER_CONSTRUCTION_RESOURCE
		and task.target != null
		and task.target.has_method("on_delivery_task_released")
	):
		task.target.on_delivery_task_released(task)
	elif (
		task.type == GameTask.TaskType.BUILD
		and task.target != null
		and task.target.has_method("on_build_task_released")
	):
		task.target.on_build_task_released(task)

	_return_worker_resources(task)
	_clear_worker_task(task)
	_return_worker_to_idle(task)
	task.data["preferred_worker"] = null
	task.state = GameTask.State.AVAILABLE
	task.assigned_worker = null

	_print_task(task, "released")
	return true


func complete_task(task: GameTask) -> bool:

	if not _is_registered(task):
		return false

	if (
		task.state == GameTask.State.COMPLETED
		or task.state == GameTask.State.CANCELLED
	):
		return false

	if (
		task.type == GameTask.TaskType.DELIVER_CONSTRUCTION_RESOURCE
		and task.target != null
		and task.target.has_method("on_delivery_task_completed")
	):
		task.target.on_delivery_task_completed(task)
	elif (
		task.type == GameTask.TaskType.BUILD
		and task.target != null
		and task.target.has_method("on_build_task_completed")
	):
		task.target.on_build_task_completed(task)

	_clear_worker_task(task)
	task.state = GameTask.State.COMPLETED
	task.assigned_worker = null

	_print_task(task, "completed")
	return true


func cancel_task(task: GameTask) -> bool:

	if not _is_registered(task):
		return false

	if (
		task.state == GameTask.State.COMPLETED
		or task.state == GameTask.State.CANCELLED
	):
		return false

	if (
		task.type == GameTask.TaskType.DELIVER_CONSTRUCTION_RESOURCE
		and task.target != null
		and task.target.has_method("on_delivery_task_released")
	):
		task.target.on_delivery_task_released(task)
	elif (
		task.type == GameTask.TaskType.BUILD
		and task.target != null
		and task.target.has_method("on_build_task_released")
	):
		task.target.on_build_task_released(task)

	_return_worker_resources(task)
	_clear_worker_task(task)
	_return_worker_to_idle(task)
	task.data["preferred_worker"] = null
	task.state = GameTask.State.CANCELLED
	task.assigned_worker = null

	_print_task(task, "cancelled")
	return true


func fail_task(task: GameTask) -> bool:

	if not _is_registered(task):
		return false
	if (
		task.state == GameTask.State.COMPLETED
		or task.state == GameTask.State.CANCELLED
	):
		return false

	if (
		task.type == GameTask.TaskType.DELIVER_CONSTRUCTION_RESOURCE
		and task.target != null
		and task.target.has_method("on_delivery_task_failed")
	):
		task.target.on_delivery_task_failed(task)

	_clear_worker_task(task)
	_return_worker_resources(task)
	_return_worker_to_idle(task)
	task.data["preferred_worker"] = null
	task.state = GameTask.State.CANCELLED
	task.assigned_worker = null

	_print_task(task, "failed")
	return true


func _is_registered(task: GameTask) -> bool:

	return task != null and tasks.get(task.id) == task


func _clear_worker_task(task: GameTask) -> void:

	if (
		task.assigned_worker != null
		and task.assigned_worker.has_method("clear_current_task")
	):
		task.assigned_worker.clear_current_task()


func _return_worker_to_idle(task: GameTask) -> void:

	if (
		task.assigned_worker != null
		and task.assigned_worker.has_method("return_to_idle")
	):
		task.assigned_worker.return_to_idle()


func _return_worker_resources(task: GameTask) -> void:

	if (
		task.assigned_worker != null
		and task.assigned_worker.has_method("return_carried_resource_to_base")
	):
		print("📦 取消任务，检查居民携带资源：", task.assigned_worker)
		task.assigned_worker.return_carried_resource_to_base()


func _debug_create_task() -> void:

	debug_task = create_task(
		debug_task_type,
		self,
		null
	)
	_print_task(debug_task, "created")


func _debug_claim_task() -> void:

	if debug_task == null:
		return

	var villagers = get_tree().get_nodes_in_group("villagers")
	for villager: Node in villagers:
		if claim_task(debug_task, villager):
			return

	print("TaskManager debug claim failed")


func _debug_release_task() -> void:

	if debug_task != null:
		release_task(debug_task)


func _debug_complete_task() -> void:

	if debug_task != null:
		complete_task(debug_task)


func _print_task(task: GameTask, action: String) -> void:

	print(
		"TaskManager ",
		action,
		": id=",
		task.id,
		" type=",
		task.type,
		" state=",
		task.state,
		" worker=",
		task.assigned_worker
	)
