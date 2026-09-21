extends SceneTree

var _failed: bool = false


class FakeEnemy extends Node3D:
	var health: float = 10.0

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
	var swordsman: Node = villager_scene.instantiate()
	swordsman.set_combat_role(CombatRole.Type.SWORDSMAN)
	swordsman.state = swordsman.State.PATROLLING
	swordsman.patrol_target_position = Vector3(5.0, 0.0, 0.0)
	swordsman.set_physics_process(false)
	get_root().add_child(swordsman)

	var first_enemy: FakeEnemy = FakeEnemy.new()
	first_enemy.position = Vector3(1.0, 0.0, 0.0)
	first_enemy.add_to_group("enemies")
	get_root().add_child(first_enemy)
	var second_enemy: FakeEnemy = FakeEnemy.new()
	second_enemy.position = Vector3(2.0, 0.0, 0.0)
	second_enemy.add_to_group("enemies")
	get_root().add_child(second_enemy)
	await process_frame
	swordsman.state = swordsman.State.PATROLLING
	swordsman.patrol_target_position = Vector3(5.0, 0.0, 0.0)

	swordsman._process_combat(0.1)
	_expect(
		first_enemy.health == 0.0 and second_enemy.health == 10.0,
		"剑士先攻击最近敌人"
	)
	first_enemy.health = 0.0
	swordsman._process_combat(0.1)
	_expect(swordsman.combat_target == second_enemy, "当前目标失效后切换到第二个敌人")
	second_enemy.health = 0.0
	swordsman._process_combat(0.1)
	_expect(swordsman.combat_target == null, "附近没有敌人后清除战斗目标")
	_expect(
		swordsman.state == swordsman.State.MOVE_TO_PATROL_POINT,
		"战斗结束后恢复之前的巡逻任务"
	)

	swordsman.free()
	first_enemy.free()
	second_enemy.free()
	if _failed:
		printerr("Combat V1 阶段 6 测试失败")
		quit(1)
		return

	print("Combat V1 阶段 6 测试通过")
	quit()


func _expect(condition: bool, description: String) -> void:
	if condition:
		print("[通过] ", description)
		return

	_failed = true
	printerr("[失败] ", description)
