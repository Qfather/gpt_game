extends SceneTree

var _failed: bool = false


func _initialize() -> void:
	var enemy_scene: PackedScene = preload("res://Scene/unit/enemy_base.tscn")
	var enemy: EnemyBase = enemy_scene.instantiate() as EnemyBase
	get_root().add_child(enemy)
	await process_frame

	_expect(enemy.enemy_data != null, "EnemyBase 可以读取 EnemyData")
	_expect(enemy.has_signal("enemy_clicked"), "EnemyBase 提供对象点击信号")
	_expect(enemy.get_enemy_id() == &"slime", "EnemyData 身份 ID 正确")
	_expect(enemy.get_display_name() == "史莱姆", "EnemyData 显示名称正确")
	_expect(enemy.max_health == 30.0, "EnemyBase 初始化 HP 正确")
	_expect(enemy.damage == 5.0, "EnemyBase 初始化 Damage 正确")
	_expect(enemy.move_speed == 2.5, "EnemyBase 初始化 Move Speed 正确")
	_expect(enemy.attack_range == 1.2, "EnemyBase 初始化 Attack Range 正确")
	_expect(enemy.attack_interval == 1.0, "EnemyBase 初始化 Attack Interval 正确")
	_expect(enemy.detection_range == 8.0, "EnemyBase 初始化 Detection Range 正确")
	_expect(enemy.current_health == enemy.max_health, "EnemyBase 初始当前 HP 等于最大 HP")

	enemy.free()
	if _failed:
		printerr("Combat V1 阶段 1 测试失败")
		quit(1)
		return

	print("Combat V1 阶段 1 测试通过")
	quit()


func _expect(condition: bool, description: String) -> void:
	if condition:
		print("[通过] ", description)
		return

	_failed = true
	printerr("[失败] ", description)
