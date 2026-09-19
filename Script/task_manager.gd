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
	site: Node
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
		"amount": reserved_amount
	}
	_print_task(task, "created")
	return task


func create_construction_delivery_tasks(site: Node) -> void:

	if site == null or not site.has_method("get_max_construction_workers"):
		return

	var max_workers: int = site.get_max_construction_workers()
	var active_count: int = 0

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
		var task: GameTask = create_construction_delivery_task(site)
		if task == null:
			break
		active_count += 1


func claim_task(task: GameTask, worker: Node) -> bool:

	if not _is_registered(task):
		return false

	if task.state != GameTask.State.AVAILABLE:
		return false

	if worker == null or not worker.has_method("can_take_task"):
		return false

	if not worker.can_take_task(task):
		return false

	task.state = GameTask.State.CLAIMED
	task.assigned_worker = worker

	if worker.has_method("set_current_task"):
		worker.set_current_task(task)

	_print_task(task, "claimed")
	return true


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

	_clear_worker_task(task)
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

	_clear_worker_task(task)
	task.state = GameTask.State.CANCELLED
	task.assigned_worker = null

	_print_task(task, "cancelled")
	return true


func _is_registered(task: GameTask) -> bool:

	return task != null and tasks.get(task.id) == task


func _clear_worker_task(task: GameTask) -> void:

	if (
		task.assigned_worker != null
		and task.assigned_worker.has_method("clear_current_task")
	):
		task.assigned_worker.clear_current_task()


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
