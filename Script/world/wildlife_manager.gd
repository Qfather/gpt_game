extends Node3D

var config: Resource
var timer: float = 0.0
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	add_to_group("wildlife_manager")
	rng.randomize()

func _process(delta: float) -> void:
	if config == null or not config.enabled: return
	var runtime: MapGenerateRuntime = get_tree().get_first_node_in_group("map_generate_runtime") as MapGenerateRuntime
	if runtime == null or runtime.map_data == null: return
	if NavigationServer3D.map_get_iteration_id(get_world_3d().get_navigation_map()) == 0: return
	timer -= delta
	if timer > 0.0: return
	timer = maxf(config.refresh_interval, 1.0)
	refill()

func refill() -> void:
	var runtime: MapGenerateRuntime = get_tree().get_first_node_in_group("map_generate_runtime") as MapGenerateRuntime
	var base: Node3D = get_tree().get_first_node_in_group("bases") as Node3D
	if runtime == null or base == null or config.prey_pool.is_empty(): return
	var count: int = get_tree().get_nodes_in_group("wildlife").size()
	var total_weight: float = 0.0
	for data: Resource in config.prey_pool:
		if data != null and data.scene != null: total_weight += maxf(data.weight, 0.0)
	if total_weight <= 0.0: return
	for attempt: int in range(100):
		if count >= config.maximum_animals: return
		var angle: float = rng.randf_range(0.0, TAU)
		var radius: float = rng.randf_range(config.minimum_base_distance, config.maximum_base_distance)
		var point: Vector3 = base.global_position + Vector3(cos(angle), 0, sin(angle)) * radius
		point = runtime.get_safe_ground_position(Vector2(point.x, point.z), 0.4)
		if point == Vector3.INF: continue
		var closest: Vector3 = NavigationServer3D.map_get_closest_point(get_world_3d().get_navigation_map(), point)
		if point.distance_to(closest) > 0.5: continue
		var value: float = rng.randf_range(0.0, total_weight)
		for data: Resource in config.prey_pool:
			if data == null or data.scene == null: continue
			value -= maxf(data.weight, 0.0)
			if value > 0.0: continue
			var animal: Node3D = data.scene.instantiate()
			animal.data = data
			add_child(animal)
			animal.global_position = point
			count += 1
			break
