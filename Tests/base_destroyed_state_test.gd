extends SceneTree


func _init() -> void:
	var base_scene: PackedScene = preload("res://Scene/building/base.tscn")
	var base: Node = base_scene.instantiate()
	get_root().add_child(base)
	await process_frame
	base.take_damage(1000.0)
	_expect(base.is_destroyed(), "Base 生命归零后进入摧毁状态")
	_expect(not base.visible, "Base 被摧毁后隐藏")
	var click_area: CollisionObject3D = base.get_node("ClickArea") as CollisionObject3D
	_expect(click_area.collision_layer == 0, "Base 被摧毁后关闭点击碰撞层")
	print("Base Destroyed V0 测试通过")
	quit()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		push_error("失败：" + message)
		quit(1)
