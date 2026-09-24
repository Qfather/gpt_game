extends SceneTree

var _failed: bool = false


func _initialize() -> void:
	var enemy_scene: PackedScene = preload("res://Scene/unit/enemy_base.tscn")
	var wolf_data: EnemyData = preload("res://data/enemies/raid/WolfData.tres")
	var wolf: EnemyBase = enemy_scene.instantiate()
	wolf.enemy_data = wolf_data
	wolf.set_physics_process(false)
	get_root().add_child(wolf)
	await process_frame

	_expect(not wolf.get_abilities().is_empty(), "狼可以加载 Ground Slam 能力")
	_expect(
		wolf.get_abilities().size() == wolf_data.abilities.size(),
		"EnemyBase 读取 EnemyData 的能力列表"
	)

	wolf.free()
	if _failed:
		printerr("Combat V1 阶段 8 测试失败")
		quit(1)
		return

	print("Combat V1 阶段 8 测试通过")
	quit()


func _expect(condition: bool, description: String) -> void:
	if condition:
		print("[通过] ", description)
		return

	_failed = true
	printerr("[失败] ", description)
