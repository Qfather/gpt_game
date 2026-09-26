extends SceneTree

const MAIN_SCENE: PackedScene = preload("res://Scene/main.tscn")
const ENEMY_SCENE: PackedScene = preload("res://Scene/unit/enemy_base.tscn")
var _failed: bool = false


func _initialize() -> void:
	call_deferred("_run_test")


func _run_test() -> void:
	var main_scene: Node = MAIN_SCENE.instantiate()
	(main_scene.get_node("Systems/MapGenerateRuntime") as MapGenerateRuntime).settlement_seed = 42
	root.add_child(main_scene)
	await process_frame
	for frame: int in range(5):
		await physics_frame
		await process_frame
	var spawn_manager: RaidSpawnManager = main_scene.get_node("Systems/RaidSpawnManager")
	var world_bounds: WorldBounds = main_scene.get_node("Systems/WorldBounds")
	var runtime: MapGenerateRuntime = main_scene.get_node("Systems/MapGenerateRuntime") as MapGenerateRuntime
	var base: Node3D = get_first_node_in_group("bases") as Node3D
	var rift: RiftManager = main_scene.get_node("Systems/RiftManager") as RiftManager
	for attempt: int in range(20):
		var point: Vector3 = rift._find_safe_rift_position(world_bounds.get_world_bounds(), world_bounds.get_settlement_bounds(), world_bounds.get_settlement_center())
		_expect(point != Vector3.INF, "裂缝没有找到合适远端陆地")
		if point != Vector3.INF:
			_expect(Vector2(point.x - base.global_position.x, point.z - base.global_position.z).length() >= rift.minimum_base_distance, "裂缝突破距据点下限")
	rift.minimum_base_distance = 10000.0
	_expect(rift._find_safe_rift_position(world_bounds.get_world_bounds(), world_bounds.get_settlement_bounds(), Vector3.ZERO) == Vector3.INF, "无远端点时错误回退到据点附近")
	rift.minimum_base_distance = main_scene.level_preset.rift_min_base_distance
	var points: Array[Vector3] = spawn_manager._get_rift_spawn_points(
		Vector3(14.5, 0.5, 0.0),
		30,
		world_bounds
	)
	var minimum_distance: float = INF
	var minimum_height: float = INF
	var maximum_height: float = -INF
	for index: int in range(points.size()):
		_expect(Vector2(points[index].x - base.global_position.x, points[index].z - base.global_position.z).length() >= rift.minimum_base_distance, "裂缝怪物出生点突破距据点下限")
		var ground: Vector3 = runtime.get_safe_ground_position(Vector2(points[index].x, points[index].z))
		_expect(ground != Vector3.INF, "敌人出生点不在通向据点的安全地面")
		_expect(is_equal_approx(points[index].y, ground.y + 0.6), "敌人出生高度未匹配地图与胶囊中心")
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
	var enemy: Node = ENEMY_SCENE.instantiate()
	var collision_shape: CollisionShape3D = enemy.get_node("CollisionShape3D")
	_expect(collision_shape.shape is CapsuleShape3D, "敌人碰撞体使用竖直胶囊，避免球形碰撞互相爬升")
	if collision_shape.shape is CapsuleShape3D:
		_expect(is_equal_approx((collision_shape.shape as CapsuleShape3D).radius, 0.48), "敌人碰撞半径缩小至原始模型尺度的0.8倍")
	enemy.free()
	main_scene.queue_free()
	print("裂缝出生布局测试", "失败" if _failed else "通过")
	quit(1 if _failed else 0)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		push_error("失败：" + message)
