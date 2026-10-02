extends Node3D

var target: Node3D
var shooter: Node
var damage: float
var speed: float
var lifetime: float = 8.0

static func launch(source: Node3D, victim: Node3D, origin: Vector3, amount: float, flight_speed: float) -> Node3D:
	var arrow: Node3D = load("res://Scene/unit/arrow.tscn").instantiate()
	arrow.target = victim
	arrow.shooter = source
	arrow.damage = amount
	arrow.speed = flight_speed
	source.get_tree().current_scene.add_child(arrow)
	arrow.global_position = origin
	return arrow

func _physics_process(delta: float) -> void:
	lifetime -= delta
	if lifetime <= 0.0 or not is_instance_valid(target) or target.is_queued_for_deletion() or (target.has_method("is_dead") and target.is_dead()):
		queue_free()
		return
	var destination: Vector3 = target.global_position + Vector3.UP * 0.6
	var distance: float = global_position.distance_to(destination)
	if distance <= speed * delta + 0.1:
		if is_instance_valid(shooter): target.take_damage(damage, shooter)
		queue_free()
		return
	look_at(destination)
	global_position = global_position.move_toward(destination, speed * delta)
