class_name Barracks
extends BuildingBase


@export var patrol_point_reach_radius: float = 0.5


var garrisoned_units: Array[Node] = []
var active_patrol_units: Array[Node] = []
var patrol_group_started: bool = false
var patrol_points: Array[Vector3] = []
var patrol_point_index: int = -1
var patrol_assembled_units: Array[Node] = []
var patrol_point_reached_units: Array[Node] = []
var patrol_group_start_index: int = 0
var patrol_routes: Dictionary = {}


func _ready() -> void:
	super._ready()
	call_deferred("dispatch_available_swordsmen")


func _process(_delta: float) -> void:
	super._process(_delta)
	if not is_demolition_in_progress():
		dispatch_available_swordsmen()


func demolish() -> bool:
	var started: bool = super.demolish()
	if not started:
		return false
	var units_to_release: Array[Node] = garrisoned_units.duplicate()
	garrisoned_units.clear()
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
		if not is_instance_valid(unit):
			garrisoned_units.erase(unit)
	return garrisoned_units.size()


func has_free_garrison_slot() -> bool:
	return get_garrison_count() < get_garrison_capacity()


func register_garrison(unit: Node) -> bool:
	if unit == null or garrisoned_units.has(unit):
		return false
	if not has_free_garrison_slot():
		return false
	garrisoned_units.append(unit)
	return true


func unregister_garrison(unit: Node) -> void:
	garrisoned_units.erase(unit)


func get_garrison_entrance_position(_unit: Node = null) -> Vector3:
	return global_position + Vector3(0.0, 0.0, 2.0)


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
	if not garrisoned_units.has(unit):
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


func request_patrol() -> bool:
	if not can_start_patrol():
		print("军营暂时无法开始巡逻：没有可出巡的待命驻军")
		return false

	patrol_group_started = true
	return _start_next_patrol_group()


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
		active_patrol_units.append(unit)
		if unit.has_method("leave_garrison_for_patrol"):
			unit.leave_garrison_for_patrol(
				self,
				get_patrol_assemble_position(index)
			)
	return not active_patrol_units.is_empty()


func _get_ready_garrison_units() -> Array[Node]:
	var ready_units: Array[Node] = []
	for unit: Node in garrisoned_units:
		if not is_instance_valid(unit) or not unit.has_method("get"):
			continue
		if unit.has_method("is_garrisoned") and unit.is_garrisoned():
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
