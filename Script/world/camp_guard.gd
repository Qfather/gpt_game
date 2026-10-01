extends EnemyBase

var camp: TreasureCamp
var home_position: Vector3


func update_targeting() -> void:
	if is_dead() or not is_instance_valid(camp):
		_set_target(null)
		return
	var nearest: Node3D
	var distance: float = detection_range
	var candidates: Array[Node] = get_tree().get_nodes_in_group("combat_units")
	candidates.append_array(get_tree().get_nodes_in_group("enemies"))
	for candidate: Node in candidates:
		if candidate == self or not candidate is Node3D or not candidate.is_visible_in_tree():
			continue
		if not candidate.has_method("get_faction") or candidate.get_faction() == get_faction():
			continue
		if candidate.has_method("is_dead") and candidate.is_dead():
			continue
		if camp.global_position.distance_to(candidate.global_position) > camp.guard_leash_radius:
			continue
		var next_distance: float = global_position.distance_to(candidate.global_position)
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
	if not is_instance_valid(target):
		if global_position.distance_to(home_position) > 0.8:
			_move_toward_navigation_target(home_position)
		else:
			velocity = Vector3.ZERO
		return
	super._physics_process(delta)


func _on_input_event(camera: Node, event: InputEvent, position: Vector3, normal: Vector3, shape: int) -> void:
	if is_instance_valid(camp):
		camp._on_input_event(camera, event, position, normal, shape)
