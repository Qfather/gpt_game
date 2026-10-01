class_name CampSpawnManager
extends Node3D

const DEFAULT_SCENE: PackedScene = preload("res://Scene/world/treasure_camp.tscn")

var config: CampSpawnConfig
var rng := RandomNumberGenerator.new()
var next_spawn_time: float = -1.0
var runtime: MapGenerateRuntime
var fog: Node


func _ready() -> void:
	add_to_group("camp_spawn_manager")
	rng.randomize()
	if config != null and config.enabled and not config.validation_error().is_empty():
		push_error("营地配置错误：" + config.validation_error())
		set_process(false)


func _process(_delta: float) -> void:
	if config == null or not config.enabled:
		return
	runtime = get_tree().get_first_node_in_group("map_generate_runtime") as MapGenerateRuntime
	fog = get_tree().get_first_node_in_group("fog_of_war")
	if runtime == null or runtime.map_data == null or fog == null or not fog.initialized:
		return
	if NavigationServer3D.map_get_iteration_id(get_world_3d().get_navigation_map()) == 0:
		return
	var director: EncounterDirector = get_tree().get_first_node_in_group("encounter_director") as EncounterDirector
	if director == null:
		return
	if next_spawn_time < 0.0:
		next_spawn_time = director.elapsed_time + config.first_spawn_time
	if director.elapsed_time >= next_spawn_time:
		try_spawn(director.elapsed_time)
		next_spawn_time = director.elapsed_time + rng.randf_range(config.interval_min, config.interval_max)


func try_spawn(elapsed: float) -> TreasureCamp:
	if config == null or not config.enabled or get_tree().get_nodes_in_group("treasure_camps").size() >= config.maximum_camps:
		return null
	runtime = get_tree().get_first_node_in_group("map_generate_runtime") as MapGenerateRuntime
	fog = get_tree().get_first_node_in_group("fog_of_war")
	if runtime == null or runtime.map_data == null or fog == null or not fog.initialized:
		return null
	var data: TreasureCampData = config.draw_camp(elapsed, rng)
	if data == null or not data.validation_error().is_empty():
		return null
	var plan: Dictionary = data.roll(rng)
	var base: Node3D = get_tree().get_first_node_in_group("bases") as Node3D
	if base == null:
		return null
	var scene: PackedScene = data.scene if data.scene != null else DEFAULT_SCENE
	var instance: Node = scene.instantiate()
	if not instance is TreasureCamp:
		instance.free()
		push_error("营地场景根节点必须使用 TreasureCamp：" + data.display_name)
		return null
	var camp: TreasureCamp = instance as TreasureCamp
	var chest: Node3D = camp.get_node_or_null("Chest") as Node3D
	var chest_offset: Vector3 = chest.position if chest != null else Vector3.ZERO
	var cells: Array[Vector2i] = runtime.map_data.occupied_cells.duplicate()
	# 使用独立随机源，固定种子可以复现整个营地布局。
	for index: int in range(cells.size() - 1, 0, -1):
		var other: int = rng.randi_range(0, index)
		var previous: Vector2i = cells[index]
		cells[index] = cells[other]
		cells[other] = previous
	for cell: Vector2i in cells:
		var position: Vector3 = runtime._cell_world_position(cell)
		var distance: float = Vector2(position.x - base.global_position.x, position.z - base.global_position.z).length()
		if distance < config.minimum_base_distance or distance > config.maximum_base_distance:
			continue
		if not is_valid_site(position, data.footprint_radius):
			continue
		var guard_positions: Array[Vector3] = _find_guard_positions(position, data.footprint_radius, plan["guards"].size(), chest_offset)
		if guard_positions.size() != plan["guards"].size():
			continue
		camp.configure_camp(data, plan, guard_positions, elapsed)
		camp.position = to_local(position)
		add_child(camp)
		fog.refresh_visibility()
		print("宝箱营地生成：", camp.display_name, "，位置=", position, "，守卫=", camp.guards.size())
		return camp
	camp.free()
	return null


func is_valid_site(position: Vector3, radius: float) -> bool:
	if fog == null or not fog.initialized or fog.is_area_visible(position, radius):
		return false
	if runtime.get_safe_ground_position(Vector2(position.x, position.z), radius) == Vector3.INF:
		return false
	for camp: Node3D in get_tree().get_nodes_in_group("treasure_camps"):
		if Vector2(camp.global_position.x - position.x, camp.global_position.z - position.z).length() < radius + float(camp.get("footprint_radius")) + config.camp_spacing:
			return false
	# 整片占地必须有同高度、可站立的导航地面，不能跨海岸或悬崖。
	var navigation_map: RID = get_world_3d().get_navigation_map()
	for x: int in range(-ceili(radius), ceili(radius) + 1):
		for z: int in range(-ceili(radius), ceili(radius) + 1):
			var offset := Vector3(x, 0.0, z)
			if Vector2(x, z).length() > radius:
				continue
			var point: Vector3 = position + offset
			var nearest: Vector3 = NavigationServer3D.map_get_closest_point(navigation_map, point)
			if Vector2(nearest.x - point.x, nearest.z - point.z).length() > 0.4 or absf(nearest.y - point.y) > 0.5:
				return false
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = 1.2
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis.IDENTITY, position + Vector3.UP * 1.2)
	query.collision_mask = 1
	return get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()


func _find_guard_positions(center: Vector3, radius: float, count: int, chest_offset: Vector3 = Vector3.ZERO) -> Array[Vector3]:
	var result: Array[Vector3] = []
	var candidates: Array[Vector3] = []
	var navigation_map: RID = get_world_3d().get_navigation_map()
	var rotation: float = rng.randf_range(0.0, TAU)
	# 守卫站位按实际世界坐标布局，不受3米地形格大小限制。
	for index: int in range(24):
		var angle: float = rotation + TAU * index / 24.0
		var desired: Vector3 = center + Vector3(cos(angle), 0.0, sin(angle)) * (radius - 0.8)
		var point: Vector3 = NavigationServer3D.map_get_closest_point(navigation_map, desired)
		if chest_offset != Vector3.ZERO and point.distance_to(center + chest_offset) < 1.4:
			continue
		if point.distance_to(desired) <= 0.5:
			candidates.append(point)
	while not candidates.is_empty() and result.size() < count:
		var index: int = rng.randi_range(0, candidates.size() - 1)
		# 后续守卫优先选择离已有守卫最远的环形站位，避免都挤在篝火一侧。
		var best_distance: float = -1.0
		if not result.is_empty():
			for candidate_index: int in range(candidates.size()):
				var distance: float = INF
				for previous: Vector3 in result:
					distance = minf(distance, previous.distance_to(candidates[candidate_index]))
				if distance > best_distance:
					best_distance = distance
					index = candidate_index
		var point: Vector3 = candidates[index]
		candidates.remove_at(index)
		var free: bool = true
		for previous: Vector3 in result:
			if previous.distance_to(point) < 1.2:
				free = false
		if free:
			result.append(point)
	return result
