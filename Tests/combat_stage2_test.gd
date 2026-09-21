extends SceneTree

var _failed: bool = false


func _initialize() -> void:
	var enemy_scene: PackedScene = preload("res://Scene/unit/enemy_base.tscn")
	var enemy: EnemyBase = enemy_scene.instantiate() as EnemyBase
	get_root().add_child(enemy)
	await process_frame

	var first_damage: float = enemy.take_damage(10.0)
	_expect(first_damage == 10.0, "敌人会返回实际承受伤害")
	_expect(enemy.current_health == 20.0, "敌人受到伤害后 HP 正确减少")
	_expect(not enemy.is_dead(), "敌人未归零时不会死亡")

	var final_damage: float = enemy.take_damage(25.0)
	_expect(final_damage == 20.0, "伤害不会超过当前 HP")
	_expect(enemy.current_health == 0.0, "敌人 HP 可以归零")
	_expect(enemy.is_dead(), "敌人 HP 归零后进入死亡状态")

	var villager: UnitBase = UnitBase.new()
	var health_script: Script = load(
		"res://Script/combat/health_component.gd"
	) as Script
	var villager_health: Node = health_script.new() as Node
	villager_health.name = "HealthComponent"
	villager.add_child(villager_health)
	get_root().add_child(villager)
	await process_frame

	var swordsman_damage: float = villager.take_damage(25.0)
	_expect(swordsman_damage == 25.0, "居民可以使用同一 take_damage 接口")
	_expect(villager.get_health() == 75.0, "剑士基础生命值正确减少")
	_expect(not villager.is_dead(), "剑士未归零时不会死亡")

	enemy.free()
	villager.free()
	if _failed:
		printerr("Combat V1 阶段 2 测试失败")
		quit(1)
		return

	print("Combat V1 阶段 2 测试通过")
	quit()


func _expect(condition: bool, description: String) -> void:
	if condition:
		print("[通过] ", description)
		return

	_failed = true
	printerr("[失败] ", description)
