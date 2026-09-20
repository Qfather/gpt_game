class_name Migrant
extends CharacterBody3D

signal arrived(migrant: Node3D, base: Node3D)

@export var move_speed: float = 2.5

@onready var navigation_agent: NavigationAgent3D = $NavigationAgent3D

var target_base: Node3D
var _arrival_notified: bool = false


func setup(base: Node3D) -> void:
	target_base = base
	call_deferred("_set_navigation_target")


func _set_navigation_target() -> void:
	if not is_instance_valid(target_base):
		return

	await get_tree().physics_frame
	while NavigationServer3D.map_get_iteration_id(
		navigation_agent.get_navigation_map()
	) == 0:
		await get_tree().physics_frame

	if not is_instance_valid(target_base):
		return

	var target_position: Vector3 = target_base.global_position
	if target_base.has_method("get_interaction_position"):
		target_position = target_base.get_interaction_position(self)

	navigation_agent.target_position = NavigationServer3D.map_get_closest_point(
		navigation_agent.get_navigation_map(),
		target_position
	)


func _physics_process(_delta: float) -> void:
	if not is_instance_valid(target_base):
		velocity = Vector3.ZERO
		return

	if NavigationServer3D.map_get_iteration_id(
		navigation_agent.get_navigation_map()
	) == 0:
		velocity = Vector3.ZERO
		return

	if _has_arrived():
		velocity = Vector3.ZERO
		_notify_arrival()
		return

	var next_position: Vector3 = navigation_agent.get_next_path_position()
	var direction: Vector3 = global_position.direction_to(next_position)
	direction.y = 0.0
	if direction.length_squared() <= 0.0001:
		velocity = Vector3.ZERO
		return

	velocity = direction.normalized() * move_speed
	move_and_slide()


func _has_arrived() -> bool:
	if _arrival_notified or not is_instance_valid(target_base):
		return false

	var target_position: Vector3 = target_base.global_position
	if target_base.has_method("get_interaction_position"):
		target_position = target_base.get_interaction_position(self)

	return (
		global_position.distance_to(target_position) <= 1.6
		or navigation_agent.is_navigation_finished()
	)


func _notify_arrival() -> void:
	if _arrival_notified:
		return

	_arrival_notified = true
	arrived.emit(self, target_base)
