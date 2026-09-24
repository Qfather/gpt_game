class_name AbilityData
extends EnemyAbility


enum AreaShape { SINGLE, CIRCLE }

@export var area_shape: AreaShape = AreaShape.SINGLE
@export_range(0.1, 20.0, 0.1) var radius: float = 1.0
@export var effects: Array[EffectData] = []


func can_use(owner: Node) -> bool:
	return owner != null and is_instance_valid(owner)


func try_use(owner: Node, target: Node, modifiers: Dictionary = {}) -> bool:
	if not can_use(owner) or not owner.has_method("get_faction"):
		return false
	var targets: Array[Node] = _collect_targets(
		owner,
		target,
		float(modifiers.get("radius_multiplier", 1.0))
	)
	var hit_count: int = 0
	for effect: EffectData in effects:
		if effect == null or not effect.has_method("apply_effect"):
			continue
		for effect_target: Node in targets:
			if effect.apply_effect(owner, effect_target, modifiers):
				hit_count += 1
	return hit_count > 0


func _collect_targets(owner: Node, primary_target: Node, radius_multiplier: float) -> Array[Node]:
	var targets: Array[Node] = []
	var owner_faction: int = int(owner.get_faction())
	if _is_valid_target(primary_target, owner_faction):
		targets.append(primary_target)
	if area_shape != AreaShape.CIRCLE or not owner.is_inside_tree():
		return targets
	var candidates: Array[Node] = []
	candidates.append_array(owner.get_tree().get_nodes_in_group("villagers"))
	candidates.append_array(owner.get_tree().get_nodes_in_group("enemies"))
	for candidate: Node in candidates:
		if candidate in targets or not _is_valid_target(candidate, owner_faction):
			continue
		if owner is Node3D and candidate is Node3D:
			if (owner as Node3D).global_position.distance_to((candidate as Node3D).global_position) <= radius * radius_multiplier:
				targets.append(candidate)
	return targets


func _is_valid_target(candidate: Node, owner_faction: int) -> bool:
	if candidate == null or not is_instance_valid(candidate) or not candidate.has_method("get_faction"):
		return false
	if candidate.has_method("is_dead") and candidate.is_dead():
		return false
	return int(candidate.get_faction()) != owner_faction
