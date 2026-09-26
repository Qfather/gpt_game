extends SceneTree

const VILLAGER_SCRIPT = preload("res://Script/unit/game/villager.gd")

var _failed: bool = false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene: Node = load("res://Scene/main.tscn").instantiate()
	var runtime: MapGenerateRuntime = scene.get_node("Systems/MapGenerateRuntime") as MapGenerateRuntime
	runtime.settlement_seed = 42
	root.add_child(scene)
	await process_frame
	await process_frame
	scene.get_node("Villagers").queue_free()
	var base: Node3D = get_first_node_in_group("bases") as Node3D
	var center: Vector3 = base.global_position + Vector3(0.0, 0.0, -3.0)
	var resources: Node3D = runtime.get_node("GeneratedResources") as Node3D
	_expect(runtime._place_resource_at(resources, runtime.TREE_SCENE, center, null), "测试树放置失败")
	var tree: ResourceBase = resources.get_child(resources.get_child_count() - 1) as ResourceBase
	runtime._build_navigation()
	for frame: int in range(60):
		await physics_frame
	var region: NavigationRegion3D = scene.get_node("Systems/NavigationRegion3D") as NavigationRegion3D
	var navigation_map: RID = region.get_navigation_map()
	_expect(region.navigation_mesh.get_polygon_count() > 0, "导航烘焙结果为空")
	var start: Vector3 = center + Vector3(-5.0, 0.0, 0.0)
	var finish: Vector3 = center + Vector3(5.0, 0.0, 0.0)
	var gather_point: Vector3 = tree.get_gather_position(start, navigation_map)
	_expect(gather_point.is_finite() and gather_point.x < center.x, "采集点未选择居民近侧")
	var opposite_point: Vector3 = tree.get_gather_position(finish, navigation_map)
	_expect(opposite_point.is_finite() and opposite_point.x > center.x, "采集点固定在资源同一侧")
	var worker: CharacterBody3D = load("res://Scene/unit/villager.tscn").instantiate() as CharacterBody3D
	root.add_child(worker)
	worker.set_physics_process(false)
	worker.global_position = start
	worker.target_resource = tree
	worker.state = VILLAGER_SCRIPT.State.MOVE_TO_RESOURCE
	worker.navigation_agent.target_position = gather_point
	for frame: int in range(300):
		await physics_frame
		worker.move_to_resource()
		if worker.state == VILLAGER_SCRIPT.State.GATHER_RESOURCE:
			break
	_expect(worker.state == VILLAGER_SCRIPT.State.GATHER_RESOURCE, "居民未实际抵达采集范围")
	_expect(worker.global_position.x < center.x, "居民绕到了树的背面采集")
	worker.queue_free()
	var blocked_path: PackedVector3Array = NavigationServer3D.map_get_path(navigation_map, start, finish, true)
	_expect(blocked_path.size() > 2, "路径没有绕开挡路树")
	for index: int in range(1, blocked_path.size()):
		var closest: Vector2 = Geometry2D.get_closest_point_to_segment(Vector2(center.x, center.z), Vector2(blocked_path[index - 1].x, blocked_path[index - 1].z), Vector2(blocked_path[index].x, blocked_path[index].z))
		_expect(closest.distance_to(Vector2(center.x, center.z)) >= 1.0, "路径穿过树木碰撞及单位余量")
	var target: Node3D = Node3D.new()
	root.add_child(target)
	target.global_position = finish
	var migrant: Migrant = load("res://Scene/unit/migrant.tscn").instantiate() as Migrant
	root.add_child(migrant)
	migrant.global_position = start
	var arrived: Array[bool] = [false]
	migrant.arrived.connect(func(_unit: Node3D, _base: Node3D) -> void: arrived[0] = true)
	migrant.setup(target)
	for frame: int in range(600):
		await physics_frame
		if arrived[0]:
			break
	_expect(arrived[0] and migrant.global_position.distance_to(finish) < 1.7, "移民没有实际绕树抵达目标")
	# 即使路径结束，远离真正目标也不能误报移民抵达。
	migrant._arrival_notified = false
	target.global_position = finish + Vector3(100.0, 0.0, 0.0)
	_expect(not migrant._has_arrived(), "路径结束被误判为实际抵达")
	migrant.queue_free()
	target.global_position = finish
	var enemy: EnemyBase = load("res://Scene/unit/enemy_base.tscn").instantiate() as EnemyBase
	root.add_child(enemy)
	enemy.set_process(false)
	enemy.global_position = start + Vector3.UP * 0.65
	enemy.target = target
	enemy.attack_range = 0.6
	enemy.move_speed = 4.0
	for frame: int in range(600):
		await physics_frame
		if Vector2(enemy.global_position.x, enemy.global_position.z).distance_to(Vector2(finish.x, finish.z)) < 1.0:
			break
	_expect(Vector2(enemy.global_position.x, enemy.global_position.z).distance_to(Vector2(finish.x, finish.z)) < 1.0, "敌人没有实际绕树抵达目标")
	enemy.queue_free()
	var previous_revision: int = runtime.navigation_revision
	tree.gather(tree.resource_amount)
	for frame: int in range(300):
		await physics_frame
		if runtime.navigation_revision > previous_revision:
			break
	for frame: int in range(5):
		await physics_frame
	_expect(runtime.navigation_revision > previous_revision, "采集后未更新导航")
	_expect(not runtime._resource_points.has(center), "采集后仍保留资源占位")
	var cleared_path: PackedVector3Array = NavigationServer3D.map_get_path(navigation_map, start, finish, true)
	_expect(not cleared_path.is_empty(), "采集后路径丢失")
	_expect(_length(cleared_path) < _length(blocked_path) - 0.2, "采集后没有开放更短的道路")
	var high_start: Vector3 = Vector3.INF
	var shortest: float = INF
	for cell: Vector2i in runtime.map_data.occupied_cells:
		if runtime.height_field.get_cell_surface_height(cell) < 1.0:
			continue
		var position: Vector3 = runtime._cell_world_position(cell)
		var safe_position: Vector3 = runtime.get_safe_ground_position(Vector2(position.x, position.z))
		if safe_position == Vector3.INF:
			continue
		var path: PackedVector3Array = NavigationServer3D.map_get_path(navigation_map, safe_position, base.global_position, true)
		if not path.is_empty() and _length(path) < shortest:
			shortest = _length(path)
			high_start = safe_position
	_expect(high_start != Vector3.INF, "高台没有连到据点的安全出生点")
	if high_start != Vector3.INF:
		target.global_position = base.global_position
		var high_migrant: Migrant = load("res://Scene/unit/migrant.tscn").instantiate() as Migrant
		root.add_child(high_migrant)
		high_migrant.global_position = high_start
		high_migrant.move_speed = 6.0
		var high_arrived: Array[bool] = [false]
		high_migrant.arrived.connect(func(_unit: Node3D, _base: Node3D) -> void: high_arrived[0] = true)
		high_migrant.setup(target)
		for frame: int in range(900):
			await physics_frame
			if high_arrived[0]:
				break
		_expect(high_arrived[0], "高台移民未经过坡道抵达低地据点")
		print("高台移民测试：起点=", high_start, " 终点=", high_migrant.global_position, " 路程=", shortest)
		high_migrant.queue_free()
		var high_enemy: EnemyBase = load("res://Scene/unit/enemy_base.tscn").instantiate() as EnemyBase
		root.add_child(high_enemy)
		high_enemy.set_process(false)
		high_enemy.global_position = high_start + Vector3.UP * 0.6
		high_enemy.target = target
		high_enemy.attack_range = 0.6
		high_enemy.move_speed = 6.0
		for frame: int in range(900):
			await physics_frame
			if Vector2(high_enemy.global_position.x - target.global_position.x, high_enemy.global_position.z - target.global_position.z).length() < 1.0:
				break
		_expect(high_enemy.global_position.distance_to(target.global_position) < 1.3, "高台敌人未经过坡道抵达低地目标")
		high_enemy.queue_free()
	print("资源导航测试", "失败" if _failed else "通过", "：绕树路径=", _length(blocked_path), " 清除后=", _length(cleared_path), " 移民/敌人实走、采集更新与抵达判定")
	scene.queue_free()
	target.queue_free()
	await process_frame
	quit(1 if _failed else 0)


func _length(path: PackedVector3Array) -> float:
	var result: float = 0.0
	for index: int in range(1, path.size()):
		result += path[index - 1].distance_to(path[index])
	return result


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		push_error("失败：" + message)
