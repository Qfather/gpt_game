class_name ConstructionSite
extends Node3D

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
var grid_position: Vector2i
var rotation_step: int = 0
var mirrored: bool = false

var required_resources: Dictionary = {}
var delivered_resources: Dictionary = {}
var reserved_resources: Dictionary = {}
var construction_progress: float = 0.0
var builders: Array[Node] = []
var state: State = State.WAITING_RESOURCES

var site_mesh: MeshInstance3D
var site_material: StandardMaterial3D


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
	required_resources = building_data.construction_cost.duplicate(true)
	delivered_resources = {}
	reserved_resources = {}
	_refresh_state()


func _ready() -> void:

	add_to_group("construction_sites")
	_create_site_visual()
	_print_status()
	call_deferred("_request_delivery_task")


func _unhandled_input(event: InputEvent) -> void:

	if (
		event is InputEventKey
		and event.pressed
		and not event.echo
		and event.keycode == KEY_D
	):

		debug_deliver_required_resources()
		get_viewport().set_input_as_handled()


func get_state() -> State:

	return state


func get_required_amount(resource_type: ResourceType.Type) -> float:

	return float(required_resources.get(resource_type, 0.0))


func get_delivered_amount(resource_type: ResourceType.Type) -> float:

	return float(delivered_resources.get(resource_type, 0.0))


func get_reserved_amount(resource_type: ResourceType.Type) -> float:

	return float(reserved_resources.get(resource_type, 0.0))


func get_still_needed(resource_type: ResourceType.Type) -> float:

	return maxf(
		get_required_amount(resource_type)
		- get_delivered_amount(resource_type)
		- get_reserved_amount(resource_type),
		0.0
	)


func get_next_needed_resource() -> int:

	for resource_type: int in required_resources.keys():
		if get_still_needed(resource_type) > 0.0:
			return resource_type

	return -1


func get_max_construction_workers() -> int:

	if building_data == null:
		return 1

	return maxi(building_data.max_construction_workers, 1)


func reserve_resource(
	resource_type: ResourceType.Type,
	amount: float
) -> float:

	var actual_amount: float = minf(amount, get_still_needed(resource_type))
	if actual_amount <= 0.0:
		return 0.0

	reserved_resources[resource_type] = (
		get_reserved_amount(resource_type) + actual_amount
	)
	_print_status()
	return actual_amount


func release_reserved_resource(
	resource_type: ResourceType.Type,
	amount: float
) -> void:

	var remaining: float = maxf(
		get_reserved_amount(resource_type) - amount,
		0.0
	)
	if remaining <= 0.0:
		reserved_resources.erase(resource_type)
	else:
		reserved_resources[resource_type] = remaining


func receive_delivery(
	resource_type: ResourceType.Type,
	amount: float
) -> float:

	var actual_amount: float = minf(amount, get_still_needed(resource_type) + get_reserved_amount(resource_type))
	if actual_amount <= 0.0:
		return 0.0

	delivered_resources[resource_type] = (
		get_delivered_amount(resource_type) + actual_amount
	)
	_refresh_state()
	_print_status()
	return actual_amount


func on_delivery_task_completed(task: GameTask) -> void:
	var resource_type: int = int(task.data.get("resource_type", -1))
	var amount: float = float(task.data.get("amount", 0.0))
	release_reserved_resource(resource_type, amount)
	call_deferred("_request_delivery_task")


func on_delivery_task_released(task: GameTask) -> void:
	var resource_type: int = int(task.data.get("resource_type", -1))
	var amount: float = float(task.data.get("amount", 0.0))
	release_reserved_resource(resource_type, amount)
	call_deferred("_request_delivery_task")


func _request_delivery_task() -> void:
	if state != State.WAITING_RESOURCES:
		return

	var managers: Array[Node] = get_tree().get_nodes_in_group("task_manager")
	if managers.is_empty():
		return

	var manager: Node = managers[0]
	if manager.has_method("create_construction_delivery_tasks"):
		manager.create_construction_delivery_tasks(self)


func debug_deliver_resource(
	resource_type: ResourceType.Type,
	amount: float
) -> float:

	if amount <= 0.0:
		return 0.0

	var actual_amount: float = minf(
		amount,
		get_still_needed(resource_type)
	)

	if actual_amount <= 0.0:
		return 0.0

	delivered_resources[resource_type] = (
		get_delivered_amount(resource_type)
		+ actual_amount
	)
	_refresh_state()
	_print_status()

	return actual_amount


func debug_deliver_required_resources() -> void:

	var resource_types: Array = required_resources.keys()

	for resource_type: int in resource_types:
		debug_deliver_resource(
			resource_type,
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


func _all_resources_delivered() -> bool:

	var resource_types: Array = required_resources.keys()

	for resource_type: int in resource_types:

		if get_delivered_amount(resource_type) < get_required_amount(resource_type):
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
	var resource_types: Array = required_resources.keys()

	for resource_type: int in resource_types:
		result[resource_type] = get_still_needed(resource_type)

	return result


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
