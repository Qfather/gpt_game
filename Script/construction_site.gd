class_name ConstructionSite
extends BuildingBase

const RESOURCE_DATABASE: ResourceDatabase = preload(
	"res://data/resources/resource_database.tres"
)

static var next_delivery_priority: int = 0

enum State {
	WAITING_RESOURCES,
	READY_TO_BUILD,
	BUILDING,
	COMPLETED,
	CANCELLED
}

signal state_changed(new_state: State)

@export var debug_delivery_amount: float = 5.0

var building_data: BuildingData
var delivery_priority: int = 0
var grid_position: Vector2i
var rotation_step: int = 0
var mirrored: bool = false

var required_resources: Dictionary[StringName, float] = {}
var delivered_resources: Dictionary[StringName, float] = {}
var reserved_resources: Dictionary[StringName, float] = {}
var construction_progress: float = 0.0
var builders: Array[Node] = []
var delivery_workers: Array[Node] = []
var construction_workers: Array[Node] = []
var waiting_workers: Array[Node] = []
var state: State = State.WAITING_RESOURCES
var next_delivery_worker: Node = null
var delivery_replenishment_blocked: bool = false
var worker_replenishment_requested: bool = false
var worker_target_offsets: Dictionary = {}
var model_bounds: AABB = AABB()
var has_model_bounds: bool = false
var construction_worker_limit: int = 1
var progress_report_timer: float = 0.0

var site_mesh: MeshInstance3D
var site_material: StandardMaterial3D


func _init() -> void:
	delivery_priority = next_delivery_priority
	next_delivery_priority += 1


func setup(
	data: BuildingData,
	placed_grid_position: Vector2i,
	placed_rotation_step: int,
	placed_mirrored: bool
) -> void:

	building_data = data
	grid_position = placed_grid_position
	rotation_step = placed_rotation_step
	mirrored = placed_mirrored
	required_resources = _normalize_resource_dictionary(
		building_data.construction_cost
	)
	delivered_resources = {}
	reserved_resources = {}
	delivery_workers = []
	construction_workers = []
	waiting_workers = []
	next_delivery_worker = null
	delivery_replenishment_blocked = false
	worker_replenishment_requested = false
	worker_target_offsets = {}
	has_model_bounds = false
	construction_worker_limit = maxi(building_data.max_construction_workers, 1)
	_refresh_state()


func _ready() -> void:

	_create_click_area()
	super._ready()
	add_to_group("construction_sites")
	_calculate_model_bounds()
	_create_site_visual()
	_print_status()
	call_deferred("_request_delivery_task")
	call_deferred("_register_with_main")


func _process(delta: float) -> void:
	if (
		state == State.WAITING_RESOURCES
		and worker_replenishment_requested
		and not delivery_replenishment_blocked
	):
		var worker_count_before: int = get_worker_count()
		fill_waiting_workers()
		if get_worker_count() > worker_count_before:
			worker_replenishment_requested = false
			call_deferred("_request_delivery_task")

	if state != State.BUILDING or builders.is_empty() or building_data == null:
		return

	var efficiency: float = float(builders.size())
	construction_progress = minf(
		construction_progress + delta * efficiency,
		building_data.construction_time
	)
	if construction_progress >= building_data.construction_time:
		_complete_construction()
		return

	progress_report_timer += delta
	if progress_report_timer >= 1.0:
		progress_report_timer = 0.0
		print(
			"ConstructionSite 施工进度：",
			construction_progress,
			" / ",
			building_data.construction_time,
			"，人数：",
			builders.size(),
			"，效率：",
			efficiency
		)


func _complete_construction() -> void:
	if state == State.COMPLETED or building_data == null:
		return

	state = State.COMPLETED
	state_changed.emit(state)
	print("ConstructionSite 状态：", _state_name())

	var managers: Array[Node] = get_tree().get_nodes_in_group("task_manager")
	var building: Node3D = building_data.building_scene.instantiate() as Node3D
	if building == null:
		push_error("ConstructionSite：无法生成正式建筑场景")
		return

	var completed_workers: Array[Node] = []
	for worker: Node in builders:
		if is_instance_valid(worker) and not completed_workers.has(worker):
			completed_workers.append(worker)
	for worker: Node in waiting_workers:
		if is_instance_valid(worker) and not completed_workers.has(worker):
			completed_workers.append(worker)
	for worker: Node in delivery_workers:
		if is_instance_valid(worker) and not completed_workers.has(worker):
			completed_workers.append(worker)
	var keep_workers_at_building: bool = building.has_method("add_worker")
	if not managers.is_empty() and managers[0].has_method("cancel_tasks_for_target"):
		managers[0].cancel_tasks_for_target(self, not keep_workers_at_building)

	var parent_node: Node = get_parent()
	parent_node.add_child(building)
	building.global_transform = global_transform
	if keep_workers_at_building:
		for worker: Node in completed_workers:
			if is_instance_valid(worker):
				building.add_worker(worker)

	var main_node: Node = get_tree().current_scene
	if main_node != null and main_node.has_method("register_building"):
		main_node.register_building(building)

	print("ConstructionSite 完工，生成建筑：", building.name)
	_request_task_dispatch()
	queue_free()


func get_construction_progress_text() -> String:
	if building_data == null:
		return "施工进度：0 / 0"

	return "施工进度：%d / %d" % [
		int(construction_progress),
		int(building_data.construction_time)
	]


func _create_click_area() -> void:
	if get_node_or_null("ClickArea") != null:
		return

	var click_area_node: Area3D = Area3D.new()
	click_area_node.name = "ClickArea"
	add_child(click_area_node)
	click_area = click_area_node

	var collision: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	var rotated_size: Vector2i = Vector2i(
		building_data.grid_size.y,
		building_data.grid_size.x
	) if posmod(rotation_step, 2) == 1 else building_data.grid_size
	shape.size = Vector3(float(rotated_size.x), 1.0, float(rotated_size.y))
	collision.shape = shape
	collision.position.y = 0.5
	click_area_node.add_child(collision)


func _register_with_main() -> void:
	var main_node: Node = get_tree().current_scene
	if main_node != null and main_node.has_method("register_building"):
		main_node.register_building(self)


func get_state() -> State:

	return state


func get_required_amount(resource_key: Variant) -> float:

	var resource_id: StringName = ResourceStorage.resource_id_from_key(resource_key)
	return float(required_resources.get(resource_id, 0.0))


func get_delivered_amount(resource_key: Variant) -> float:

	var resource_id: StringName = ResourceStorage.resource_id_from_key(resource_key)
	return float(delivered_resources.get(resource_id, 0.0))


func get_reserved_amount(resource_key: Variant) -> float:

	var resource_id: StringName = ResourceStorage.resource_id_from_key(resource_key)
	return float(reserved_resources.get(resource_id, 0.0))


func get_still_needed(resource_key: Variant) -> float:

	var resource_id: StringName = ResourceStorage.resource_id_from_key(resource_key)

	return maxf(
		get_required_amount(resource_id)
		- get_delivered_amount(resource_id)
		- get_reserved_amount(resource_id),
		0.0
	)


func get_next_needed_resource_id() -> StringName:

	for resource_id: StringName in required_resources.keys():
		if get_still_needed(resource_id) > 0.0:
			return resource_id

	return &""


func get_delivery_resource_id() -> StringName:
	for resource_id: StringName in required_resources.keys():
		if get_delivered_amount(resource_id) < get_required_amount(resource_id):
			return resource_id

	return &""


func get_next_needed_resource() -> ResourceType.Type:
	return ResourceStorage.resource_type_from_id(get_next_needed_resource_id())


func get_delivery_resource_type() -> ResourceType.Type:
	return ResourceStorage.resource_type_from_id(get_delivery_resource_id())


func get_max_construction_workers() -> int:

	if building_data == null:
		return 1

	return maxi(building_data.max_construction_workers, 1)


func get_construction_worker_limit() -> int:
	return construction_worker_limit


func get_delivery_priority() -> int:
	return delivery_priority


func can_request_delivery_tasks() -> bool:
	return state == State.WAITING_RESOURCES and not delivery_replenishment_blocked


func has_all_reserved_construction_resources() -> bool:
	if state != State.WAITING_RESOURCES:
		return false
	for resource_id: StringName in required_resources.keys():
		if get_still_needed(resource_id) > 0.0:
			return false
	return true


func prepare_construction_workers() -> void:
	if not has_all_reserved_construction_resources():
		return
	fill_waiting_workers()


func get_build_preferred_workers() -> Array[Node]:
	var preferred_workers: Array[Node] = waiting_workers.duplicate()
	for worker: Node in delivery_workers:
		if not preferred_workers.has(worker):
			preferred_workers.append(worker)
	return preferred_workers


func get_worker_target_position(worker: Node) -> Vector3:
	var worker_id: int = worker.get_instance_id() if worker != null else 0
	if not worker_target_offsets.has(worker_id):
		var worker_index: int = construction_workers.find(worker)
		if worker_index < 0:
			worker_index = waiting_workers.find(worker)
		if worker_index < 0:
			worker_index = worker_target_offsets.size()
		worker_target_offsets[worker_id] = _create_random_edge_offset(
			worker_index,
			maxi(get_max_construction_workers(), 1)
		)

	var local_offset: Vector3 = worker_target_offsets[worker_id]
	var site_basis: Basis = global_transform.basis.orthonormalized()
	return global_position + site_basis * local_offset


func _create_random_edge_offset(worker_index: int, worker_count: int) -> Vector3:
	if not has_model_bounds:
		return Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0))

	var half_size: Vector2 = Vector2(
		model_bounds.size.x * 0.5,
		model_bounds.size.z * 0.5
	)
	var center: Vector3 = model_bounds.position + model_bounds.size * 0.5
	var edge_padding: float = 0.2
	var width: float = maxf(half_size.x * 2.0, 0.1)
	var depth: float = maxf(half_size.y * 2.0, 0.1)
	var perimeter: float = 2.0 * (width + depth)
	var slot_center: float = float(worker_index) + 0.5
	var distance_on_perimeter: float = (
		slot_center
	) / float(maxi(worker_count, 1)) * perimeter
	var min_x: float = center.x - half_size.x
	var max_x: float = center.x + half_size.x
	var min_z: float = center.z - half_size.y
	var max_z: float = center.z + half_size.y
	var result: Vector3 = center

	if distance_on_perimeter < width:
		result.x = min_x + distance_on_perimeter
		result.z = max_z + edge_padding
	elif distance_on_perimeter < width + depth:
		result.x = max_x + edge_padding
		result.z = max_z - (distance_on_perimeter - width)
	elif distance_on_perimeter < width * 2.0 + depth:
		result.x = max_x - (distance_on_perimeter - width - depth)
		result.z = min_z - edge_padding
	else:
		result.x = min_x - edge_padding
		result.z = min_z + (distance_on_perimeter - width * 2.0 - depth)

	result.y = 0.0
	return result


func _calculate_model_bounds() -> void:
	if building_data == null or building_data.building_scene == null:
		return

	var model: Node3D = building_data.building_scene.instantiate() as Node3D
	if model == null:
		return
	add_child(model)

	var mesh_nodes: Array[Node] = model.find_children(
		"*",
		"MeshInstance3D",
		true,
		false
	)
	for mesh_node: Node in mesh_nodes:
		var mesh_instance: MeshInstance3D = mesh_node as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null:
			continue
		var mesh_to_model: Transform3D = (
			model.global_transform.affine_inverse() * mesh_instance.global_transform
		)
		var mesh_bounds: AABB = _transform_aabb(mesh_instance.get_aabb(), mesh_to_model)
		if not has_model_bounds:
			model_bounds = mesh_bounds
			has_model_bounds = true
		else:
			model_bounds = model_bounds.merge(mesh_bounds)

	model.free()


func _transform_aabb(source: AABB, transform: Transform3D) -> AABB:
	var first_corner: Vector3 = transform * source.position
	var result: AABB = AABB(first_corner, Vector3.ZERO)
	for corner_index: int in range(1, 8):
		var corner: Vector3 = source.position
		if (corner_index & 1) != 0:
			corner.x += source.size.x
		if (corner_index & 2) != 0:
			corner.y += source.size.y
		if (corner_index & 4) != 0:
			corner.z += source.size.z
		result = result.expand(transform * corner)
	return result


func get_worker_count() -> int:
	var assigned_workers: Array[Node] = []
	for worker: Node in construction_workers:
		if is_instance_valid(worker) and not assigned_workers.has(worker):
			assigned_workers.append(worker)
	for worker: Node in waiting_workers:
		if is_instance_valid(worker) and not assigned_workers.has(worker):
			assigned_workers.append(worker)
	for worker: Node in delivery_workers:
		if is_instance_valid(worker) and not assigned_workers.has(worker):
			assigned_workers.append(worker)

	return assigned_workers.size()


func get_max_worker_count() -> int:
	return get_max_construction_workers()


func has_free_slot() -> bool:
	return get_worker_count() < construction_worker_limit


func get_construction_material_text() -> String:
	var lines: PackedStringArray = []
	for resource_id: StringName in required_resources.keys():
		var resource_name: String = str(resource_id)
		var resource_data: ResourceData = RESOURCE_DATABASE.get_resource_data(resource_id)
		if resource_data != null and not resource_data.display_name.is_empty():
			resource_name = resource_data.display_name
		lines.append(
			"%s：%d / %d" % [
				resource_name,
				int(get_delivered_amount(resource_id)),
				int(get_required_amount(resource_id))
			]
		)
	return "材料：\n" + "\n".join(lines)


func request_additional_worker() -> void:
	if (
		state != State.WAITING_RESOURCES
		and state != State.READY_TO_BUILD
		and state != State.BUILDING
	):
		return
	if construction_worker_limit >= get_max_construction_workers():
		return

	construction_worker_limit += 1
	delivery_replenishment_blocked = false
	worker_replenishment_requested = true
	var villagers: Array[Node] = get_tree().get_nodes_in_group("villagers")
	var preferred_workers: Array[Node] = []
	for villager: Node in villagers:
		if not villager.has_method("is_idle") or not villager.is_idle():
			continue
		if construction_workers.has(villager) or waiting_workers.has(villager):
			continue
		if state == State.BUILDING:
			preferred_workers.append(villager)
		else:
			waiting_workers.append(villager)
			if villager.has_method("wait_at_construction_site"):
				villager.wait_at_construction_site(self)
		break
	if state != State.WAITING_RESOURCES or get_worker_count() >= construction_worker_limit:
		worker_replenishment_requested = false

	if state == State.WAITING_RESOURCES:
		call_deferred("_request_delivery_task")
	else:
		if state == State.BUILDING:
			var managers: Array[Node] = get_tree().get_nodes_in_group("task_manager")
			if not managers.is_empty() and managers[0].has_method(
				"create_construction_build_tasks"
			):
				managers[0].create_construction_build_tasks(self, preferred_workers)
			if not managers.is_empty() and managers[0].has_method("request_dispatch"):
				managers[0].request_dispatch()
		else:
			call_deferred("_request_build_tasks")


func cancel_one_worker() -> void:
	if (
		state != State.WAITING_RESOURCES
		and state != State.READY_TO_BUILD
		and state != State.BUILDING
	) or construction_worker_limit <= 0:
		return

	var cancelled: bool = false
	var managers: Array[Node] = get_tree().get_nodes_in_group("task_manager")
	if not managers.is_empty():
		var manager: Node = managers[0]
		if state == State.WAITING_RESOURCES and manager.has_method("cancel_one_delivery_task"):
			cancelled = manager.cancel_one_delivery_task(self)
		elif (
			(state == State.READY_TO_BUILD or state == State.BUILDING)
			and manager.has_method("cancel_one_build_task")
		):
			cancelled = manager.cancel_one_build_task(self)

	if cancelled:
		if state == State.WAITING_RESOURCES:
			delivery_replenishment_blocked = true
		construction_worker_limit = maxi(construction_worker_limit - 1, 0)
		return

	if state == State.WAITING_RESOURCES and not delivery_workers.is_empty():
		var worker: Node = delivery_workers.pop_back()
		if is_instance_valid(worker):
			construction_workers.erase(worker)
			delivery_replenishment_blocked = true
			if worker.has_method("return_to_idle"):
				worker.return_to_idle()
			construction_worker_limit = maxi(construction_worker_limit - 1, 0)
			return

	if state == State.BUILDING and not builders.is_empty():
		var worker: Node = builders.back()
		remove_builder(worker)
		if is_instance_valid(worker) and worker.has_method("return_to_idle"):
			worker.return_to_idle()
		construction_worker_limit = maxi(construction_worker_limit - 1, 0)
		return

	if not waiting_workers.is_empty():
		delivery_replenishment_blocked = true
		var worker: Node = waiting_workers.pop_back()
		if is_instance_valid(worker) and worker.has_method("return_to_idle"):
			worker.return_to_idle()
		construction_worker_limit = maxi(construction_worker_limit - 1, 0)


func register_construction_worker(worker: Node) -> void:
	if worker != null and not construction_workers.has(worker):
		waiting_workers.erase(worker)
		construction_workers.append(worker)


func remove_construction_worker(worker: Node) -> void:
	if construction_workers.has(worker):
		construction_workers.erase(worker)


func fill_waiting_workers() -> void:
	if state != State.WAITING_RESOURCES:
		return

	var villagers: Array[Node] = get_tree().get_nodes_in_group("villagers")
	while get_worker_count() < construction_worker_limit:
		var assigned: bool = false
		for villager: Node in villagers:
			if not villager.has_method("is_idle") or not villager.is_idle():
				continue
			if construction_workers.has(villager) or waiting_workers.has(villager):
				continue
			waiting_workers.append(villager)
			villager.wait_at_construction_site(self)
			assigned = true
			break
		if not assigned:
			break


func release_waiting_workers() -> void:
	var workers_to_release: Array[Node] = waiting_workers.duplicate()
	waiting_workers.clear()
	for worker: Node in workers_to_release:
		if is_instance_valid(worker) and worker.has_method("return_to_idle"):
			worker.return_to_idle()


func reserve_resource(
	resource_key: Variant,
	amount: float
) -> float:
	var resource_id: StringName = ResourceStorage.resource_id_from_key(resource_key)

	var actual_amount: float = minf(amount, get_still_needed(resource_id))
	if actual_amount <= 0.0:
		return 0.0

	reserved_resources[resource_id] = (
		get_reserved_amount(resource_id) + actual_amount
	)
	_print_status()
	return actual_amount


func release_reserved_resource(
	resource_key: Variant,
	amount: float
) -> void:
	var resource_id: StringName = ResourceStorage.resource_id_from_key(resource_key)

	var remaining: float = maxf(
		get_reserved_amount(resource_id) - amount,
		0.0
	)
	if remaining <= 0.0:
		reserved_resources.erase(resource_id)
	else:
		reserved_resources[resource_id] = remaining


func receive_delivery(
	resource_key: Variant,
	amount: float
) -> float:
	var resource_id: StringName = ResourceStorage.resource_id_from_key(resource_key)

	var actual_amount: float = minf(amount, get_still_needed(resource_id) + get_reserved_amount(resource_id))
	if actual_amount <= 0.0:
		return 0.0

	delivered_resources[resource_id] = (
		get_delivered_amount(resource_id) + actual_amount
	)
	_refresh_state()
	_print_status()
	return actual_amount


func on_delivery_task_completed(task: GameTask) -> void:
	if is_instance_valid(task.assigned_worker) and not delivery_workers.has(task.assigned_worker):
		delivery_workers.append(task.assigned_worker)
	next_delivery_worker = task.assigned_worker

	var resource_id: StringName = ResourceStorage.resource_id_from_key(
		task.data.get("resource_id", task.data.get("resource_type", &""))
	)
	var amount: float = float(task.data.get("amount", 0.0))
	release_reserved_resource(resource_id, amount)
	call_deferred("_request_delivery_task")


func on_delivery_task_released(task: GameTask) -> void:
	remove_construction_worker(task.assigned_worker)
	delivery_workers.erase(task.assigned_worker)
	if next_delivery_worker == task.assigned_worker:
		next_delivery_worker = null

	var resource_id: StringName = ResourceStorage.resource_id_from_key(
		task.data.get("resource_id", task.data.get("resource_type", &""))
	)
	var amount: float = float(task.data.get("amount", 0.0))
	release_reserved_resource(resource_id, amount)
	call_deferred("_request_delivery_task")


func on_delivery_task_failed(task: GameTask) -> void:
	remove_construction_worker(task.assigned_worker)
	delivery_workers.erase(task.assigned_worker)
	if next_delivery_worker == task.assigned_worker:
		next_delivery_worker = null

	var resource_id: StringName = ResourceStorage.resource_id_from_key(
		task.data.get("resource_id", task.data.get("resource_type", &""))
	)
	var amount: float = float(task.data.get("amount", 0.0))
	release_reserved_resource(resource_id, amount)


func _request_delivery_task() -> void:
	if state != State.WAITING_RESOURCES or delivery_replenishment_blocked:
		return

	var managers: Array[Node] = get_tree().get_nodes_in_group("task_manager")
	if managers.is_empty():
		return

	var manager: Node = managers[0]
	if manager.has_method("request_dispatch"):
		manager.request_dispatch()
	elif manager.has_method("create_construction_delivery_tasks"):
		manager.create_construction_delivery_tasks(self, next_delivery_worker)
	next_delivery_worker = null


func request_delivery_tasks() -> void:
	_request_delivery_task()


func _create_delivery_tasks_now() -> void:
	if state != State.WAITING_RESOURCES or delivery_replenishment_blocked:
		return

	var managers: Array[Node] = get_tree().get_nodes_in_group("task_manager")
	if managers.is_empty():
		return

	var manager: Node = managers[0]
	if manager.has_method("create_construction_delivery_tasks"):
		manager.create_construction_delivery_tasks(self, next_delivery_worker)
	next_delivery_worker = null


func _request_build_tasks() -> void:
	if state != State.READY_TO_BUILD:
		return

	var managers: Array[Node] = get_tree().get_nodes_in_group("task_manager")
	if managers.is_empty():
		return

	var manager: Node = managers[0]
	if manager.has_method("create_construction_build_tasks"):
		manager.create_construction_build_tasks(self, get_build_preferred_workers())
	if manager.has_method("request_dispatch"):
		manager.request_dispatch()


func add_builder(worker: Node) -> bool:
	if worker == null or builders.has(worker):
		return false
	if builders.size() >= get_max_construction_workers():
		return false

	builders.append(worker)
	if state == State.READY_TO_BUILD:
		state = State.BUILDING
		state_changed.emit(state)
		print("ConstructionSite 状态：", _state_name())
	print("ConstructionSite 加入施工人员：", worker)
	return true


func remove_builder(worker: Node) -> void:
	if builders.has(worker):
		builders.erase(worker)
		print("ConstructionSite 施工人员离开：", worker)
		if builders.is_empty() and construction_progress < float(building_data.construction_time):
			state = State.READY_TO_BUILD
			state_changed.emit(state)


func on_build_task_released(task: GameTask) -> void:
	remove_builder(task.assigned_worker)
	call_deferred("_request_build_tasks")


func on_build_task_completed(task: GameTask) -> void:
	remove_builder(task.assigned_worker)


func debug_deliver_resource(
	resource_key: Variant,
	amount: float
) -> float:
	var resource_id: StringName = ResourceStorage.resource_id_from_key(resource_key)

	if amount <= 0.0:
		return 0.0

	var actual_amount: float = minf(
		amount,
		get_still_needed(resource_id)
	)

	if actual_amount <= 0.0:
		return 0.0

	delivered_resources[resource_id] = (
		get_delivered_amount(resource_id)
		+ actual_amount
	)
	_refresh_state()
	_print_status()

	return actual_amount


func debug_deliver_required_resources() -> void:

	var resource_ids: Array = required_resources.keys()

	for resource_id: StringName in resource_ids:
		debug_deliver_resource(
			resource_id,
			debug_delivery_amount
		)


func _refresh_state() -> void:

	if (
		state == State.CANCELLED
		or state == State.COMPLETED
	):
		return

	var next_state: State = (
		State.READY_TO_BUILD
		if _all_resources_delivered()
		else State.WAITING_RESOURCES
	)

	if state == next_state:
		return

	state = next_state
	state_changed.emit(state)
	print("ConstructionSite 状态：", _state_name())
	if state == State.READY_TO_BUILD:
		call_deferred("_request_build_tasks")
	_request_task_dispatch()


func _request_task_dispatch() -> void:
	var managers: Array[Node] = get_tree().get_nodes_in_group("task_manager")
	if not managers.is_empty() and managers[0].has_method("request_dispatch"):
		managers[0].request_dispatch()


func _all_resources_delivered() -> bool:

	var resource_ids: Array = required_resources.keys()

	for resource_id: StringName in resource_ids:

		if get_delivered_amount(resource_id) < get_required_amount(resource_id):
			return false

	return true


func _state_name() -> String:

	return State.keys()[state]


func _print_status() -> void:

	print(
		"ConstructionSite ",
		_state_name(),
		" required=",
		required_resources,
		" delivered=",
		delivered_resources,
		" reserved=",
		reserved_resources,
		" still_needed=",
		_get_still_needed_summary()
	)


func _get_still_needed_summary() -> Dictionary:

	var result: Dictionary = {}
	var resource_ids: Array = required_resources.keys()

	for resource_id: StringName in resource_ids:
		result[resource_id] = get_still_needed(resource_id)

	return result


func _normalize_resource_dictionary(
	source: Dictionary
) -> Dictionary[StringName, float]:
	var normalized: Dictionary[StringName, float] = {}
	for resource_key: Variant in source.keys():
		var resource_id: StringName = ResourceStorage.resource_id_from_key(resource_key)
		if resource_id.is_empty():
			continue
		normalized[resource_id] = float(source[resource_key])
	return normalized


func _create_site_visual() -> void:

	if building_data == null:
		return

	site_mesh = MeshInstance3D.new()
	site_mesh.name = "ConstructionSiteMarker"
	add_child(site_mesh)

	var rotated_size: Vector2i = Vector2i(
		building_data.grid_size.y,
		building_data.grid_size.x
	) if posmod(rotation_step, 2) == 1 else building_data.grid_size

	var box_mesh: BoxMesh = BoxMesh.new()
	box_mesh.size = Vector3(
		float(rotated_size.x),
		0.25,
		float(rotated_size.y)
	)
	site_mesh.mesh = box_mesh

	site_material = StandardMaterial3D.new()
	site_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	site_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	site_material.albedo_color = Color(1.0, 0.65, 0.1, 0.35)
	site_mesh.material_override = site_material

	rotation.y = float(rotation_step) * PI * 0.5
	scale.x = -1.0 if mirrored else 1.0
