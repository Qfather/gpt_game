class_name ForceEffectData
extends EffectData

@export_range(0.0, 5.0, 0.1) var horizontal_force: float = 0.0
@export_range(0.0, 5.0, 0.1) var vertical_force: float = 0.0

func apply_effect(source: Node, target: Node, modifiers: Dictionary = {}) -> bool:
	if source == null or target == null or not source is Node3D or not target is Node3D:
		return false
	if not source.is_inside_tree() or not target.is_inside_tree():
		return false
	var direction: Vector3 = (target as Node3D).global_position - (source as Node3D).global_position
	direction.y = 0.0
	if direction.length_squared() <= 0.001:
		return false
	var target_3d: Node3D = target as Node3D
	var force_multiplier: float = float(modifiers.get("force_multiplier", 1.0))
	var force: Vector3 = direction.normalized() * horizontal_force * force_multiplier * 8.0
	force.y = vertical_force * force_multiplier * 8.0
	if target.has_method("apply_force"):
		target.apply_force(force)
	else:
		target_3d.global_position += force
	return horizontal_force > 0.0 or vertical_force > 0.0
