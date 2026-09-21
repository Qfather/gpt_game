extends SceneTree

var _failed: bool = false


class FakeSwordsman extends Node3D:
	var combat_role: int = 1
	var health: float = 100.0

	func get_combat_role() -> int:
		return combat_role

	func is_dead() -> bool:
		return health <= 0.0

	func get_faction() -> int:
		return 0

	func take_damage(amount: float, _source: Node) -> float:
		var actual_damage: float = minf(amount, health)
		health = maxf(health - actual_damage, 0.0)
		return actual_damage


func _initialize() -> void:
	var enemy_scene: PackedScene = preload("res://Scene/unit/enemy_base.tscn")
	var enemy: EnemyBase = enemy_scene.instantiate() as EnemyBase
	get_root().add_child(enemy)
	await process_frame

	var swordsman: FakeSwordsman = FakeSwordsman.new()
	swordsman.position = Vector3(4.0, 0.0, 0.0)
	swordsman.add_to_group("villagers")
	get_root().add_child(swordsman)

	enemy.update_targeting()
	var start_x: float = enemy.global_position.x
	enemy._physics_process(0.5)
	_expect(enemy.global_position.x > start_x, "史莱姆会自动向剑士追踪")

	enemy.global_position = Vector3(3.0, 0.0, 0.0)
	swordsman.global_position = Vector3(3.8, 0.0, 0.0)
	enemy.update_targeting()
	enemy.attack_cooldown = 0.0
	enemy._physics_process(1.0)
	_expect(swordsman.health == 95.0, "进入攻击范围后会造成基础伤害")

	enemy._physics_process(0.2)
	_expect(swordsman.health == 95.0, "攻击间隔内不会重复攻击")

	enemy.free()
	swordsman.free()
	if _failed:
		printerr("Combat V1 阶段 4 测试失败")
		quit(1)
		return

	print("Combat V1 阶段 4 测试通过")
	quit()


func _expect(condition: bool, description: String) -> void:
	if condition:
		print("[通过] ", description)
		return

	_failed = true
	printerr("[失败] ", description)
