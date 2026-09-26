extends SceneTree

var failed: bool = false


func _initialize() -> void:
	call_deferred("_run")


func _expect(value: bool, message: String) -> void:
	if not value:
		failed = true
		push_error("失败：" + message)


func _wait_navigation(runtime: MapGenerateRuntime, revision: int) -> void:
	for frame: int in range(300):
		await physics_frame
		if runtime.navigation_revision > revision:
			break
	for frame: int in range(5):
		await physics_frame
		await process_frame
	_expect(runtime.navigation_revision > revision, "城墙变更未更新导航")


func _run() -> void:
	var scene: Node = load("res://Scene/main.tscn").instantiate()
	var runtime: MapGenerateRuntime = scene.get_node("Systems/MapGenerateRuntime") as MapGenerateRuntime
	runtime.settlement_seed = 42
	root.add_child(scene)
	await process_frame
	await process_frame
	scene.get_node("Villagers").queue_free()
	var base: Node3D = get_first_node_in_group("bases") as Node3D
	var center: Vector3 = base.global_position + Vector3(0, 0, -3)
	var start: Vector3 = center + Vector3(0, 0, -3)
	var finish: Vector3 = center + Vector3(0, 0, 3)
	var revision: int = runtime.navigation_revision
	var wall: Wall = load("res://Scene/building/game/wall.tscn").instantiate() as Wall
	scene.add_child(wall)
	wall.global_position = center
	await _wait_navigation(runtime, revision)
	var map: RID = (scene.get_node("Systems/NavigationRegion3D") as NavigationRegion3D).get_navigation_map()
	var path: PackedVector3Array = NavigationServer3D.map_get_path(map, start, finish, true)
	_expect(path.size() > 2, "建墙后路径仍直穿城墙")
	# 强制直线移动也必须被实体碰撞阻挡。
	var body := CharacterBody3D.new()
	var shape := CollisionShape3D.new()
	shape.shape = CapsuleShape3D.new()
	body.add_child(shape)
	root.add_child(body)
	body.global_position = start + Vector3.UP
	await physics_frame
	var hit: KinematicCollision3D = body.move_and_collide(Vector3(0, 0, 6))
	_expect(hit != null and hit.get_collider() == wall.get_node("StaticBody3D"), "实体移动穿过城墙")
	body.queue_free()
	var target := Node3D.new()
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
	_expect(arrived[0], "移民未实际绕墙抵达")
	migrant.queue_free()
	var enemy: EnemyBase = load("res://Scene/unit/enemy_base.tscn").instantiate() as EnemyBase
	root.add_child(enemy)
	enemy.set_process(false)
	enemy.global_position = start + Vector3.UP * 0.65
	enemy.target = target
	enemy.attack_range = 0.6
	enemy.move_speed = 4.0
	for frame: int in range(600):
		await physics_frame
		if Vector2(enemy.global_position.x - finish.x, enemy.global_position.z - finish.z).length() < 1.0:
			break
	_expect(Vector2(enemy.global_position.x - finish.x, enemy.global_position.z - finish.z).length() < 1.0, "敌人未实际绕墙抵达")
	enemy.queue_free()
	target.queue_free()
	revision = runtime.navigation_revision
	wall.take_damage(1000)
	await _wait_navigation(runtime, revision)
	_expect(not is_instance_valid(wall), "摧毁后仍保留隐形城墙")
	var cleared: PackedVector3Array = NavigationServer3D.map_get_path(map, start, finish, true)
	_expect(not cleared.is_empty() and _length(cleared) < _length(path) - 0.2, "摧毁后未恢复通道")
	wall = load("res://Scene/building/game/wall.tscn").instantiate() as Wall
	revision = runtime.navigation_revision
	scene.add_child(wall)
	wall.global_position = center
	wall.rotation.y = PI * 0.5
	await _wait_navigation(runtime, revision)
	path = NavigationServer3D.map_get_path(map, center + Vector3(-3, 0, 0), center + Vector3(3, 0, 0), true)
	_expect(path.size() > 2, "旋转城墙没有加入导航")
	revision = runtime.navigation_revision
	wall._complete_demolition()
	await _wait_navigation(runtime, revision)
	_expect(not is_instance_valid(wall), "拆除未移除城墙")
	scene.queue_free()
	await process_frame
	print("城墙导航测试", "失败" if failed else "通过", "：实体阻挡、移民/敌人绕行、旋转、摧毁与拆除更新")
	quit(1 if failed else 0)


func _length(path: PackedVector3Array) -> float:
	var result: float = 0.0
	for index: int in range(1, path.size()):
		result += path[index - 1].distance_to(path[index])
	return result
