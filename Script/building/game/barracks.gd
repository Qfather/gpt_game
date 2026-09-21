class_name Barracks
extends BuildingBase


const RESOURCE_DATABASE: ResourceDatabase = preload(
	"res://data/resources/resource_database.tres"
)

@export var patrol_point_reach_radius: float = 0.5
@export var garrison_entry_reach_radius: float = 1.8
@export_category("军粮")
@export var food_capacity: float = 30.0
@export var resupply_trigger: float = 10.0


var garrisoned_units: Array[Node] = []
var garrison_reservations: Array[Node] = []
var active_patrol_units: Array[Node] = []
var patrol_group_started: bool = false
var patrol_points: Array[Vector3] = []
var patrol_point_index: int = -1
var patrol_assembled_units: Array[Node] = []
var patrol_point_reached_units: Array[Node] = []
var patrol_group_start_index: int = 0
var patrol_routes: Dictionary = {}
var food_inventory: Dictionary[StringName, float] = {}
var resupply_workers: Array[Node] = []
var food_resupply_requested: bool = false

signal food_changed(current_amount: float, capacity: float)


func _ready() -> void:
	super._ready()
	call_deferred("dispatch_available_swordsmen")


func _process(_delta: float) -> void:
	super._process(_delta)
	if not is_demolition_in_progress():
		dispatch_available_swordsmen()
		_try_start_food_resupply()
		_try_start_auto_patrol()


func demolish() -> bool:
	var started: bool = super.demolish()
	if not started:
		return false
	var units_to_release: Array[Node] = garrisoned_units.duplicate()
	garrisoned_units.clear()
	units_to_release.append_array(garrison_reservations)
	garrison_reservations.clear()
	for unit: Node in units_to_release:
		if is_instance_valid(unit) and unit.has_method("leave_garrison"):
			unit.leave_garrison()
	return true


func get_garrison_capacity() -> int:
	if building_data != null and building_data.garrison_capacity > 0:
		return building_data.garrison_capacity
	return 6


func get_garrison_count() -> int:
	for unit: Node in garrisoned_units.duplicate():
		if (
			not is_instance_valid(unit)
			or not unit.has_method("is_garrisoned")
			or not unit.is_garrisoned()
			or unit.get("garrisoned_in") != self
		):
			garrisoned_units.erase(unit)
	for unit: Node in active_patrol_units.duplicate():
		if not is_instance_valid(unit):
			active_patrol_units.erase(unit)
	for unit: Node in resupply_workers.duplicate():
		if not is_instance_valid(unit):
			resupply_workers.erase(unit)
	var assigned_units: Array[Node] = []
	for unit: Node in garrisoned_units + active_patrol_units + resupply_workers:
		if is_instance_valid(unit) and not assigned_units.has(unit):
			assigned_units.append(unit)
	return assigned_units.size()


func get_garrison_occupancy_count() -> int:
	for unit: Node in garrison_reservations.duplicate():
		if (
			not is_instance_valid(unit)
			or not unit.has_method("get")
			or unit.get("garrison_target") != self
			or unit.get("state") != unit.State.MOVE_TO_BARRACKS
		):
			garrison_reservations.erase(unit)
	return get_garrison_count() + garrison_reservations.size()


func has_free_garrison_slot() -> bool:
	return get_garrison_occupancy_count() < get_garrison_capacity()


func get_food_amount() -> float:
	var total: float = 0.0
	for amount: float in food_inventory.values():
		total += amount
	return total


func get_food_capacity() -> float:
	return maxf(food_capacity, 0.0)


func get_food_ratio() -> float:
	var capacity: float = get_food_capacity()
	if capacity <= 0.0:
		return 0.0
	return clampf(get_food_amount() / capacity, 0.0, 1.0)


func add_food(resource_id: StringName, amount: float) -> float:
	if amount <= 0.0:
		return 0.0
	var resource_data: ResourceData = RESOURCE_DATABASE.get_resource_data(resource_id)
	if resource_data == null or not resource_data.is_food():
		return 0.0
	var accepted_amount: float = minf(
		amount,
		maxf(get_food_capacity() - get_food_amount(), 0.0)
	)
	if accepted_amount <= 0.0:
		return 0.0
	food_inventory[resource_id] = (
		float(food_inventory.get(resource_id, 0.0)) + accepted_amount
	)
	if get_food_amount() >= get_food_capacity():
		food_resupply_requested = false
	food_changed.emit(get_food_amount(), get_food_capacity())
	return accepted_amount


func get_food_resource_ids() -> Array[StringName]:
	var resource_ids: Array[StringName] = []
	for resource_id: StringName in food_inventory.keys():
		if float(food_inventory[resource_id]) > 0.0:
			resource_ids.append(resource_id)
	return resource_ids


func take_food(resource_id: StringName, amount: float) -> float:
	if amount <= 0.0:
		return 0.0
	var available_amount: float = float(food_inventory.get(resource_id, 0.0))
	var taken_amount: float = minf(amount, available_amount)
	if taken_amount <= 0.0:
		return 0.0
	food_inventory[resource_id] = available_amount - taken_amount
	if food_inventory[resource_id] <= 0.0:
		food_inventory.erase(resource_id)
	food_changed.emit(get_food_amount(), get_food_capacity())
	return taken_amount


func debug_add_food(amount: float = 10.0) -> float:
	return add_food(&"grain", amount)


func register_garrison(unit: Node) -> bool:
	if unit == null or garrisoned_units.has(unit) or garrison_reservations.has(unit):
		return false
	if not has_free_garrison_slot():
		return false
	garrison_reservations.append(unit)
	return true


func unregister_garrison(unit: Node) -> void:
	garrisoned_units.erase(unit)
	garrison_reservations.erase(unit)


func receive_resupply_return(unit: Node) -> void:
	resupply_workers.erase(unit)
	if is_instance_valid(unit) and has_free_garrison_slot():
		garrisoned_units.append(unit)
		unit.enter_garrison(self)


func _try_start_food_resupply() -> void:
	for worker: Node in resupply_workers.duplicate():
		if not is_instance_valid(worker):
			resupply_workers.erase(worker)
	if get_food_amount() < maxf(resupply_trigger, 0.0):
		food_resupply_requested = true
	if not food_resupply_requested:
		return
	if get_food_amount() >= get_food_capacity():
		food_resupply_requested = false
		return
	var total_garrison_count: int = get_garrison_count()
	var max_resupply_workers: int = maxi(1, floori(float(total_garrison_count) / 2.0))
	if resupply_workers.size() >= max_resupply_workers:
		return
	var bases: Array[Node] = get_tree().get_nodes_in_group("bases")
	if bases.is_empty():
		return
	var base: Node = bases[0]
	for unit: Node in garrisoned_units.duplicate():
		if resupply_workers.size() >= max_resupply_workers:
			return
		if not is_instance_valid(unit):
			garrisoned_units.erase(unit)
			continue
		if unit.get("state") != unit.State.GARRISONED:
			continue
		if unit.has_method("begin_barracks_resupply") and unit.begin_barracks_resupply(self, base):
			resupply_workers.append(unit)


func get_garrison_entrance_position(_unit: Node = null) -> Vector3:
	return global_position + Vector3(0.0, 0.0, 2.0)


func get_garrison_entry_reach_radius() -> float:
	return maxf(garrison_entry_reach_radius, 0.1)


func get_patrol_assemble_position(index: int) -> Vector3:
	var offsets: Array[Vector3] = [
		Vector3(-1.5, 0.0, 3.5),
		Vector3(0.0, 0.0, 4.0),
		Vector3(1.5, 0.0, 3.5)
	]
	var safe_index: int = clampi(index, 0, offsets.size() - 1)
	return global_position + global_transform.basis.orthonormalized() * offsets[safe_index]


func get_patrol_point(index: int) -> Vector3:
	var offsets: Array[Vector3] = [
		Vector3(-7.0, 0.0, 1.0),
		Vector3(-5.0, 0.0, -7.0),
		Vector3(7.0, 0.0, -6.0),
		Vector3(8.0, 0.0, 2.0)
	]
	var safe_index: int = clampi(index, 0, offsets.size() - 1)
	return global_position + global_transform.basis.orthonormalized() * offsets[safe_index]


func get_patrol_point_reach_radius() -> float:
	return maxf(patrol_point_reach_radius, 0.1)


func enter_garrison(unit: Node) -> void:
	if garrison_reservations.has(unit):
		garrison_reservations.erase(unit)
		garrisoned_units.append(unit)
	elif not garrisoned_units.has(unit):
		return
	if unit.has_method("enter_garrison"):
		unit.enter_garrison(self)


func dispatch_available_swordsmen() -> void:
	for unit: Node in get_tree().get_nodes_in_group("villagers"):
		if not has_free_garrison_slot():
			return
		if unit.has_method("try_assign_to_barracks"):
			unit.try_assign_to_barracks(self)


func can_start_patrol() -> bool:
	return (
		not patrol_group_started
		and active_patrol_units.is_empty()
		and not _get_ready_garrison_units().is_empty()
	)


func is_patrol_in_progress() -> bool:
	return not active_patrol_units.is_empty() or not patrol_assembled_units.is_empty()


func request_patrol() -> bool:
	if not can_start_patrol():
		print("军营暂时无法开始巡逻：没有可出巡的待命驻军")
		return false

	patrol_group_started = true
	return _start_next_patrol_group()


func _try_start_auto_patrol() -> void:
	if is_patrol_in_progress():
		return
	if get_food_amount() < maxf(resupply_trigger, 0.0):
		return
	var ready_units: Array[Node] = _get_ready_garrison_units()
	if ready_units.is_empty():
		return
	patrol_group_started = true
	_start_next_patrol_group()


func _start_next_patrol_group() -> bool:
	var ready_units: Array[Node] = _get_ready_garrison_units()
	if ready_units.is_empty():
		return false

	var patrol_count: int = ceili(float(ready_units.size()) / 2.0)
	var selected_units: Array[Node] = []
	for offset: int in range(mini(patrol_count, ready_units.size())):
		var unit_index: int = (patrol_group_start_index + offset) % ready_units.size()
		selected_units.append(ready_units[unit_index])

	patrol_group_start_index = (
		patrol_group_start_index + selected_units.size()
		) % ready_units.size()
	for index: int in range(selected_units.size()):
		var unit: Node = selected_units[index]
		if unit.has_method("leave_garrison_for_patrol") and unit.leave_garrison_for_patrol(
				self,
				get_patrol_assemble_position(index)
			):
			garrisoned_units.erase(unit)
			active_patrol_units.append(unit)
	return not active_patrol_units.is_empty()


func _get_ready_garrison_units() -> Array[Node]:
	var ready_units: Array[Node] = []
	for unit: Node in garrisoned_units:
		if not is_instance_valid(unit) or not unit.has_method("get"):
			continue
		if unit.has_method("is_ready_for_patrol") and unit.is_ready_for_patrol():
			ready_units.append(unit)
	return ready_units


func notify_patrol_assembled(unit: Node) -> void:
	if not active_patrol_units.has(unit) or patrol_assembled_units.has(unit):
		return
	patrol_assembled_units.append(unit)
	if patrol_assembled_units.size() < _get_active_patrol_count():
		return

	patrol_points.clear()
	var previous_point: Vector3 = get_patrol_assemble_position(0)
	for point_index: int in range(4):
		var patrol_point: Vector3 = _find_reachable_patrol_point(
			get_patrol_point(point_index),
			previous_point
		)
		patrol_points.append(patrol_point)
		previous_point = patrol_point
	patrol_point_index = 0
	patrol_point_reached_units.clear()
	for unit_index: int in range(active_patrol_units.size()):
		var patrol_unit: Node = active_patrol_units[unit_index]
		if not is_instance_valid(patrol_unit):
			continue
		var route: Array[Vector3] = _create_patrol_route(unit_index)
		patrol_routes[patrol_unit] = route
		if patrol_unit.has_method("start_patrol_route"):
			patrol_unit.start_patrol_route(route, unit_index)


func _create_patrol_route(unit_index: int) -> Array[Vector3]:
	return patrol_points.duplicate()


func _find_reachable_patrol_point(
	desired_point: Vector3,
	previous_point: Vector3
) -> Vector3:
	var navigation_map: RID = get_world_3d().get_navigation_map()
	if not navigation_map.is_valid():
		return desired_point

	var sample_directions: Array[Vector3] = [
		Vector3.ZERO,
		Vector3.RIGHT,
		Vector3.LEFT,
		Vector3.FORWARD,
		Vector3.BACK,
		(Vector3.RIGHT + Vector3.FORWARD).normalized(),
		(Vector3.LEFT + Vector3.FORWARD).normalized(),
		(Vector3.RIGHT + Vector3.BACK).normalized(),
		(Vector3.LEFT + Vector3.BACK).normalized()
	]
	var sample_radii: Array[float] = [0.0, 1.0, 2.0, 3.0]
	var navigation_start: Vector3 = NavigationServer3D.map_get_closest_point(
		navigation_map,
		previous_point
	)
	for radius: float in sample_radii:
		for direction: Vector3 in sample_directions:
			if radius <= 0.0 and direction != Vector3.ZERO:
				continue
			if radius > 0.0 and direction == Vector3.ZERO:
				continue
			var sample_point: Vector3 = desired_point + direction * radius
			var navigation_point: Vector3 = NavigationServer3D.map_get_closest_point(
				navigation_map,
				sample_point
			)
			if not _is_patrol_point_clear(navigation_point):
				continue
			var path: PackedVector3Array = NavigationServer3D.map_get_path(
				navigation_map,
				navigation_start,
				navigation_point,
				true
			)
			if path.is_empty():
				continue
			if path[path.size() - 1].distance_to(navigation_point) > 0.25:
				continue
			return navigation_point
	push_warning("军营巡逻点附近没有可达位置，跳过该巡逻点")
	return navigation_start


func _is_patrol_point_clear(point: Vector3) -> bool:
	var clearance_shape := SphereShape3D.new()
	clearance_shape.radius = 0.55
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = clearance_shape
	query.transform = Transform3D(Basis.IDENTITY, point + Vector3.UP * 0.8)
	query.collision_mask = 1
	query.collide_with_bodies = true
	query.collide_with_areas = false
	return get_world_3d().direct_space_state.intersect_shape(query, 8).is_empty()


func notify_patrol_route_completed(unit: Node) -> void:
	if not active_patrol_units.has(unit):
		return
	patrol_routes.erase(unit)
	if is_instance_valid(unit) and unit.has_method("start_return_to_patrol_barracks"):
		unit.start_return_to_patrol_barracks()


func receive_patrol_return(unit: Node) -> void:
	if not active_patrol_units.has(unit):
		return
	active_patrol_units.erase(unit)
	if is_instance_valid(unit) and unit.has_method("enter_garrison"):
		if not garrisoned_units.has(unit):
			garrisoned_units.append(unit)
		unit.enter_garrison(self)
	if active_patrol_units.is_empty():
		patrol_assembled_units.clear()
		patrol_point_reached_units.clear()
		patrol_points.clear()
		patrol_point_index = -1
		patrol_routes.clear()
		_start_next_patrol_group()


func _get_active_patrol_count() -> int:
	var count: int = 0
	for unit: Node in active_patrol_units:
		if is_instance_valid(unit):
			count += 1
	return count
