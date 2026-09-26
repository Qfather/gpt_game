extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene: Node = load("res://Scene/main.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await process_frame
	await process_frame
	var population: PopulationManager = get_first_node_in_group("population_manager") as PopulationManager
	var map_runtime: MapGenerateRuntime = get_first_node_in_group("map_generate_runtime") as MapGenerateRuntime
	var base: Node3D = get_first_node_in_group("bases") as Node3D
	population._spawn_migrant_group(2)
	var migrants: Array[Node] = scene.get_node("Migrants").get_children()
	_expect(migrants.size() == 2, "移民没有生成两人")
	var initial_distances: Array[float] = []
	for migrant_node: Node in migrants:
		var migrant: Node3D = migrant_node as Node3D
		var position: Vector3 = migrant.global_position
		initial_distances.append(position.distance_to(base.global_position))
		var ground: Vector3 = map_runtime.get_safe_ground_position(Vector2(position.x, position.z), 1.0)
		_expect(ground != Vector3.INF, "移民不在安全陆地上")
		_expect(is_equal_approx(position.y, ground.y), "移民在地图地面下方")
	await create_timer(0.6).timeout
	var moving_count: int = 0
	for index: int in range(migrants.size()):
		var migrant: Node3D = migrants[index] as Node3D
		if is_instance_valid(migrant) and migrant.global_position.distance_to(base.global_position) < initial_distances[index] - 0.1:
			moving_count += 1
	_expect(moving_count == 2, "有移民出生后没有向 Base 移动")
	print("移民地图出生测试通过：人数=", migrants.size(), " 地面高度=", (migrants[0] as Node3D).global_position.y)
	quit()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		push_error("失败：" + message)
		quit(1)
