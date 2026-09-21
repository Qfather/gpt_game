class_name TaskManager
extends Node

@export var debug_task_type: int = GameTask.TaskType.BUILD

var tasks: Dictionary = {}
var next_task_number: int = 1
var debug_task: GameTask
var dispatch_queued: bool = false
var dispatch_running: bool = false


func _ready() -> void:

	add_to_group("task_manager")
	for storage_node: Node in get_tree().get_nodes_in_group("resource_storages"):
		if (
			storage_node.has_signal("resource_changed")
			and not storage_node.resource_changed.is_connected(_on_resource_changed)
		):
			storage_node.resource_changed.connect(_on_resource_changed)
	request_dispatch()


func _on_resource_changed(
	_resource_id: StringName,
	_new_amount: float
) -> void:

	for villager: Node in get_tree().get_nodes_in_group("villagers"):
		if villager.has_method("wake_delivery_task"):
			villager.wake_delivery_task()

	request_dispatch()


func request_dispatch() -> void:
	if dispatch_queued or dispatch_running:
		return

	dispatch_queued = true
	call_deferred("_run_dispatch")


func _run_dispatch() -> void:
	dispatch_queued = false
	dispatch_running = true

	var construction_sites: Array[Node] = []
	for site: Node in get_tree().get_nodes_in_group("construction_sites"):
		construction_sites.append(site)
	construction_sites.sort_custom(_sort_construction_sites_by_priority)

	for site: Node in construction_sites:
		if site.has_method("_create_delivery_tasks_now"):
			site._create_delivery_tasks_now()
		elif site.has_method("request_delivery_tasks"):
			site.request_delivery_tasks()

	_dispatch_available_tasks()

	# 先让运输任务领取并登记运输居民，再补充施工等待居民，
	# 避免运输居民和施工居民同时占用名额导致人数超过上限。
	for site: Node in construction_sites:
		if site.has_method("prepare_construction_workers"):
			site.prepare_construction_workers()

	dispatch_running = false


func _sort_construction_sites_by_priority(a: Node, b: Node) -> bool:
	var a_priority: int = (
		int(a.get_delivery_priority())
		if a.has_method("get_delivery_priority")
		else 0
	)
	var b_priority: int = (
		int(b.get_delivery_priority())
		if b.has_method("get_delivery_priority")
		else 0
	)
	if a_priority != b_priority:
		return a_priority < b_priority

	return a.get_instance_id() < b.get_instance_id()


func _dispatch_available_tasks() -> void:

	var villagers: Array[Node] = get_tree().get_nodes_in_group("villagers")
	var available_tasks: Array[GameTask] = []

	for task_variant in tasks.values():
		var task: GameTask = task_variant as GameTask
		if task != null and task.state == GameTask.State.AVAILABLE:
			available_tasks.append(task)

	available_tasks.sort_custom(_sort_task_priority)

	for task: GameTask in available_tasks:

		for villager: Node in villagers:

			if claim_task(task, villager):
				break


func _sort_task_priority(a: GameTask, b: GameTask) -> bool:
	if a.priority != b.priority:
		return a.priority > b.priority

	return str(a.id).naturalnocasecmp_to(str(b.id)) < 0


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
	request_dispatch()
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
	preferred_worker: Node = null,
	preferred_resource_id: StringName = &""
) -> GameTask:

	if site == null:
		return null

	if (
		not site.has_method("get_next_needed_resource_id")
		and not site.has_method("get_next_needed_resource")
	):
		return null

	var resource_id: StringName = preferred_resource_id
	if resource_id.is_empty():
		if site.has_method("get_next_needed_resource_id"):
			resource_id = site.get_next_needed_resource_id()
		else:
			resource_id = ResourceStorage.resource_id_from_key(
				site.get_next_needed_resource()
			)
	if resource_id.is_empty():
		return null

	var amount: float = minf(
		float(site.get_still_needed(resource_id)),
		5.0
	)
	amount = minf(
		amount,
		_get_available_resource_amount(resource_id)
	)
	if amount <= 0.0:
		return null

	if not site.has_method("reserve_resource"):
		return null

	var reserved_amount: float = site.reserve_resource(
		resource_id,
		amount
	)
	if reserved_amount <= 0.0:
		return null

	var task := create_task(
		GameTask.TaskType.DELIVER_CONSTRUCTION_RESOURCE,
		site,
		site,
		_get_construction_task_priority(site)
	)
	task.data = {
		"resource_id": resource_id,
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
	var resources_already_reserved: bool = (
		site.has_method("has_all_reserved_construction_resources")
		and site.has_all_reserved_construction_resources()
	)
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
		var resource_id: StringName = _get_next_available_construction_resource(site)
		if resource_id.is_empty():
			break
		var task: GameTask = create_construction_delivery_task(
			site,
			preferred_worker if not preferred_assigned else null,
			resource_id
		)
		if task == null:
			break
		active_count += 1
		preferred_assigned = true

	resources_already_reserved = (
		site.has_method("has_all_reserved_construction_resources")
		and site.has_all_reserved_construction_resources()
	)
	if not resources_already_reserved and site.has_method("release_waiting_workers"):
		site.release_waiting_workers()


func _get_next_available_construction_resource(site: Node) -> StringName:
	if site == null:
		return &""
	var resource_ids: Array[StringName] = []
	if site.has_method("get_delivery_resource_ids"):
		resource_ids = site.get_delivery_resource_ids()
	elif site.has_method("get_delivery_resource_id"):
		var resource_id: StringName = site.get_delivery_resource_id()
		if not resource_id.is_empty():
			resource_ids.append(resource_id)
	else:
		var fallback_id: StringName = ResourceStorage.resource_id_from_key(
			site.get_delivery_resource_type()
		)
		if not fallback_id.is_empty():
			resource_ids.append(fallback_id)

	for resource_id: StringName in resource_ids:
		if site.has_method("get_still_needed") and site.get_still_needed(resource_id) <= 0.0:
			continue
		if _has_resource_source(resource_id):
			return resource_id
	return &""


func _get_construction_task_priority(site: Node) -> int:
	if site != null and site.has_method("get_delivery_priority"):
		return -int(site.get_delivery_priority())

	return 0


func _has_resource_source(resource_key: Variant) -> bool:
	var resource_id: StringName = ResourceStorage.resource_id_from_key(resource_key)
	return not resource_id.is_empty() and _get_available_resource_amount(resource_id) > 0.0


func _get_available_resource_amount(resource_id: StringName) -> float:
	if resource_id.is_empty():
		return 0.0

	var total_amount: float = 0.0

	for storage_node: Node in get_tree().get_nodes_in_group("resource_storages"):
		var storage: ResourceStorage = storage_node as ResourceStorage
		if storage != null and storage.get_amount(resource_id) > 0.0:
			total_amount += storage.get_amount(resource_id)

	var reserved_by_tasks: float = 0.0
	for task_variant in tasks.values():
		var task: GameTask = task_variant as GameTask
		if (
			task == null
			or task.type != GameTask.TaskType.DELIVER_CONSTRUCTION_RESOURCE
			or task.state == GameTask.State.COMPLETED
			or task.state == GameTask.State.CANCELLED
		):
			continue
		var task_resource_id: StringName = ResourceStorage.resource_id_from_key(
			task.data.get("resource_id", task.data.get("resource_type", &""))
		)
		if task_resource_id == resource_id:
			reserved_by_tasks += maxf(
				float(task.data.get("amount", 0.0))
				- float(task.data.get("resource_taken_amount", 0.0)),
				0.0
			)

	return maxf(total_amount - reserved_by_tasks, 0.0)


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
			site,
			_get_construction_task_priority(site)
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
	if (
		task.type == GameTask.TaskType.BUILD
		and task.target != null
		and task.target.has_method("can_register_construction_worker")
		and not task.target.can_register_construction_worker(worker)
	):
		return false
	if (
		task.type == GameTask.TaskType.TRAIN_SWORDSMAN
		and task.target != null
		and task.target.has_method("register_training_worker")
		and not task.target.register_training_worker(worker)
	):
		return false

	task.state = GameTask.State.CLAIMED
	task.assigned_worker = worker
	if task.target != null and task.target.has_method("register_construction_worker"):
		task.target.register_construction_worker(worker)

	if worker.has_method("set_current_task"):
		worker.set_current_task(task)

	_print_task(task, "claimed")
	request_dispatch()
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


func cancel_tasks_for_target(target: Node, return_workers: bool = true) -> void:
	var target_tasks: Array[GameTask] = []
	for task_variant in tasks.values():
		var task: GameTask = task_variant as GameTask
		if task == null or task.target != target:
			continue
		if task.state == GameTask.State.AVAILABLE or task.state == GameTask.State.CLAIMED or task.state == GameTask.State.IN_PROGRESS:
			target_tasks.append(task)

	for task: GameTask in target_tasks:
		cancel_task(task, return_workers)


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
	elif (
		task.type == GameTask.TaskType.TRAIN_SWORDSMAN
		and task.target != null
		and task.target.has_method("on_training_task_released")
	):
		task.target.on_training_task_released(task)

	var returning_resources: bool = _return_worker_resources(task)
	task.data["resource_taken_amount"] = 0.0
	_clear_worker_task(task)
	if not returning_resources:
		_return_worker_to_idle(task)
	task.data["preferred_worker"] = null
	task.state = GameTask.State.AVAILABLE
	task.assigned_worker = null

	_print_task(task, "released")
	request_dispatch()
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
	elif (
		task.type == GameTask.TaskType.TRAIN_SWORDSMAN
		and task.target != null
		and task.target.has_method("on_training_task_completed")
	):
		task.target.on_training_task_completed(task)

	_clear_worker_task(task)
	task.state = GameTask.State.COMPLETED
	task.assigned_worker = null

	_print_task(task, "completed")
	request_dispatch()
	return true


func cancel_task(task: GameTask, return_worker: bool = true) -> bool:

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
	elif (
		task.type == GameTask.TaskType.TRAIN_SWORDSMAN
		and task.target != null
		and task.target.has_method("on_training_task_released")
	):
		task.target.on_training_task_released(task)

	var returning_resources: bool = _return_worker_resources(task)
	task.data["resource_taken_amount"] = 0.0
	_clear_worker_task(task)
	if return_worker and not returning_resources:
		_return_worker_to_idle(task)
	task.data["preferred_worker"] = null
	task.state = GameTask.State.CANCELLED
	task.assigned_worker = null

	_print_task(task, "cancelled")
	request_dispatch()
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
	elif (
		task.type == GameTask.TaskType.TRAIN_SWORDSMAN
		and task.target != null
		and task.target.has_method("on_training_task_released")
	):
		task.target.on_training_task_released(task)

	_clear_worker_task(task)
	var returning_resources: bool = _return_worker_resources(task)
	task.data["resource_taken_amount"] = 0.0
	if not returning_resources:
		_return_worker_to_idle(task)
	task.data["preferred_worker"] = null
	task.state = GameTask.State.CANCELLED
	task.assigned_worker = null

	_print_task(task, "failed")
	request_dispatch()
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


func _return_worker_resources(task: GameTask) -> bool:

	if (
		task.assigned_worker != null
		and task.assigned_worker.has_method("return_carried_resource_to_base")
	):
		print("📦 取消任务，检查居民携带资源：", task.assigned_worker)
		return bool(task.assigned_worker.return_carried_resource_to_base())
	return false


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
	if not DevMode.DEV_MODE:
		return

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
