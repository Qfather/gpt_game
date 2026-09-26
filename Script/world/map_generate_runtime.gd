class_name MapGenerateRuntime
extends Node3D

const DEMO_SCENE: PackedScene = preload("res://addons/MapGenerate/demo/demo.tscn")
const TREE_SCENE: PackedScene = preload("res://Scene/resource/tree.tscn")
const STONE_SCENE: PackedScene = preload("res://Scene/resource/stone.tscn")

# 由主场景的统一关卡预设注入，不再单独配置第二份地图资源。
var level_config: WFCLevelConfig
var resource_entries: Array[MapResourceEntry] = []
var _active_resource: MapResourceEntry
var _terrain_features: Dictionary = {}
var _resource_specs: Dictionary = {}
var _point_spacings: Dictionary = {}
var _scene_outlines: Dictionary = {}
var _scene_circles: Dictionary = {}
var _point_geometry: Dictionary = {}
var _resource_passages: Array[Rect2] = []
var tree_count: int:
	get:
		return _scene_count(TREE_SCENE)
var stone_count: int:
	get:
		return _scene_count(STONE_SCENE)


func _scene_count(scene: PackedScene) -> int:
	var total: int = 0
	for entry: MapResourceEntry in resource_entries:
		if entry != null and entry.enabled and entry.scene == scene:
			total += entry.count
	return total
## -1 每局随机；指定非负值可复现据点与资源布局，不改变地形种子。
@export var settlement_seed: int = -1
@export var world_bounds_path: NodePath = ^"../WorldBounds"
@export var navigation_region_path: NodePath = ^"../NavigationRegion3D"
@export var build_grid_path: NodePath = ^"../BuildGrid"

var map_data: WFCMapData
var height_field: WFCHeightField
var _terrain_demo: Node
var _resource_points: Array[Vector3] = []
var _resource_rng := RandomNumberGenerator.new()
var _visual_rng := RandomNumberGenerator.new()
# 地图格 -> Vector2(树木权重, 石头权重)。
var _resource_terrain_weights: Dictionary = {}
var _cliff_foot_distances: Dictionary = {}
var _cliff_top_distances: Dictionary = {}
var generation_timings_ms: Dictionary = {}
var _cell_positions: Dictionary = {}
var _navigation_faces: PackedVector3Array = PackedVector3Array()
var _navigation_dirty: bool = false
var _navigation_update_queued: bool = false
var _navigation_baking: bool = false
var navigation_revision: int = 0


func _ready() -> void:
	var started: int = Time.get_ticks_msec()
	add_to_group("map_generate_runtime")
	if level_config == null:
		push_error("地图生成缺少关卡预设中的地图配置")
		return
	_clear_authored_map()
	if settlement_seed < 0:
		_resource_rng.randomize()
		_resource_rng.seed = _resource_rng.randi()
	else:
		_resource_rng.seed = settlement_seed
	print("据点资源布局种子：", _resource_rng.seed)
	_visual_rng.seed = _resource_rng.seed
	map_data = level_config.generate_map()
	generation_timings_ms["地形数据"] = Time.get_ticks_msec() - started
	if map_data == null:
		push_error("MapGenerate 关卡配置生成地图失败")
		return
	height_field = map_data.create_height_field()
	_cell_positions.clear()
	var stage_started: int = Time.get_ticks_msec()
	if not _place_base():
		return
	generation_timings_ms["据点选址"] = Time.get_ticks_msec() - stage_started
	stage_started = Time.get_ticks_msec()
	_terrain_demo = DEMO_SCENE.instantiate()
	_terrain_demo.set("level_config", null)
	_terrain_demo.set("map_outline", map_data)
	_terrain_demo.name = "GeneratedTerrain"
	add_child(_terrain_demo)
	_hide_demo_only_nodes()
	generation_timings_ms["地形模型"] = Time.get_ticks_msec() - stage_started
	await get_tree().process_frame
	stage_started = Time.get_ticks_msec()
	_spawn_resources()
	generation_timings_ms["资源生成"] = Time.get_ticks_msec() - stage_started
	stage_started = Time.get_ticks_msec()
	_build_navigation()
	_sync_world_bounds()
	_configure_build_grid()
	var camera: GameCameraController = get_viewport().get_camera_3d() as GameCameraController
	var base: Node3D = get_tree().get_first_node_in_group("bases") as Node3D
	if camera != null and base != null:
		camera.set_island_bounds(map_data.occupied_cells, map_data.map_size, map_data.cell_size_m)
		camera.focus_on_position(base.global_position)
	generation_timings_ms["导航与网格"] = Time.get_ticks_msec() - stage_started
	generation_timings_ms["总计"] = Time.get_ticks_msec() - started
	print("地图初始化耗时（毫秒）：", generation_timings_ms)
	print("MapGenerate 地图完成：尺寸=", map_data.map_size, "单格尺寸=", map_data.cell_size_m, "中心空地=", map_data.generation_center_clear_size, "格子=", map_data.occupied_cells.size(), "资源=", _resource_points.size())


func _hide_demo_only_nodes() -> void:
	for node_name: String in ["地面", "相机", "太阳光"]:
		var node: Node = _terrain_demo.get_node_or_null(node_name)
		if node != null:
			node.queue_free()
	# 插件动态创建的层可能叫 @CanvasLayer@...，不能按固定名称查找。
	for child: Node in _terrain_demo.get_children():
		if child is CanvasLayer:
			(child as CanvasLayer).hide()
			child.queue_free()


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


func _place_base() -> bool:
	var base: Node3D = get_tree().get_first_node_in_group("bases") as Node3D
	if base == null or map_data.occupied_cells.is_empty():
		return false
	var base_candidates: Array[Vector2i] = []
	for cell: Vector2i in map_data.occupied_cells:
		if _is_safe_base_cell(cell):
			base_candidates.append(cell)
	if base_candidates.is_empty():
		push_error("中心平地没有安全的据点落点，请扩大中心平地")
		return false
	var selected_index: int = _resource_rng.randi_range(0, base_candidates.size() - 1)
	var selected_cell: Vector2i = base_candidates[selected_index]
	base.global_position = _cell_world_position(selected_cell)
	base.global_position += Vector3(_resource_rng.randf_range(-0.25, 0.25), 0.0, _resource_rng.randf_range(-0.25, 0.25)) * map_data.cell_size_m
	# 据点占地 2×3 个 1m 游戏格，中心对齐后才能精确登记六格占地。
	base.global_position.x = roundf(base.global_position.x)
	base.global_position.z = floorf(base.global_position.z) + 0.5
	print("MapGenerate Base随机位置：地图格=", selected_cell, "世界位置=", base.global_position)
	return true


func _is_safe_base_cell(cell: Vector2i) -> bool:
	var center: Vector2 = (Vector2(map_data.map_size) - Vector2.ONE) * 0.5
	var offset: Vector2 = Vector2(cell) - center
	# 预留一格边缘余量，覆盖当前 3m 据点和格内随机偏移。
	var extent: float = float(map_data.generation_center_clear_size) * (1.0 if map_data.generation_center_clear_circle else 0.5) - 1.0
	if map_data.generation_center_clear_circle:
		if offset.length() > extent:
			return false
	elif maxf(absf(offset.x), absf(offset.y)) > extent:
		return false
	var height: float = height_field.get_cell_surface_height(cell)
	for y: int in range(-1, 2):
		for x: int in range(-1, 2):
			var neighbor: Vector2i = cell + Vector2i(x, y)
			if not map_data.has_cell(neighbor) or height_field.has_control(neighbor, WFCHeightControl.Kind.STAIRS):
				return false
			for corner: float in height_field.get_cell_corners(neighbor):
				if not is_equal_approx(corner, height):
					return false
	return true


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
	_build_resource_terrain_weights(available)
	_build_resource_passages()
	for cell: Vector2i in available.duplicate():
		if not _resource_terrain_weights.has(cell) or _overlaps_resource_passage(_cell_world_position(cell), 0.0):
			available.erase(cell)
	for entry: MapResourceEntry in resource_entries:
		if entry == null or not entry.enabled or entry.count == 0:
			continue
		entry.migrate_spacing()
		var error: String = entry.validation_error()
		if not error.is_empty():
			push_error("地图资源配置错误：" + entry.display_name + "：" + error)
			continue
		_active_resource = entry
		if not _prepare_resource_spec(entry):
			continue
		var suitable: Array[Vector2i] = []
		for cell: Vector2i in available:
			if _terrain_weight(cell) > 0.0:
				suitable.append(cell)
		if entry.distribution == 0:
			_spawn_forest(resource_root, suitable, base)
		else:
			var nearby: int = ceili(float(entry.count) * entry.nearby_ratio)
			_spawn_resource_type(resource_root, suitable, entry.scene, nearby, entry.cluster_size, base, true)
			_spawn_resource_type(resource_root, suitable, entry.scene, entry.count - nearby, entry.cluster_size, base, false)
	_active_resource = null


func _build_resource_passages() -> void:
	_resource_passages.clear()
	var size: float = map_data.cell_size_m
	for cell: Vector2i in map_data.occupied_cells:
		var corners: Array[float] = height_field.get_cell_corners(cell)
		var slope: bool = height_field.has_control(cell, WFCHeightControl.Kind.STAIRS)
		for height: float in corners:
			slope = slope or not is_equal_approx(height, corners[0])
		var narrow: bool = false
		# 地形连接带宽度不超过两格时，保留完整通行带。
		for axis: Vector2i in [Vector2i.RIGHT, Vector2i.DOWN]:
			var width: int = 1
			for sign_value: int in [-1, 1]:
				for step: int in range(1, 3):
					if not map_data.has_cell(cell + axis * sign_value * step):
						break
					width += 1
			narrow = narrow or width <= 2
		if not slope and not narrow:
			continue
		var center: Vector3 = _cell_world_position(cell)
		var rect := Rect2(Vector2(center.x, center.z) - Vector2.ONE * size * 0.5, Vector2.ONE * size)
		# 坡道两端预留一格出入口；窄连接带边缘留出导航半径。
		_resource_passages.append(rect.grow(size if slope else 0.75))


func _overlaps_resource_passage(position: Vector3, radius: float) -> bool:
	var point := Vector2(position.x, position.z)
	for passage: Rect2 in _resource_passages:
		if passage.grow(radius).has_point(point):
			return true
	return false


func _prepare_resource_spec(entry: MapResourceEntry) -> bool:
	var instance: Node = entry.scene.instantiate()
	var collision: CollisionShape3D = instance.get_node_or_null("StaticBody3D/CollisionShape3D") as CollisionShape3D
	if not instance is ResourceBase or collision == null or collision.shape == null:
		push_error("地图资源场景需要 ResourceBase 和 StaticBody3D/CollisionShape3D：" + entry.display_name)
		instance.free()
		return false
	var bounds: AABB = collision.transform * collision.shape.get_debug_mesh().get_aabb()
	if collision.get_parent() is Node3D:
		bounds = (collision.get_parent() as Node3D).transform * bounds
	var extent := Vector2(maxf(absf(bounds.position.x), absf(bounds.end.x)), maxf(absf(bounds.position.z), absf(bounds.end.z)))
	var radius: float = extent.length()
	if collision.shape is CylinderShape3D:
		radius = maxf(extent.x, extent.y)
	var support_radius: float = radius + 0.05 if collision.shape is CylinderShape3D else ceilf(radius * 100.0) / 100.0
	_resource_specs[entry.scene] = Vector2(support_radius, radius)
	var outline := PackedVector2Array()
	var shape_bounds: AABB = collision.shape.get_debug_mesh().get_aabb()
	var shape_transform: Transform3D = (collision.get_parent() as Node3D).transform * collision.transform
	for x: float in [shape_bounds.position.x, shape_bounds.end.x]:
		for y: float in [shape_bounds.position.y, shape_bounds.end.y]:
			for z: float in [shape_bounds.position.z, shape_bounds.end.z]:
				var point: Vector3 = shape_transform * Vector3(x, y, z)
				outline.append(Vector2(point.x, point.z))
	_scene_outlines[entry.scene] = Geometry2D.convex_hull(outline)
	_scene_circles[entry.scene] = collision.shape is CylinderShape3D and shape_transform.basis.y.normalized().is_equal_approx(Vector3.UP) and is_equal_approx(extent.x, extent.y) and is_zero_approx(bounds.get_center().x) and is_zero_approx(bounds.get_center().z)
	instance.free()
	return true


func _geometry(scene: PackedScene, position: Vector3, yaw: float) -> Dictionary:
	var center := Vector2(position.x, position.z)
	var spec: Vector2 = _resource_specs[scene]
	return {"center": center, "radius": spec.y, "circle": _scene_circles[scene], "outline": ResourceSpacing.transformed(_scene_outlines[scene], center, yaw)}


func _edge_gap(a: Dictionary, b: Dictionary) -> float:
	if a.circle and b.circle:
		return maxf(0.0, (a.center as Vector2).distance_to(b.center) - float(a.radius) - float(b.radius))
	if a.circle:
		return ResourceSpacing.circle_gap(a.center, a.radius, b.outline)
	if b.circle:
		return ResourceSpacing.circle_gap(b.center, b.radius, a.outline)
	return ResourceSpacing.gap(a.outline, b.outline)


func _neighbor_candidate(parent: Vector3, angle: float) -> Vector4:
	var yaw: float = _resource_rng.randf_range(0.0, TAU)
	var gap: float = _resource_rng.randf_range(_active_resource.minimum_spacing, _active_resource.neighbor_distance_max) + 0.001
	var previous: Dictionary = _point_geometry[parent]
	var spec: Vector2 = _resource_specs[_active_resource.scene]
	var direction := Vector3(cos(angle), 0.0, sin(angle))
	var lower: float = 0.0
	var upper: float = float(previous.radius) + spec.y + gap
	if not (previous.circle and _scene_circles[_active_resource.scene]):
		# 求沿该方向达到边缘留空的中心距离，旋转方形不能按固定直径推进。
		for iteration: int in range(12):
			var middle: float = (lower + upper) * 0.5
			if _edge_gap(previous, _geometry(_active_resource.scene, parent + direction * middle, yaw)) < gap:
				lower = middle
			else:
				upper = middle
	var point: Vector3 = parent + direction * upper
	return Vector4(point.x, point.y, point.z, yaw)


func _terrain_weight(cell: Vector2i) -> float:
	var features: Vector3 = _terrain_features[cell]
	return maxf(0.0, _active_resource.base_weight + features.x * _active_resource.altitude_weight + features.y * _active_resource.cliff_foot_bonus + features.z * _active_resource.cliff_top_bonus)


func _build_resource_terrain_weights(cells: Array[Vector2i]) -> void:
	_resource_terrain_weights.clear()
	_terrain_features.clear()
	var level_counts: Array[int] = [0, 0, 0, 0]
	var tree_totals: Array[float] = [0.0, 0.0, 0.0, 0.0]
	var stone_totals: Array[float] = [0.0, 0.0, 0.0, 0.0]
	var cliff_foot_count: int = 0
	var cliff_top_count: int = 0
	var flat_heights: Dictionary = {}
	var cliff_foot_cells: Array[Vector2i] = []
	var cliff_top_cells: Array[Vector2i] = []
	for cell: Vector2i in cells:
		var cell_corners: Array[float] = height_field.get_cell_corners(cell)
		if height_field.has_control(cell, WFCHeightControl.Kind.STAIRS) or not (is_equal_approx(cell_corners[0], cell_corners[1]) and is_equal_approx(cell_corners[0], cell_corners[2]) and is_equal_approx(cell_corners[0], cell_corners[3])):
			continue
		var height: float = height_field.get_cell_surface_height(cell)
		flat_heights[cell] = height
		var level: int = clampi(roundi(height / WFCHeightControl.LEVEL_HEIGHT), 0, WFCHeightControl.MAX_LEVEL)
		var cliff_foot: bool = false
		var cliff_top: bool = false
		for neighbor: Vector2i in [cell + Vector2i.UP, cell + Vector2i.RIGHT, cell + Vector2i.DOWN, cell + Vector2i.LEFT]:
			if not map_data.has_cell(neighbor) or height_field.has_control(neighbor, WFCHeightControl.Kind.STAIRS):
				continue
			var corners: Array[float] = height_field.get_cell_corners(neighbor)
			if not (is_equal_approx(corners[0], corners[1]) and is_equal_approx(corners[0], corners[2]) and is_equal_approx(corners[0], corners[3])):
				continue
			var height_difference: float = corners[0] - height
			if height_difference >= WFCHeightControl.LEVEL_HEIGHT:
				cliff_foot = true
			elif height_difference <= -WFCHeightControl.LEVEL_HEIGHT:
				cliff_top = true
		# 使用插件的海拔层，不把地图模型的整体缩放当作层数。
		var tree_weight: float = 1.2 - 0.1 * float(level) + (0.6 if cliff_foot else 0.0)
		var stone_weight: float = 0.7 + 0.25 * float(level) + (1.0 if cliff_foot else 0.0) + (0.4 if cliff_top else 0.0)
		_resource_terrain_weights[cell] = Vector2(tree_weight, stone_weight)
		_terrain_features[cell] = Vector3(level, 1.0 if cliff_foot else 0.0, 1.0 if cliff_top else 0.0)
		level_counts[level] += 1
		tree_totals[level] += tree_weight
		stone_totals[level] += stone_weight
		if cliff_foot:
			cliff_foot_count += 1
			cliff_foot_cells.append(cell)
		if cliff_top:
			cliff_top_count += 1
			cliff_top_cells.append(cell)
	_cliff_foot_distances = _measure_cliff_distances(cliff_foot_cells, flat_heights)
	_cliff_top_distances = _measure_cliff_distances(cliff_top_cells, flat_heights)
	for level: int in range(level_counts.size()):
		if level_counts[level] > 0:
			print("地形参考权重（默认树/石）：海拔层=", level, " 平地=", level_counts[level], " 树均权=", snappedf(tree_totals[level] / float(level_counts[level]), 0.01), " 石均权=", snappedf(stone_totals[level] / float(level_counts[level]), 0.01))
	print("资源地形权重：崖脚平地=", cliff_foot_count, " 崖顶平地=", cliff_top_count)


func _measure_cliff_distances(edge_cells: Array[Vector2i], flat_heights: Dictionary) -> Dictionary:
	# 沿同海拔平地的四邻格距离，单位为米；相邻崖缘从半格算起。
	# 未收录的格子在该平地范围内没有对应崖缘，不是距离为零。
	var distances: Dictionary = {}
	var queue: Array[Vector2i] = edge_cells.duplicate()
	for cell: Vector2i in edge_cells:
		distances[cell] = map_data.cell_size_m * 0.5
	var index: int = 0
	while index < queue.size():
		var cell: Vector2i = queue[index]
		index += 1
		for neighbor: Vector2i in [cell + Vector2i.UP, cell + Vector2i.RIGHT, cell + Vector2i.DOWN, cell + Vector2i.LEFT]:
			if not flat_heights.has(neighbor) or distances.has(neighbor):
				continue
			if not is_equal_approx(float(flat_heights[cell]), float(flat_heights[neighbor])):
				continue
			distances[neighbor] = float(distances[cell]) + map_data.cell_size_m
			queue.append(neighbor)
	return distances


func _spawn_forest(root: Node3D, available: Array[Vector2i], base: Node3D) -> void:
	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.seed = int(_resource_rng.seed % 2147483647)
	noise.frequency = 0.09
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	var grove_centers: Array[Vector3] = []
	if base != null:
		var angle: float = _resource_rng.randf_range(0.0, TAU)
		for index: int in range(3):
			var direction: float = angle + float(index) * TAU / 3.0 + _resource_rng.randf_range(-0.2, 0.2)
			grove_centers.append(base.global_position + Vector3(cos(direction), 0.0, sin(direction)) * _resource_rng.randf_range(_active_resource.near_distance_min, _active_resource.near_distance_max))
	var nearby_count: int = ceili(float(_active_resource.count) * _active_resource.nearby_ratio)
	_grow_forest(root, available, base, grove_centers, noise, nearby_count)
	var distant_cells: Array[Vector2i] = []
	var highland_cells: Array[Vector2i] = []
	for cell: Vector2i in available:
		if base != null and _horizontal_distance(_cell_world_position(cell), base.global_position) < _active_resource.far_distance_min:
			continue
		distant_cells.append(cell)
		if height_field.get_cell_surface_height(cell) > 0.0:
			highland_cells.append(cell)
	var distant_centers: Array[Vector3] = []
	var center_candidates: Array[Vector2i] = distant_cells.duplicate()
	# 有可用高台时先为其安排一片林地，其余林区按树木权重分散选择。
	for index: int in range(4):
		var pool: Array[Vector2i] = highland_cells if index == 0 and not highland_cells.is_empty() else center_candidates
		if pool.is_empty():
			break
		var selected: Vector2i = pool[_pick_resource_cell(pool)]
		var center: Vector3 = _cell_world_position(selected)
		distant_centers.append(center)
		for cell: Vector2i in center_candidates.duplicate():
			if _horizontal_distance(_cell_world_position(cell), center) < _active_resource.cluster_separation:
				center_candidates.erase(cell)
	_grow_forest(root, distant_cells, base, distant_centers, noise, _active_resource.count - nearby_count)


func _grow_forest(root: Node3D, available: Array[Vector2i], base: Node3D, grove_centers: Array[Vector3], noise: FastNoiseLite, count: int) -> void:
	var candidates: Array[Vector2i] = available.duplicate()
	# 格子中心的密度与地形权重在本次生成中不变，只计算一次。
	var cell_weights: Dictionary = {}
	for cell: Vector2i in candidates:
		cell_weights[cell] = _terrain_weight(cell) * _forest_density(_cell_world_position(cell), grove_centers, noise)
	var planted_positions: Array[Vector3] = []
	var spawned: int = 0
	var attempts: int = 0
	while spawned < count and not candidates.is_empty() and attempts < count * 100:
		attempts += 1
		if not planted_positions.is_empty() and _resource_rng.randf() < 0.8:
			var parent: Vector3 = planted_positions[_resource_rng.randi_range(0, planted_positions.size() - 1)]
			var direction: float = _resource_rng.randf_range(0.0, TAU)
			var candidate: Vector4 = _neighbor_candidate(parent, direction)
			var position := Vector3(candidate.x, candidate.y, candidate.z)
			var half_size: Vector2 = Vector2(map_data.map_size) * map_data.cell_size_m * 0.5
			var child_cell: Vector2i = Vector2i(floori((position.x + half_size.x) / map_data.cell_size_m), floori((position.z + half_size.y) / map_data.cell_size_m))
			if available.has(child_cell):
				if _resource_rng.randf() > minf(1.0, _terrain_weight(child_cell) * _forest_density(position, grove_centers, noise)):
					continue
				position.y = _cell_world_position(child_cell).y
				if _place_resource_at(root, _active_resource.scene, position, base, candidate.w):
					spawned += 1
					planted_positions.append(position)
			continue
		var weights: Array[float] = []
		var total_weight: float = 0.0
		for cell: Vector2i in candidates:
			var weight: float = cell_weights[cell]
			weights.append(weight)
			total_weight += weight
		if total_weight <= 0.0:
			break
		var roll: float = _resource_rng.randf() * total_weight
		var selected_index: int = candidates.size() - 1
		for index: int in range(candidates.size()):
			roll -= weights[index]
			if roll <= 0.0:
				selected_index = index
				break
		var cell: Vector2i = candidates[selected_index]
		if _try_place_resource(root, _active_resource.scene, cell, base):
			spawned += 1
			planted_positions.append(_resource_points[_resource_points.size() - 1])
		else:
			candidates.remove_at(selected_index)
	print("树林生成：目标=", count, " 实际=", spawned, " 林区=", grove_centers.size())
	if spawned < count:
		push_warning("树林可用位置不足，保留实际数量，不强行重叠生成")


func _forest_density(position: Vector3, centers: Array[Vector3], noise: FastNoiseLite) -> float:
	var density: float = 0.0
	for center: Vector3 in centers:
		density = maxf(density, pow(maxf(0.0, 1.0 - _horizontal_distance(position, center) / _active_resource.cluster_radius), 1.5))
	var variation: float = (noise.get_noise_2d(position.x, position.z) + 1.0) * 0.5
	return _active_resource.scattered_weight + density * (0.6 + variation * 1.4)


func _pick_resource_cell(cells: Array[Vector2i]) -> int:
	var total: float = 0.0
	for cell: Vector2i in cells:
		total += _terrain_weight(cell)
	var roll: float = _resource_rng.randf() * total
	for index: int in range(cells.size()):
		roll -= _terrain_weight(cells[index])
		if roll <= 0.0:
			return index
	return cells.size() - 1


func _spawn_resource_type(root: Node3D, available: Array[Vector2i], scene: PackedScene, count: int, cluster_size: int, base: Node3D, near_base: bool) -> void:
	var spawned: int = 0
	var centers: Array[Vector2i] = available.duplicate()
	if base != null:
		for cell: Vector2i in centers.duplicate():
			var distance: float = _horizontal_distance(_cell_world_position(cell), base.global_position)
			if (near_base and (distance < _active_resource.near_distance_min or distance > _active_resource.near_distance_max)) or (not near_base and distance < _active_resource.far_distance_min):
				centers.erase(cell)
	while spawned < count and not centers.is_empty():
		var center_index: int = _pick_resource_cell(centers)
		var center: Vector2i = centers[center_index]
		centers.remove_at(center_index)
		if not _try_place_resource(root, scene, center, base):
			continue
		spawned += 1
		var members: Array[Vector3] = [_resource_points.back()]
		for other: Vector2i in centers.duplicate():
			if _horizontal_distance(_cell_world_position(other), members[0]) < _active_resource.cluster_separation:
				centers.erase(other)
		var attempts: int = 0
		var half_size: Vector2 = Vector2(map_data.map_size) * map_data.cell_size_m * 0.5
		while spawned < count and members.size() < cluster_size and attempts < cluster_size * 40:
			attempts += 1
			var parent: Vector3 = members[_resource_rng.randi_range(0, members.size() - 1)]
			var angle: float = _resource_rng.randf_range(0.0, TAU)
			var candidate: Vector4 = _neighbor_candidate(parent, angle)
			var position := Vector3(candidate.x, candidate.y, candidate.z)
			if _horizontal_distance(position, members[0]) > _active_resource.cluster_radius:
				continue
			var cell: Vector2i = Vector2i(floori((position.x + half_size.x) / map_data.cell_size_m), floori((position.z + half_size.y) / map_data.cell_size_m))
			if not available.has(cell) or not is_equal_approx(_cell_world_position(cell).y, members[0].y):
				continue
			if _place_resource_at(root, scene, position, base, candidate.w):
				spawned += 1
				members.append(position)
	print(_active_resource.display_name, "近处" if near_base else "远处", "生成：目标=", count, " 实际=", spawned)
	if spawned < count:
		push_warning("石群可用位置不足，保留实际数量，不强行重叠生成")


func _try_place_resource(root: Node3D, scene: PackedScene, cell: Vector2i, base: Node3D) -> bool:
	var position: Vector3 = _cell_world_position(cell)
	var jitter: float = map_data.cell_size_m * 0.5 - 0.01
	position.x += _resource_rng.randf_range(-jitter, jitter)
	position.z += _resource_rng.randf_range(-jitter, jitter)
	return _place_resource_at(root, scene, position, base)


func _place_resource_at(root: Node3D, scene: PackedScene, position: Vector3, base: Node3D, yaw: float = NAN) -> bool:
	if not _resource_specs.has(scene):
		return false
	var spec: Vector2 = _resource_specs[scene]
	var radius: float = spec.x
	if _overlaps_resource_passage(position, radius):
		return false
	var half_size: Vector2 = Vector2(map_data.map_size) * map_data.cell_size_m * 0.5
	for offset: Vector2 in [Vector2(-radius, -radius), Vector2(radius, -radius), Vector2(-radius, radius), Vector2(radius, radius)]:
		var probe: Vector2 = Vector2(position.x, position.z) + offset
		var probe_cell: Vector2i = Vector2i(floori((probe.x + half_size.x) / map_data.cell_size_m), floori((probe.y + half_size.y) / map_data.cell_size_m))
		if not _resource_terrain_weights.has(probe_cell) or not is_equal_approx(_cell_world_position(probe_cell).y, position.y):
			return false
	if base != null and _horizontal_distance(position, base.global_position) < 6.5:
		return false
	if is_nan(yaw):
		yaw = _resource_rng.randf_range(0.0, TAU)
	var spacing: float = _active_resource.minimum_spacing if _active_resource != null else 0.0
	var geometry: Dictionary = _geometry(scene, position, yaw)
	for other: Vector3 in _resource_points:
		var required: float = maxf(spacing, float(_point_spacings[other])) + 0.0001
		var previous: Dictionary = _point_geometry[other]
		if _horizontal_distance(position, other) >= spec.y + float(previous.radius) + required:
			continue
		if _edge_gap(geometry, previous) < required:
			return false
	var instance: Node3D = scene.instantiate() as Node3D
	if instance is ResourceBase:
		(instance as ResourceBase).visual_seed = _visual_rng.randi()
	root.add_child(instance)
	instance.global_position = position
	instance.rotation.y = yaw
	_resource_points.append(position)
	_point_spacings[position] = spacing
	_point_geometry[position] = geometry
	instance.tree_exiting.connect(_on_resource_removed.bind(position))
	return true


func _horizontal_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z))


func _build_navigation() -> void:
	var region: NavigationRegion3D = get_node_or_null(navigation_region_path) as NavigationRegion3D
	if region == null:
		return
	_navigation_faces.clear()
	for cell: Vector2i in map_data.occupied_cells:
		var position: Vector3 = _cell_world_position(cell)
		var half_cell: float = map_data.cell_size_m * 0.5
		var corners: Array[float] = height_field.get_cell_corners(cell)
		var vertices: PackedVector3Array = PackedVector3Array()
		for offset: Vector2 in [Vector2(-half_cell, -half_cell), Vector2(half_cell, -half_cell), Vector2(half_cell, half_cell), Vector2(-half_cell, half_cell)]:
			var height: float = (corners[vertices.size()] + WFCHeightControl.LEVEL_HEIGHT) * map_data.cell_size_m
			vertices.append(Vector3(position.x + offset.x, height, position.z + offset.y))
		for index: int in [0, 1, 3, 1, 2, 3]:
			_navigation_faces.append(vertices[index])
	var navigation_mesh: NavigationMesh = _new_navigation_mesh()
	NavigationServer3D.bake_from_source_geometry_data(navigation_mesh, _navigation_geometry())
	region.navigation_mesh = navigation_mesh
	region.enabled = true
	navigation_revision += 1


func _new_navigation_mesh() -> NavigationMesh:
	var mesh: NavigationMesh = NavigationMesh.new()
	mesh.cell_size = 0.25
	mesh.cell_height = 0.25
	# 当前最大普通单位（史莱姆）碰撞半径 0.48m，额外留出转弯余量。
	mesh.agent_radius = 0.75
	mesh.agent_height = 2.0
	mesh.agent_max_climb = 0.5
	mesh.agent_max_slope = 45.0
	mesh.region_min_size = 0.0
	mesh.region_merge_size = 0.0
	return mesh


func _navigation_geometry() -> NavigationMeshSourceGeometryData3D:
	var source: NavigationMeshSourceGeometryData3D = NavigationMeshSourceGeometryData3D.new()
	source.add_faces(_navigation_faces, Transform3D.IDENTITY)
	var resources: Node = get_node_or_null("GeneratedResources")
	var obstacles: Array[Node] = get_tree().get_nodes_in_group("navigation_solid_buildings")
	if resources != null:
		obstacles.append_array(resources.get_children())
	for resource: Node in obstacles:
		if resource.is_queued_for_deletion():
			continue
		var collision: CollisionShape3D = resource.get_node_or_null("StaticBody3D/CollisionShape3D") as CollisionShape3D
		if collision == null or collision.shape == null or collision.disabled:
			continue
		var bounds: AABB = collision.shape.get_debug_mesh().get_aabb()
		var footprint: PackedVector3Array = PackedVector3Array()
		for corner: Vector3 in [bounds.position, Vector3(bounds.end.x, bounds.position.y, bounds.position.z), Vector3(bounds.end.x, bounds.position.y, bounds.end.z), Vector3(bounds.position.x, bounds.position.y, bounds.end.z)]:
			var projected: Vector3 = collision.global_transform * corner
			projected.y = 0.0
			footprint.append(projected)
		var world_bounds: AABB = collision.global_transform * bounds
		source.add_projected_obstruction(footprint, world_bounds.position.y - 0.1, world_bounds.size.y + 0.2, false)
	return source


func _on_resource_removed(position: Vector3) -> void:
	_resource_points.erase(position)
	_point_spacings.erase(position)
	_point_geometry.erase(position)
	request_navigation_update()


func request_navigation_update() -> void:
	if not is_inside_tree() or is_queued_for_deletion() or navigation_revision == 0:
		return
	_navigation_dirty = true
	call_deferred("_queue_navigation_update")


func _queue_navigation_update() -> void:
	if not is_inside_tree() or is_queued_for_deletion() or _navigation_update_queued or _navigation_baking:
		return
	_navigation_update_queued = true
	get_tree().create_timer(0.2).timeout.connect(_rebuild_navigation_async)


func _rebuild_navigation_async() -> void:
	_navigation_update_queued = false
	if not is_inside_tree() or is_queued_for_deletion():
		return
	_navigation_dirty = false
	_navigation_baking = true
	var mesh: NavigationMesh = _new_navigation_mesh()
	NavigationServer3D.bake_from_source_geometry_data_async(mesh, _navigation_geometry(), _on_navigation_baked.bind(mesh))


func _on_navigation_baked(mesh: NavigationMesh) -> void:
	_navigation_baking = false
	var region: NavigationRegion3D = get_node_or_null(navigation_region_path) as NavigationRegion3D
	if region == null or is_queued_for_deletion():
		return
	region.navigation_mesh = mesh
	navigation_revision += 1
	if _navigation_dirty:
		_queue_navigation_update()


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
	var base: BuildingBase = get_tree().get_first_node_in_group("bases") as BuildingBase
	if base != null:
		var origin: Vector2i = grid.world_to_grid(base.global_position - Vector3(1, 0, 1.5))
		if grid.occupy_area(origin, Vector2i(2, 3)):
			base.set_build_grid_occupancy(origin, Vector2i(2, 3), 0)


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
	if _cell_positions.has(cell):
		return _cell_positions[cell]
	var half_size: Vector2 = Vector2(map_data.map_size) * map_data.cell_size_m * 0.5
	var height: float = (height_field.get_cell_surface_height(cell) + WFCHeightControl.LEVEL_HEIGHT) * map_data.cell_size_m if height_field != null else 0.0
	var position: Vector3 = Vector3((float(cell.x) + 0.5) * map_data.cell_size_m - half_size.x, height, (float(cell.y) + 0.5) * map_data.cell_size_m - half_size.y)
	_cell_positions[cell] = position
	return position


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
	var region: NavigationRegion3D = get_node_or_null(navigation_region_path) as NavigationRegion3D
	var base: Node3D = get_tree().get_first_node_in_group("bases") as Node3D
	if region == null or base == null:
		return Vector3.INF
	var navigation_map: RID = region.get_navigation_map()
	if NavigationServer3D.map_get_iteration_id(navigation_map) == 0:
		return Vector3.INF
	var nearest: Vector3 = NavigationServer3D.map_get_closest_point(navigation_map, position)
	if _horizontal_distance(nearest, position) > 0.3 or absf(nearest.y - position.y) > 0.75:
		return Vector3.INF
	var destination: Vector3 = NavigationServer3D.map_get_closest_point(navigation_map, base.global_position)
	var path: PackedVector3Array = NavigationServer3D.map_get_path(navigation_map, nearest, destination, true)
	if path.is_empty() or path[path.size() - 1].distance_to(destination) > 0.5:
		return Vector3.INF
	return position
