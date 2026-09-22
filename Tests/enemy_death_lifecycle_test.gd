extends SceneTree

var _failed: bool = false


func _initialize() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	var enemy_scene: PackedScene = preload("res://Scene/unit/enemy_base.tscn")
	var enemy: Node = enemy_scene.instantiate()
	get_root().add_child(enemy)
	await process_frame

	_expect(get_nodes_in_group("enemies").has(enemy), "敌人生成后加入 enemies 分组")
	enemy.take_damage(9999.0)
	_expect(enemy.is_dead(), "敌人生命归零后进入死亡状态")
	_expect(not get_nodes_in_group("enemies").has(enemy), "敌人死亡后立即移出 enemies 分组")
	await create_timer(0.5).timeout
	_expect(not is_instance_valid(enemy), "敌人死亡后最终释放节点")

	if _failed:
		printerr("敌人死亡生命周期测试失败")
		quit(1)
		return

	print("敌人死亡生命周期测试通过")
	quit()


func _expect(condition: bool, description: String) -> void:
	if condition:
		print("[通过] ", description)
		return

	_failed = true
	printerr("[失败] ", description)
