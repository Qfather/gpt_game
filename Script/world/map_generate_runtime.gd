class_name MapGenerateRuntime
extends Node3D

const DEMO_SCENE: PackedScene = preload("res://addons/MapGenerate/demo/demo.tscn")
const TREE_SCENE: PackedScene = preload("res://Scene/resource/tree.tscn")
const STONE_SCENE: PackedScene = preload("res://Scene/resource/stone.tscn")
const BASE_RANDOM_MAP_SIZE := Vector2i(3, 3)
const STONE_CLUSTER_SIZE := 5
const RESOURCE_CLUSTER_RADIUS := 1
const TREE_SPACING := 1.1
const STONE_SPACING := 3.8

@export var level_config: WFCLevelConfig = preload("res://data/world/MapGenerateLevel_V0.tres")
@export var tree_count: int = 72
@export var stone_count: int = 10
@export var world_bounds_path: NodePath = ^"../WorldBounds"
@export var navigation_region_path: NodePath = ^"../NavigationRegion3D"
@export var build_grid_path: NodePath = ^"../BuildGrid"

var map_data: WFCMapData
var height_field: WFCHeightField
var _terrain_demo: Node
var _resource_points: Array[Vector3] = []
var _resource_rng := RandomNumberGenerator.new()


func _ready() -> void:
	add_to_group("map_generate_runtime")
	_clear_authored_map()
	_resource_rng.seed = level_config.seed_value + 7919
	map_data = level_config.generate_map()
	if map_data == null:
		push_error("MapGenerate 关卡配置生成地图失败")
		return
	height_field = map_data.create_height_field()
	_place_base()
	_terrain_demo = DEMO_SCENE.instantiate()
	_terrain_demo.set("level_config", null)
	_terrain_demo.set("map_outline", map_data)
	_terrain_demo.name = "GeneratedTerrain"
	add_child(_terrain_demo)
	_hide_demo_only_nodes()
	await get_tree().process_frame
	_spawn_resources()
	_build_navigation()
	_sync_world_bounds()
	_configure_build_grid()
	print("MapGenerate 地图完成：尺寸=", map_data.map_size, "单格尺寸=", map_data.cell_size_m, "中心空地=", map_data.generation_center_clear_size, "格子=", map_data.occupied_cells.size(), "资源=", _resource_points.size())


func _hide_demo_only_nodes() -> void:
	for node_name: String in ["地面", "相机", "太阳光"]:
		var node: Node = _terrain_demo.get_node_or_null(node_name)
		if node != null:
			node.queue_free()
	var demo_ui: Node = _terrain_demo.get_node_or_null("CanvasLayer")
	if demo_ui != null:
		demo_ui.queue_free()


func _clear_authored_map() -> void:
	var region: NavigationRegion3D = get_node_or_null(navigation_region_path) as NavigationRegion3D
	if region == null:
		return
	for container_name: String in ["trees", "Stones"]:
		var container: Node = region.get_node_or_null(container_name)
		if container != null:
			container.queue_free()
	var authored_mesh: Node = region.get_node_or_null("MeshInstance3D")
	if authored_mesh != null:
		authored_mesh.queue_free()


func _place_base() -> void:
	var base: Node3D = get_tree().get_first_node_in_group("bases") as Node3D
	if base == null or map_data.occupied_cells.is_empty():
		return
	var base_area_min := Vector2i(map_data.map_size.x / 2 - BASE_RANDOM_MAP_SIZE.x / 2, map_data.map_size.y / 2 - BASE_RANDOM_MAP_SIZE.y / 2)
	var base_candidates: Array[Vector2i] = []
	for cell: Vector2i in map_data.occupied_cells:
		if cell.x >= base_area_min.x and cell.x < base_area_min.x + BASE_RANDOM_MAP_SIZE.x and cell.y >= base_area_min.y and cell.y < base_area_min.y + BASE_RANDOM_MAP_SIZE.y:
			base_candidates.append(cell)
	if base_candidates.is_empty():
		base_candidates = map_data.occupied_cells
	var selected_index: int = _resource_rng.randi_range(0, base_candidates.size() - 1)
	var selected_cell: Vector2i = base_candidates[selected_index]
	base.global_position = _cell_world_position(selected_cell)
	print("MapGenerate Base随机位置：地图格=", selected_cell, "世界位置=", base.global_position)


func _spawn_resources() -> void:
	var resource_root: Node3D = Node3D.new()
	resource_root.name = "GeneratedResources"
	add_child(resource_root)
	var available: Array[Vector2i] = map_data.occupied_cells.duplicate()
	var base: Node3D = get_tree().get_first_node_in_group("bases") as Node3D
	for cell: Vector2i in available.duplicate():
		var corners: Array[float] = height_field.get_cell_corners(cell)
		if not (is_equal_approx(corners[0], corners[1]) and is_equal_approx(corners[0], corners[2]) and is_equal_approx(corners[0], corners[3])):
			available.erase(cell)
	_spawn_forest(resource_root, available, base)
	_spawn_resource_type(resource_root, available, STONE_SCENE, stone_count, STONE_CLUSTER_SIZE, base)


func _spawn_forest(root: Node3D, available: Array[Vector2i], base: Node3D) -> void:
	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.seed = level_config.seed_value + 104729
	noise.frequency = 0.09
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	var grove_center: Vector3 = Vector3.ZERO
	if base != null:
		var angle: float = _resource_rng.randf_range(0.0, TAU)
		grove_center = base.global_position + Vector3(cos(angle), 0.0, sin(angle)) * 12.0
	var candidates: Array[Vector2i] = available.duplicate()
	var planted_positions: Array[Vector3] = []
	var spawned: int = 0
	var attempts: int = 0
	while spawned < tree_count and not candidates.is_empty() and attempts < tree_count * 100:
		attempts += 1
		if not planted_positions.is_empty() and _resource_rng.randf() < 0.8:
			var parent: Vector3 = planted_positions[_resource_rng.randi_range(0, planted_positions.size() - 1)]
			var direction: float = _resource_rng.randf_range(0.0, TAU)
			var position: Vector3 = parent + Vector3(cos(direction), 0.0, sin(direction)) * _resource_rng.randf_range(TREE_SPACING, 1.8)
			var half_size: Vector2 = Vector2(map_data.map_size) * map_data.cell_size_m * 0.5
			var child_cell: Vector2i = Vector2i(floori((position.x + half_size.x) / map_data.cell_size_m), floori((position.z + half_size.y) / map_data.cell_size_m))
			if available.has(child_cell):
				position.y = _cell_world_position(child_cell).y
				if _place_resource_at(root, available, TREE_SCENE, child_cell, position, base):
					spawned += 1
					planted_positions.append(position)
			continue
		var weights: Array[float] = []
		var total_weight: float = 0.0
		for cell: Vector2i in candidates:
			var noise_density: float = smoothstep(0.05, 0.55, noise.get_noise_2d(float(cell.x), float(cell.y)))
			var grove_density: float = 0.0
			if base != null:
				grove_density = pow(maxf(0.0, 1.0 - _horizontal_distance(_cell_world_position(cell), grove_center) / 21.0), 2.0)
			var weight: float = 0.01 + noise_density * noise_density * 3.0 + grove_density * 5.0
			weights.append(weight)
			total_weight += weight
		var roll: float = _resource_rng.randf() * total_weight
		var selected_index: int = candidates.size() - 1
		for index: int in range(candidates.size()):
			roll -= weights[index]
			if roll <= 0.0:
				selected_index = index
				break
		var cell: Vector2i = candidates[selected_index]
		if _try_place_resource(root, available, TREE_SCENE, cell, base):
			spawned += 1
			planted_positions.append(_resource_points[_resource_points.size() - 1])
		else:
			candidates.remove_at(selected_index)


func _spawn_resource_type(root: Node3D, available: Array[Vector2i], scene: PackedScene, count: int, cluster_size: int, base: Node3D) -> void:
	var spawned: int = 0
	var centers: Array[Vector2i] = available.duplicate()
	while spawned < count and not centers.is_empty():
		var center_index: int = _resource_rng.randi_range(0, centers.size() - 1)
		var center: Vector2i = centers[center_index]
		centers.remove_at(center_index)
		var nearby: Array[Vector2i] = []
		for cell: Vector2i in available:
			if maxi(abs(cell.x - center.x), abs(cell.y - center.y)) <= RESOURCE_CLUSTER_RADIUS:
				nearby.append(cell)
		var in_cluster: int = 0
		while spawned < count and in_cluster < cluster_size and not nearby.is_empty():
			var selected_index: int = _resource_rng.randi_range(0, nearby.size() - 1)
			var cell: Vector2i = nearby[selected_index]
			nearby.remove_at(selected_index)
			if _try_place_resource(root, available, scene, cell, base):
				spawned += 1
				in_cluster += 1


func _try_place_resource(root: Node3D, available: Array[Vector2i], scene: PackedScene, cell: Vector2i, base: Node3D) -> bool:
	var position: Vector3 = _cell_world_position(cell)
	var jitter: float = map_data.cell_size_m * 0.5 - (0.6 if scene == TREE_SCENE else 1.1)
	position.x += _resource_rng.randf_range(-jitter, jitter)
	position.z += _resource_rng.randf_range(-jitter, jitter)
	return _place_resource_at(root, available, scene, cell, position, base)


func _place_resource_at(root: Node3D, available: Array[Vector2i], scene: PackedScene, cell: Vector2i, position: Vector3, base: Node3D) -> bool:
	if base != null and _horizontal_distance(position, base.global_position) < 6.5:
		return false
	var spacing: float = TREE_SPACING if scene == TREE_SCENE else STONE_SPACING
	for other: Vector3 in _resource_points:
		if _horizontal_distance(position, other) < spacing:
			return false
	var instance: Node3D = scene.instantiate() as Node3D
	root.add_child(instance)
	instance.global_position = position
	instance.rotation.y = _resource_rng.randf_range(0.0, TAU)
	_resource_points.append(position)
	if scene != TREE_SCENE:
		available.erase(cell)
	return true


func _horizontal_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z))


func _build_navigation() -> void:
	var region: NavigationRegion3D = get_node_or_null(navigation_region_path) as NavigationRegion3D
	if region == null:
		return
	var navigation_mesh: NavigationMesh = NavigationMesh.new()
	var vertices: PackedVector3Array = PackedVector3Array()
	var polygons: Array[PackedInt32Array] = []
	for cell: Vector2i in map_data.occupied_cells:
		var position: Vector3 = _cell_world_position(cell)
		var start: int = vertices.size()
		var half_cell: float = map_data.cell_size_m * 0.5
		vertices.append(position + Vector3(-half_cell, 0.0, -half_cell))
		vertices.append(position + Vector3(-half_cell, 0.0, half_cell))
		vertices.append(position + Vector3(half_cell, 0.0, -half_cell))
		vertices.append(position + Vector3(half_cell, 0.0, half_cell))
		polygons.append(PackedInt32Array([start, start + 1, start + 2]))
		polygons.append(PackedInt32Array([start + 2, start + 1, start + 3]))
	navigation_mesh.vertices = vertices
	for polygon: PackedInt32Array in polygons:
		navigation_mesh.add_polygon(polygon)
	region.enabled = false
	region.navigation_mesh = navigation_mesh
	region.enabled = true


func _sync_world_bounds() -> void:
	var bounds: Node = get_node_or_null(world_bounds_path)
	if bounds == null:
		return
	if bounds is WorldBounds:
		var size: Vector2 = Vector2(map_data.map_size) * map_data.cell_size_m
		bounds.world_size = size
		bounds.settlement_size = size * 0.86


func _configure_build_grid() -> void:
	var grid: BuildGrid = get_node_or_null(build_grid_path) as BuildGrid
	if grid == null:
		return
	var half_size: Vector2i = Vector2i(roundi(float(map_data.map_size.x) * map_data.cell_size_m * 0.5), roundi(float(map_data.map_size.y) * map_data.cell_size_m * 0.5))
	grid.grid_min = Vector2i(-half_size.x, -half_size.y)
	grid.grid_max = Vector2i(half_size.x - 1, half_size.y - 1)
	grid.set_buildability_rule(Callable(self, "_is_grid_cell_buildable"))
	grid.set_ground_height_rule(Callable(self, "_get_grid_ground_height"))


func _is_grid_cell_buildable(grid_cell: Vector2i) -> bool:
	var map_cell: Vector2i = _grid_to_map_cell(grid_cell)
	if not map_data.has_cell(map_cell):
		return false
	var corners: Array[float] = height_field.get_cell_corners(map_cell)
	return is_equal_approx(corners[0], corners[1]) and is_equal_approx(corners[0], corners[2]) and is_equal_approx(corners[0], corners[3])


func _get_grid_ground_height(grid_cell: Vector2i) -> float:
	var map_cell: Vector2i = _grid_to_map_cell(grid_cell)
	if not map_data.has_cell(map_cell):
		return 0.0
	return (height_field.get_cell_surface_height(map_cell) + WFCHeightControl.LEVEL_HEIGHT) * map_data.cell_size_m


func _grid_to_map_cell(grid_cell: Vector2i) -> Vector2i:
	var half_size: Vector2i = Vector2i(roundi(float(map_data.map_size.x) * map_data.cell_size_m * 0.5), roundi(float(map_data.map_size.y) * map_data.cell_size_m * 0.5))
	return Vector2i(
		floori(float(grid_cell.x + half_size.x) / map_data.cell_size_m),
		floori(float(grid_cell.y + half_size.y) / map_data.cell_size_m)
	)


func _cell_world_position(cell: Vector2i) -> Vector3:
	var half_size: Vector2 = Vector2(map_data.map_size) * map_data.cell_size_m * 0.5
	var height: float = (height_field.get_cell_surface_height(cell) + WFCHeightControl.LEVEL_HEIGHT) * map_data.cell_size_m if height_field != null else 0.0
	return Vector3((float(cell.x) + 0.5) * map_data.cell_size_m - half_size.x, height, (float(cell.y) + 0.5) * map_data.cell_size_m - half_size.y)


func get_safe_ground_position(point: Vector2, clearance: float = 0.75) -> Vector3:
	if map_data == null or height_field == null:
		return Vector3.INF
	var half_size: Vector2 = Vector2(map_data.map_size) * map_data.cell_size_m * 0.5
	var cell: Vector2i = Vector2i(floori((point.x + half_size.x) / map_data.cell_size_m), floori((point.y + half_size.y) / map_data.cell_size_m))
	if not map_data.has_cell(cell):
		return Vector3.INF
	var position: Vector3 = _cell_world_position(cell)
	for resource_position: Vector3 in _resource_points:
		if resource_position.distance_to(position) < clearance + 1.0:
			return Vector3.INF
	return position
