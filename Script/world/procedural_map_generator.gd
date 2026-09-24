extends Node3D
class_name ProceduralMapGenerator

const TREE_SCENE: PackedScene = preload("res://Scene/resource/tree.tscn")
const STONE_SCENE: PackedScene = preload("res://Scene/resource/stone.tscn")
const SEA_LEVEL: float = -0.22
const GRID_STEP: float = 0.35
const RESOURCE_CLEARANCE: float = 1.2

@export var config: MapGenerationConfig = preload("res://data/world/MapGeneration_V0.tres")
@export var world_bounds_path: NodePath = ^"../WorldBounds"
@export var navigation_region_path: NodePath = ^"../NavigationRegion3D"
@export var build_grid_path: NodePath = ^"../BuildGrid"

var _rng := RandomNumberGenerator.new()
var _resource_rng := RandomNumberGenerator.new()
var _lakes: Array[Vector3] = []
var _lake_positions: Array[Vector2] = []
var _resource_points: Array[Vector3] = []
var _map_base_position: Vector2 = Vector2.ZERO


func _ready() -> void:
	NavigationServer3D.set_debug_enabled(false)
	if config == null:
		push_error("ProceduralMapGenerator 缺少地图配置")
		return
	add_to_group("procedural_map_generator")
	_rng.seed = config.seed
	_resource_rng.seed = config.resource_seed
	_position_base()
	_map_base_position = _get_base_position_2d()
	_generate_lakes()
	_generate_resources()
	_build_terrain()
	_build_ocean()
	_build_navigation()
	_sync_world_bounds()
	_configure_build_grid()
	_hide_authored_map()
	print("地图生成完成：seed=", config.seed, " 湖泊=", _lakes.size(), " 资源点=", _resource_points.size())


func _generate_lakes() -> void:
	_lakes.clear()
	_lake_positions.clear()
	var lake_points := MapGenerationGeometry.generate_lakes(config, _map_base_position, _rng)
	for point in lake_points:
		_lake_positions.append(point)
		_lakes.append(Vector3(point.x, 0.0, point.y))


func _position_base() -> void:
	var base := get_tree().get_first_node_in_group("bases") as Node3D
	if base == null:
		return
	var candidate := Vector3(config.base_position.x, 0.08, config.base_position.y)
	if not _is_land(candidate, 2.5):
		push_warning("据点位置不在可放置的平缓岛屿区域内，保留场景中的原位置")
		return
	base.global_position = candidate


func _generate_resources() -> void:
	_resource_points.clear()
	var resource_root := Node3D.new()
	resource_root.name = "GeneratedResources"
	add_child(resource_root)
	var land_area := MapGenerationGeometry.estimate_land_area(config, _lake_positions)
	var tree_count := MapGenerationGeometry.resource_count_for_density(land_area, config.tree_density, 8.0)
	_spawn_resource_clusters(resource_root, TREE_SCENE, tree_count, config.trees_per_cluster, 3.0, true)
	var stone_count := MapGenerationGeometry.resource_count_for_density(land_area, config.stone_density, 5.0)
	_spawn_resource_clusters(resource_root, STONE_SCENE, stone_count, config.stones_per_cluster, 3.5, false)


func _spawn_resource_clusters(root: Node3D, scene: PackedScene, item_count: int, per_cluster: int, spread: float, is_tree: bool) -> void:
	var base := _get_base_position()
	var cluster_count := int(ceil(float(item_count) / float(per_cluster)))
	var remaining := item_count
	for cluster_index in range(cluster_count):
		if remaining <= 0:
			break
		var center := Vector3.ZERO
		var found := false
		for attempt in range(100):
			var candidate := Vector3(
				_resource_rng.randf_range(-config.island_size.x * 0.44, config.island_size.x * 0.44),
				0.0,
				_resource_rng.randf_range(-config.island_size.y * 0.44, config.island_size.y * 0.44)
			)
			if _is_resource_position_valid(candidate, base):
				center = candidate
				found = true
				break
		if not found:
			continue
		var cluster_items := mini(per_cluster, remaining)
		for resource_index in range(cluster_items):
			var point := Vector3.ZERO
			var point_found := false
			for point_attempt in range(30):
				var offset := Vector3(_resource_rng.randf_range(-spread, spread), 0.0, _resource_rng.randf_range(-spread, spread))
				var candidate := center + offset
				if _is_resource_position_valid(candidate, base):
					point = candidate
					point_found = true
					break
			if not point_found:
				continue
			var instance := scene.instantiate() as Node3D
			if instance == null:
				continue
			root.add_child(instance)
			instance.global_position = Vector3(point.x, _height_at(point.x, point.z), point.z)
			if is_tree:
				instance.rotation.y = _resource_rng.randf_range(0.0, TAU)
			_resource_points.append(instance.global_position)
			remaining -= 1


func _is_resource_position_valid(point: Vector3, base: Vector3) -> bool:
	if not _is_land(point, 1.0) or point.distance_to(base) < 6.5:
		return false
	if MapGenerationGeometry.lake_clearance(config, _lake_positions, Vector2(point.x, point.z)) < 1.5:
		return false
	for used in _resource_points:
		if Vector2(point.x - used.x, point.z - used.z).length() < RESOURCE_CLEARANCE:
			return false
	return true


func _build_terrain() -> void:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	var half := config.island_size * 0.5
	var x_steps := int(ceil(config.island_size.x / GRID_STEP))
	var z_steps := int(ceil(config.island_size.y / GRID_STEP))
	for z in range(z_steps + 1):
		for x in range(x_steps + 1):
			var px := -half.x + float(x) * GRID_STEP
			var pz := -half.y + float(z) * GRID_STEP
			var point := Vector3(px, 0.0, pz)
			var land := _is_land(point, 0.0)
			var lake := _lake_at(point)
			var height := _height_at(px, pz) if land and not lake else SEA_LEVEL
			vertices.append(Vector3(px, height, pz))
			var slope_x := _height_at(px - 0.1, pz) - _height_at(px + 0.1, pz)
			var slope_z := _height_at(px, pz - 0.1) - _height_at(px, pz + 0.1)
			normals.append(Vector3(slope_x, 0.2, slope_z).normalized())
			var shore := _edge_distance(point)
			colors.append(Color(0.72, 0.66, 0.43) if shore < 0.10 else Color(0.25, 0.48, 0.20))
	for z in range(z_steps):
		for x in range(x_steps):
			var cell_start := Vector2(-half.x + float(x) * GRID_STEP, -half.y + float(z) * GRID_STEP)
			var cell_has_only_land := true
			for corner_offset: Vector2 in [Vector2.ZERO, Vector2(GRID_STEP, 0.0), Vector2(0.0, GRID_STEP), Vector2(GRID_STEP, GRID_STEP)]:
				var corner := cell_start + corner_offset
				if not MapGenerationGeometry.is_land(config, corner) or MapGenerationGeometry.lake_contains(config, _lake_positions, corner):
					cell_has_only_land = false
					break
			if not cell_has_only_land:
				continue
			var a := z * (x_steps + 1) + x
			var b := a + 1
			var c := a + x_steps + 1
			var d := c + 1
			indices.append_array(PackedInt32Array([a, c, b, b, c, d]))
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var terrain := MeshInstance3D.new()
	terrain.name = "GeneratedIsland"
	terrain.mesh = mesh
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.roughness = 1.0
	terrain.material_override = material
	add_child(terrain)
	var body := StaticBody3D.new()
	body.name = "TerrainCollision"
	var shape := CollisionShape3D.new()
	shape.shape = mesh.create_trimesh_shape()
	body.add_child(shape)
	terrain.add_child(body)
	_build_lake_surfaces()


func _build_lake_surfaces() -> void:
	for i in range(_lakes.size()):
		var lake := MeshInstance3D.new()
		lake.name = "Lake_%02d" % i
		lake.mesh = MapGenerationGeometry.create_lake_mesh(config, i)
		lake.position = Vector3(_lakes[i].x, SEA_LEVEL + 0.015, _lakes[i].z)
		lake.material_override = _water_material()
		add_child(lake)
	for i in range(config.custom_lakes.size()):
		var lake := MeshInstance3D.new()
		lake.name = "DrawnLake_%02d" % i
		lake.mesh = MapGenerationGeometry.create_custom_lake_mesh(config, i)
		lake.position.y = SEA_LEVEL + 0.015
		lake.material_override = _water_material()
		add_child(lake)


func _build_ocean() -> void:
	var ocean := MeshInstance3D.new()
	ocean.name = "Ocean"
	var mesh := PlaneMesh.new()
	mesh.size = config.island_size * 5.0
	ocean.mesh = mesh
	ocean.position.y = SEA_LEVEL
	ocean.material_override = _water_material()
	add_child(ocean)


func _water_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.12, 0.38, 0.66)
	material.roughness = 0.32
	return material


func _build_navigation() -> void:
	var region := get_node_or_null(navigation_region_path) as NavigationRegion3D
	if region == null:
		return
	var nav := NavigationMesh.new()
	nav.cell_size = 0.5
	nav.cell_height = 0.25
	var half := config.island_size * 0.5
	const NAV_STEP := 0.5
	var steps_x := int(ceil(config.island_size.x / NAV_STEP))
	var steps_z := int(ceil(config.island_size.y / NAV_STEP))
	var vertices := PackedVector3Array()
	var polygons: Array[PackedInt32Array] = []
	for z in range(steps_z):
		for x in range(steps_x):
			var px := -half.x + (float(x) + 0.5) * NAV_STEP
			var pz := -half.y + (float(z) + 0.5) * NAV_STEP
			var center := Vector3(px, 0.0, pz)
			if _near_resource(center):
				continue
			var corners := [
				Vector2(-NAV_STEP * 0.5, -NAV_STEP * 0.5),
				Vector2(NAV_STEP * 0.5, -NAV_STEP * 0.5),
				Vector2(-NAV_STEP * 0.5, NAV_STEP * 0.5),
				Vector2(NAV_STEP * 0.5, NAV_STEP * 0.5)
			]
			var safe_cell := true
			for corner_offset: Vector2 in corners:
				var check_point := Vector2(px + corner_offset.x, pz + corner_offset.y)
				if not MapGenerationGeometry.is_land(config, check_point, 0.12) or MapGenerationGeometry.lake_clearance(config, _lake_positions, check_point) < 0.12:
					safe_cell = false
					break
			if not safe_cell:
				continue
			var start := vertices.size()
			for corner in corners:
				var vx: float = px + corner.x
				var vz: float = pz + corner.y
				vertices.append(Vector3(vx, _height_at(vx, vz) + 0.3, vz))
			polygons.append(PackedInt32Array([start, start + 2, start + 1]))
			polygons.append(PackedInt32Array([start + 1, start + 2, start + 3]))
	nav.vertices = vertices
	for polygon in polygons:
		nav.add_polygon(polygon)
	region.navigation_mesh = nav


func get_safe_ground_position(point: Vector2, clearance: float = 0.75) -> Vector3:
	if not MapGenerationGeometry.is_land(config, point, clearance):
		return Vector3.INF
	if MapGenerationGeometry.lake_clearance(config, _lake_positions, point) < clearance:
		return Vector3.INF
	var ground := Vector3(point.x, _height_at(point.x, point.y) + 0.12, point.y)
	if _near_resource(ground):
		return Vector3.INF
	return ground


func _near_resource(point: Vector3) -> bool:
	for resource in _resource_points:
		if Vector2(point.x - resource.x, point.z - resource.z).length() < 1.35:
			return true
	return false


func _sync_world_bounds() -> void:
	var bounds := get_node_or_null(world_bounds_path)
	if bounds == null:
		return
	if bounds is WorldBounds:
		bounds.world_size = config.island_size
		var bounds_ratio := 0.86
		if config.island_shape == MapGenerationConfig.IslandShape.CIRCLE or config.island_shape == MapGenerationConfig.IslandShape.ELLIPSE:
			bounds_ratio = 0.65
		elif config.island_shape == MapGenerationConfig.IslandShape.TRIANGLE:
			bounds_ratio = 0.25
		bounds.settlement_size = config.island_size * bounds_ratio


func _configure_build_grid() -> void:
	var grid := get_node_or_null(build_grid_path)
	if grid is BuildGrid:
		grid.grid_min = Vector2i(floori(-config.island_size.x * 0.5), floori(-config.island_size.y * 0.5))
		grid.grid_max = Vector2i(ceili(config.island_size.x * 0.5) - 1, ceili(config.island_size.y * 0.5) - 1)
		grid.set_buildability_rule(Callable(self, "_is_grid_cell_buildable"))


func _is_grid_cell_buildable(cell: Vector2i) -> bool:
	var center := Vector3(float(cell.x) + 0.5, 0.0, float(cell.y) + 0.5)
	if not _is_land(center, 0.45):
		return false
	if MapGenerationGeometry.lake_clearance(config, _lake_positions, Vector2(center.x, center.z)) < 0.75:
		return false
	return true


func _hide_authored_map() -> void:
	var region := get_node_or_null(navigation_region_path)
	if region == null:
		return
	var ground := region.get_node_or_null("MeshInstance3D")
	if ground:
		ground.visible = false
	for container_name in ["trees", "Stones"]:
		var container := region.get_node_or_null(container_name)
		if container:
			region.remove_child(container)
			container.queue_free()


func _is_land(point: Vector3, inset: float) -> bool:
	return MapGenerationGeometry.is_land(config, Vector2(point.x, point.z), inset)


func _lake_at(point: Vector3) -> bool:
	return MapGenerationGeometry.lake_contains(config, _lake_positions, Vector2(point.x, point.z))


func _edge_distance(point: Vector3) -> float:
	return MapGenerationGeometry.edge_distance(config, Vector2(point.x, point.z))


func _height_at(x: float, z: float) -> float:
	return MapGenerationGeometry.height_at(config, _lake_positions, _map_base_position, x, z)


func _get_base_position() -> Vector3:
	var base := get_tree().get_first_node_in_group("bases") as Node3D
	if base:
		return base.global_position
	return Vector3.ZERO


func _get_base_position_2d() -> Vector2:
	var base_position := _get_base_position()
	return Vector2(base_position.x, base_position.z)
