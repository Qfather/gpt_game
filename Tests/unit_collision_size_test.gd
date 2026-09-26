extends SceneTree

var failed: bool = false


func _initialize() -> void:
	for entry: Array in [
		["res://Scene/unit/villager.tscn", 0.15, 1.6, 0.3],
		["res://Scene/unit/migrant.tscn", 0.15, 1.6, 0.0],
		["res://Scene/unit/enemy_base.tscn", 0.24, 1.2, 0.48]
	]:
		var unit: CharacterBody3D = load(entry[0]).instantiate() as CharacterBody3D
		var collision: CollisionShape3D = unit.get_node("CollisionShape3D") as CollisionShape3D
		var shape: CapsuleShape3D = collision.shape as CapsuleShape3D
		_expect(is_equal_approx(shape.radius, entry[1]), "实体半径未减半：" + entry[0])
		_expect(is_equal_approx(shape.height, entry[2]), "碰撞高度发生变化：" + entry[0])
		_expect(unit.collision_layer == 2 and unit.collision_mask != 0, "实体碰撞被关闭：" + entry[0])
		if entry[3] > 0.0:
			var click: Area3D = unit.get_node("ClickArea") as Area3D
			var click_shape: CapsuleShape3D = click.get_node("CollisionShape3D").shape as CapsuleShape3D
			_expect(is_equal_approx(click_shape.radius, entry[3]), "点击范围改变：" + entry[0])
			_expect(click.input_event.is_connected(unit._on_input_event), "点击区域没有连接选择事件")
		unit.free()
	print("单位碰撞尺寸测试", "失败" if failed else "通过", "：实体半径减半、高度不变、点击范围保留")
	quit(1 if failed else 0)


func _expect(value: bool, message: String) -> void:
	if not value:
		failed = true
		push_error("失败：" + message)
