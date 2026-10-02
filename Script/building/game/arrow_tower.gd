extends Barracks

@export_category("箭塔")
@export_range(1, 5, 0.1) var attack_range_multiplier: float = 1.5
@export_range(1, 100, 0.1) var base_sight_radius: float = 12.0
@export_range(1, 5, 0.1) var occupied_sight_multiplier: float = 1.5

func get_garrison_role() -> int:
	return CombatRole.Type.ARCHER

func get_garrison_capacity() -> int:
	return mini(super.get_garrison_capacity(), 2)

func dispatch_available_swordsmen() -> void:
	for unit: Node in get_tree().get_nodes_in_group("villagers"):
		if not has_free_garrison_slot(): return
		if unit.get_combat_role() != CombatRole.Type.ARCHER: continue
		var previous: Node = unit.garrisoned_in
		if is_instance_valid(previous) and not previous.has_method("allows_garrison_attacks"):
			previous.remove_unit_from_rosters(unit)
			unit.leave_garrison()
		unit.try_assign_to_barracks(self)

func allows_garrison_attacks() -> bool:
	return true

func get_garrison_position(unit: Node) -> Vector3:
	var side: float = -0.65
	for other: Node3D in garrisoned_units:
		if other != unit and other.global_position.x < global_position.x: side = 0.65
	return global_position + Vector3(side, 3.0, 0.0)

func get_sight_radius() -> float:
	get_garrison_count()
	return base_sight_radius * (occupied_sight_multiplier if not garrisoned_units.is_empty() else 1.0)

func _try_start_auto_patrol() -> void:
	pass

func can_start_patrol() -> bool:
	return false

func dispatch_base_defenders(_attacker: Node3D) -> void:
	pass
