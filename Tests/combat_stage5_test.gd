extends SceneTree

var _failed: bool = false


class FakeEnemy extends Node3D:
	var health: float = 50.0

	func get_faction() -> int:
		return 1

	func is_dead() -> bool:
		return health <= 0.0

	func take_damage(amount: float, _source: Node) -> float:
		var actual_damage: float = minf(amount, health)
		health = maxf(health - actual_damage, 0.0)
		return actual_damage


func _initialize() -> void:
	var villager_scene: PackedScene = preload("res://Scene/unit/villager.tscn")
	var enemy: FakeEnemy = FakeEnemy.new()
	enemy.add_to_group("enemies")
	enemy.position = Vector3(1.0, 0.0, 0.0)
	get_root().add_child(enemy)

	var first: Node = villager_scene.instantiate()
	var second: Node = villager_scene.instantiate()
	first.set_combat_role(CombatRole.Type.SWORDSMAN)
	second.set_combat_role(CombatRole.Type.SWORDSMAN)
	first.state = first.State.PATROLLING
	second.state = second.State.PATROLLING
	first.position = Vector3.ZERO
	second.position = Vector3(0.0, 0.0, 0.5)
	get_root().add_child(first)
	get_root().add_child(second)
	await process_frame
	first.set_physics_process(false)
	second.set_physics_process(false)
	enemy.health = 50.0

	first._process_combat(1.0)
	second._process_combat(1.0)
	_expect(enemy.health == 30.0, "两个巡逻剑士可以同时攻击同一敌人")
	_expect(first.combat_target == enemy, "剑士发现敌人后锁定战斗目标")

	first.state = first.State.IDLE
	first.combat_target = null
	first.combat_resume_state = -1
	first.combat_attack_cooldown = 0.0
	enemy.health = 50.0
	first._process_combat(1.0)
	_expect(enemy.health == 40.0, "非巡逻状态的剑士也会主动攻击敌人")

	first.free()
	second.free()
	enemy.free()
	if _failed:
		printerr("Combat V1 阶段 5 测试失败")
		quit(1)
		return

	print("Combat V1 阶段 5 测试通过")
	quit()


func _expect(condition: bool, description: String) -> void:
	if condition:
		print("[通过] ", description)
		return

	_failed = true
	printerr("[失败] ", description)
