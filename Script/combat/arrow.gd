extends Node3D

const GRAVITY: float = 20.0

var target: Node3D
var shooter: Node
var damage: float
var lifetime: float = 8.0
var flight_origin: Vector3
var flight_duration: float
var flight_elapsed: float = 0.0

static func launch(source: Node3D, victim: Node3D, origin: Vector3, amount: float, flight_speed: float) -> Node3D:
	var arrow: Node3D = load("res://Scene/unit/arrow.tscn").instantiate()
	arrow.target = victim
	arrow.shooter = source
	arrow.damage = amount
	source.get_tree().current_scene.add_child(arrow)
	arrow.global_position = origin
	arrow.flight_origin = origin
	arrow.flight_duration = maxf(origin.distance_to(victim.global_position + Vector3.UP * 0.6) / flight_speed, 0.05)
	return arrow

func _physics_process(delta: float) -> void:
	lifetime -= delta
	if lifetime <= 0.0 or not is_instance_valid(target) or target.is_queued_for_deletion() or (target.has_method("is_dead") and target.is_dead()):
		queue_free()
		return
	var destination: Vector3 = target.global_position + Vector3.UP * 0.6
	flight_elapsed = minf(flight_elapsed + delta, flight_duration)
	var progress: float = flight_elapsed / flight_duration
	var next_position: Vector3 = flight_origin.lerp(destination, progress)
	next_position.y += 0.5 * GRAVITY * flight_elapsed * (flight_duration - flight_elapsed)
	var direction: Vector3 = next_position - global_position
	if direction.length_squared() > 0.000001:
		var up: Vector3 = Vector3.RIGHT if absf(direction.normalized().y) > 0.99 else Vector3.UP
		look_at(global_position + direction, up)
	global_position = next_position
	if flight_elapsed >= flight_duration:
		if is_instance_valid(shooter): target.take_damage(damage, shooter)
		queue_free()
		return
