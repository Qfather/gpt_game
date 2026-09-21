extends SceneTree

var _failed: bool = false


class FakeTarget extends Node3D:
	var combat_role: int = 0
	var dead: bool = false

	func get_combat_role() -> int:
		return combat_role

	func is_dead() -> bool:
		return dead

	func get_faction() -> int:
		return 0


func _initialize() -> void:
	var enemy_scene: PackedScene = preload("res://Scene/unit/enemy_base.tscn")
	var enemy: EnemyBase = enemy_scene.instantiate() as EnemyBase
	get_root().add_child(enemy)
	await process_frame

	var target: FakeTarget = FakeTarget.new()
	target.position = Vector3(3.0, 0.0, 0.0)
	target.add_to_group("villagers")
	get_root().add_child(target)

	enemy.update_targeting()
	_expect(enemy.target == null, "普通居民不是合法敌人目标")

	target.combat_role = 1
	enemy.update_targeting()
	_expect(enemy.target == target, "敌人可以识别检测范围内的剑士")

	target.position = Vector3(20.0, 0.0, 0.0)
	enemy.update_targeting()
	_expect(enemy.target == null, "剑士离开检测范围后清除目标")

	target.position = Vector3(3.0, 0.0, 0.0)
	target.dead = true
	enemy.update_targeting()
	_expect(enemy.target == null, "死亡目标不会被重新选择")

	target.dead = false
	target.position = Vector3(2.0, 0.0, 0.0)
	enemy.update_targeting()
	_expect(enemy.target == target, "目标恢复有效后可以重新选择")

	enemy.free()
	target.free()
	if _failed:
		printerr("Combat V1 阶段 3 测试失败")
		quit(1)
		return

	print("Combat V1 阶段 3 测试通过")
	quit()


func _expect(condition: bool, description: String) -> void:
	if condition:
		print("[通过] ", description)
		return

	_failed = true
	printerr("[失败] ", description)
