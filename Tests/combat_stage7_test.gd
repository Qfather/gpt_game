extends SceneTree

var _failed: bool = false


class FakeSwordsman extends Node3D:
	var health: float = 40.0

	func get_combat_role() -> int:
		return CombatRole.Type.SWORDSMAN

	func has_combat_role() -> bool:
		return true

	func get_faction() -> int:
		return EnemyData.Faction.SETTLEMENT

	func is_dead() -> bool:
		return health <= 0.0

	func take_damage(amount: float, _source: Node) -> float:
		var actual_damage: float = minf(amount, health)
		health = maxf(health - actual_damage, 0.0)
		return actual_damage


func _initialize() -> void:
	var enemy_scene: PackedScene = preload("res://Scene/unit/enemy_base.tscn")
	var wolf_data: EnemyData = preload("res://data/enemies/raid/WolfData.tres")
	var wolf: EnemyBase = enemy_scene.instantiate()
	wolf.enemy_data = wolf_data
	wolf.set_physics_process(false)
	get_root().add_child(wolf)

	var swordsman: FakeSwordsman = FakeSwordsman.new()
	swordsman.position = Vector3(1.0, 0.0, 0.0)
	swordsman.add_to_group("villagers")
	get_root().add_child(swordsman)
	await process_frame

	_expect(wolf.get_enemy_id() == &"wolf", "狼读取 EnemyData 标识")
	_expect(wolf.get_display_name() == "狼", "狼读取 EnemyData 名称")
	_expect(wolf.max_health == 60.0, "狼读取最大生命值")
	_expect(wolf.damage == 12.0, "狼读取攻击力")
	_expect(wolf.move_speed == 5.0, "狼读取移动速度")
	_expect(wolf.detection_range == 14.0, "狼读取索敌范围")
	_expect(wolf.get_node("VisualRoot").get_child_count() > 0, "狼加载独立视觉场景")

	wolf.update_targeting()
	_expect(wolf.target == swordsman, "狼锁定范围内最近的剑士")
	wolf.attack_cooldown = 0.0
	wolf._physics_process(0.1)
	_expect(swordsman.health == 20.0, "狼的 Ground Slam 与普通攻击均造成配置伤害")

	wolf.free()
	swordsman.free()
	if _failed:
		printerr("Combat V1 阶段 7 测试失败")
		quit(1)
		return

	print("Combat V1 阶段 7 测试通过")
	quit()


func _expect(condition: bool, description: String) -> void:
	if condition:
		print("[通过] ", description)
		return

	_failed = true
	printerr("[失败] ", description)
