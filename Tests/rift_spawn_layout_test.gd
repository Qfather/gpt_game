extends SceneTree

const MAIN_SCENE: PackedScene = preload("res://Scene/main.tscn")
const ENEMY_SCENE: PackedScene = preload("res://Scene/unit/enemy_base.tscn")


func _initialize() -> void:
	call_deferred("_run_test")


func _run_test() -> void:
	var main_scene: Node = MAIN_SCENE.instantiate()
	root.add_child(main_scene)
	await process_frame
	await physics_frame
	await physics_frame
	var spawn_manager: RaidSpawnManager = main_scene.get_node("Systems/RaidSpawnManager")
	var world_bounds: WorldBounds = main_scene.get_node("Systems/WorldBounds")
	var points: Array[Vector3] = spawn_manager._get_rift_spawn_points(
		Vector3(14.5, 0.5, 0.0),
		30,
		world_bounds
	)
	var minimum_distance: float = INF
	var minimum_height: float = INF
	var maximum_height: float = -INF
	for index: int in range(points.size()):
		minimum_height = minf(minimum_height, points[index].y)
		maximum_height = maxf(maximum_height, points[index].y)
		for other_index: int in range(index + 1, points.size()):
			var distance: float = Vector2(
				points[index].x - points[other_index].x,
				points[index].z - points[other_index].z
			).length()
			minimum_distance = minf(minimum_distance, distance)
	print("裂缝30单位出生点：数量=%d 最小间距=%.2f 高度范围=%.2f..%.2f" % [
		points.size(), minimum_distance, minimum_height, maximum_height
	])
	_expect(points.size() == 30, "按实际怪物数量生成足够的独立位置")
	_expect(minimum_distance >= 1.1, "导航投影后出生点仍保持安全间距")
	_expect(minimum_height <= 1.0, "出生点不能投影到高处导航面")
	var enemy: Node = ENEMY_SCENE.instantiate()
	var collision_shape: CollisionShape3D = enemy.get_node("CollisionShape3D")
	_expect(collision_shape.shape is CapsuleShape3D, "敌人碰撞体使用竖直胶囊，避免球形碰撞互相爬升")
	if collision_shape.shape is CapsuleShape3D:
		_expect(is_equal_approx((collision_shape.shape as CapsuleShape3D).radius, 0.48), "敌人碰撞半径缩小至原始模型尺度的0.8倍")
	enemy.free()
	main_scene.queue_free()
	print("裂缝出生布局测试通过")
	quit()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		push_error("失败：" + message)
		quit(1)
