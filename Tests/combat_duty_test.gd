extends SceneTree

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world
	var unit: Node = load("res://Scene/unit/villager.tscn").instantiate()
	world.add_child(unit)
	unit.set_physics_process(false)
	unit.traits.clear()
	unit.set_combat_role(CombatRole.Type.NONE)
	assert(not unit.has_attack_capability() and unit.get_combat_duty() == CombatRole.Duty.AVOID_DANGER)
	var bonus := StatModifier.new()
	bonus.stat = StatModifier.StatType.ATTACK_DAMAGE
	bonus.modifier_type = StatModifier.ModifierType.ADD
	bonus.value = 1.0
	var level := TraitLevelData.new()
	level.modifiers.append(bonus)
	var data := TraitData.new()
	data.levels.append(level)
	var strength := UnitTrait.new()
	strength.trait_data = data
	unit.traits.append(strength)
	var enemy: EnemyBase = load("res://Scene/unit/enemy_base.tscn").instantiate()
	world.add_child(enemy)
	enemy.set_process(false)
	enemy.set_physics_process(false)
	assert(unit.get_attack_damage() == 1.0 and unit.has_attack_capability())
	assert(unit.get_combat_duty() == CombatRole.Duty.AVOID_DANGER and not unit._process_combat(0.016))
	assert(not enemy._is_defender(unit))
	bonus.value = 3.0
	assert(unit.get_attack_damage() == 3.0 and unit.get_combat_duty() == CombatRole.Duty.AVOID_DANGER)
	unit.traits.clear()
	unit.job = unit.Job.HUNTER
	unit.set_unit_data(load("res://data/units/HunterData.tres"))
	assert(unit.has_attack_capability() and unit.get_combat_duty() == CombatRole.Duty.SELF_DEFENSE)
	assert(enemy._is_defender(unit))
	assert(not unit._process_civilian_retreat(0.016))
	unit.job = unit.Job.NONE
	for role: int in [CombatRole.Type.MILITIA, CombatRole.Type.SWORDSMAN, CombatRole.Type.ARCHER]:
		unit.set_combat_role(role)
		assert(unit.get_combat_duty() == CombatRole.Duty.ENGAGE and unit.has_attack_capability())
		assert(not unit._process_civilian_retreat(0.016))
	unit.set_combat_role(CombatRole.Type.NONE)
	assert(unit.get_combat_duty() == CombatRole.Duty.AVOID_DANGER and not unit.has_attack_capability())
	print("攻击能力与职责测试通过：居民加攻击不参战、猎人自卫、民兵剑士弓箭手迎战、身份恢复")
	world.queue_free()
	await process_frame
	quit()
