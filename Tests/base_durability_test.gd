extends SceneTree


func _init() -> void:
	var base_scene: PackedScene = preload("res://Scene/building/base.tscn")
	var base: Node = base_scene.instantiate()
	get_root().add_child(base)
	await process_frame
	_expect(is_equal_approx(base.get_max_health(), 1000.0), "Base 初始最大生命正确")
	base.take_damage(100.0)
	_expect(is_equal_approx(base.get_health(), 900.0), "Base 可以受到伤害")
	base.repair(50.0)
	_expect(is_equal_approx(base.get_health(), 950.0), "Base 可以修复")
	print("Base Durability 接入测试通过")
	quit()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		push_error("失败：" + message)
		quit(1)
