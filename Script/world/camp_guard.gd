extends EnemyBase

var camp: TreasureCamp
var home_position: Vector3
var returning_to_camp: bool = false


func update_targeting() -> void:
	if is_dead() or not is_instance_valid(camp):
		_set_target(null)
		return
	if returning_to_camp:
		_set_target(null)
		return
	if _outside_camp(global_position) or (is_instance_valid(target) and _outside_camp(target.global_position)):
		_begin_return()
		return
	var nearest: Node3D
	var distance: float = detection_range
	var candidates: Array[Node] = get_tree().get_nodes_in_group("villagers")
	candidates.append_array(get_tree().get_nodes_in_group("enemies"))
	for candidate: Node in candidates:
		if not is_instance_valid(candidate) or candidate == self or not candidate is Node3D or candidate.is_queued_for_deletion() or not candidate.is_visible_in_tree():
			continue
		if not candidate.has_method("get_faction") or not EnemyData.are_factions_hostile(get_faction(), int(candidate.get_faction())):
			continue
		if candidate.has_method("is_dead") and candidate.is_dead():
			continue
		if _outside_camp(candidate.global_position):
			continue
		var next_distance: float = _flat_distance(global_position, candidate.global_position)
		if next_distance < distance:
			distance = next_distance
			nearest = candidate as Node3D
	_set_target(nearest)


func _physics_process(delta: float) -> void:
	if is_dead():
		return
	if not is_instance_valid(camp):
		queue_free()
		return
	if _outside_camp(global_position) or (is_instance_valid(target) and _outside_camp(target.global_position)):
		_begin_return()
	if returning_to_camp or not is_instance_valid(target):
		_return_home(delta)
		return
	super._physics_process(delta)


func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z))


func _outside_camp(position: Vector3) -> bool:
	return _flat_distance(camp.global_position, position) > camp.guard_leash_radius


func _begin_return() -> void:
	returning_to_camp = true
	_set_target(null)


func _return_home(delta: float) -> void:
	if _flat_distance(global_position, home_position) > 0.8:
		navigation_agent.target_desired_distance = 0.4
		if navigation_agent.target_position.distance_to(home_position) > 0.1:
			navigation_agent.target_position = home_position
		var next_position: Vector3 = navigation_agent.get_next_path_position()
		velocity = Vector3.ZERO if navigation_agent.is_navigation_finished() else global_position.direction_to(next_position) * move_speed
		move_and_slide()
		return
	velocity = Vector3.ZERO
	returning_to_camp = false
	health_component.heal(camp.guard_health_regen * delta)


func _on_input_event(camera: Node, event: InputEvent, position: Vector3, normal: Vector3, shape: int) -> void:
	if is_instance_valid(camp):
		camp._on_input_event(camera, event, position, normal, shape)
