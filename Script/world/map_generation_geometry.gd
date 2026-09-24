extends RefCounted
class_name MapGenerationGeometry

const SEA_LEVEL: float = -0.22
const AREA_SAMPLE_STEP: float = 1.0
static var _outline_noise_cache: Dictionary = {}


static func is_land(config: MapGenerationConfig, point: Vector2, inset: float = 0.0) -> bool:
	if config.island_shape == MapGenerationConfig.IslandShape.CUSTOM:
		var data := _custom_boundary_data(point, config)
		return data.z + _custom_noise_offset(Vector2(data.x, data.y), config) >= inset
	var distance := point.length()
	if distance <= 0.001:
		return true
	var angle := atan2(point.y, point.x)
	return distance <= _island_boundary_radius(config, angle, inset)


static func edge_distance(config: MapGenerationConfig, point: Vector2) -> float:
	if config.island_shape == MapGenerationConfig.IslandShape.CUSTOM:
		var data := _custom_boundary_data(point, config)
		var clearance := data.z + _custom_noise_offset(Vector2(data.x, data.y), config)
		return clampf(clearance / 2.7, 0.0, 1.0)
	var distance := point.length()
	if distance <= 0.001:
		return 1.0
	var boundary := _island_boundary_radius(config, atan2(point.y, point.x), 0.0)
	return clampf(1.0 - distance / maxf(boundary, 0.001), 0.0, 1.0)


static func island_boundary_radius(config: MapGenerationConfig, angle: float) -> float:
	return _island_boundary_radius(config, angle, 0.0)


static func custom_outline_world(config: MapGenerationConfig) -> PackedVector2Array:
	var polygon := PackedVector2Array()
	var half := config.island_size * 0.5
	for normalized_point in config.custom_outline:
		polygon.append(Vector2(normalized_point.x * half.x, normalized_point.y * half.y))
	return polygon


static func custom_outline_preview_world(config: MapGenerationConfig) -> PackedVector2Array:
	var source := custom_outline_world(config)
	if source.size() < 3 or config.naturalization <= 0.0:
		return source
	var area := _polygon_signed_area(source)
	var result := PackedVector2Array()
	for index in range(source.size()):
		var start := source[index]
		var end := source[(index + 1) % source.size()]
		var edge := end - start
		var segments := maxi(1, int(ceil(edge.length() / 0.8)))
		var outward := Vector2(edge.y, -edge.x).normalized() if area >= 0.0 else Vector2(-edge.y, edge.x).normalized()
		for segment in range(segments):
			var point := start.lerp(end, float(segment) / float(segments))
			result.append(point + outward * _custom_noise_offset(point, config))
	return result


static func find_custom_interior_point(config: MapGenerationConfig) -> Vector2:
	if config.custom_outline.size() < 3:
		return Vector2.ZERO
	var half := config.island_size * 0.5
	var samples_x := int(ceil(config.island_size.x / 0.5))
	var samples_z := int(ceil(config.island_size.y / 0.5))
	var best_point := Vector2.ZERO
	var best_clearance := -1.0
	for z in range(samples_z):
		for x in range(samples_x):
			var point := Vector2(-half.x + (float(x) + 0.5) * 0.5, -half.y + (float(z) + 0.5) * 0.5)
			if not is_land(config, point):
				continue
			var clearance := _custom_boundary_data(point, config).z
			if clearance > best_clearance:
				best_clearance = clearance
				best_point = point
	return best_point


static func _custom_boundary_data(point: Vector2, config: MapGenerationConfig) -> Vector3:
	if config.custom_outline.size() < 3:
		return Vector3(point.x, point.y, -INF)
	var nearest_distance := INF
	var nearest_point := Vector2.ZERO
	var half := config.island_size * 0.5
	for index in range(config.custom_outline.size()):
		var start_normalized := config.custom_outline[index]
		var end_normalized := config.custom_outline[(index + 1) % config.custom_outline.size()]
		var start := Vector2(start_normalized.x * half.x, start_normalized.y * half.y)
		var edge := Vector2((end_normalized.x - start_normalized.x) * half.x, (end_normalized.y - start_normalized.y) * half.y)
		var edge_length_squared := edge.length_squared()
		var weight := 0.0 if edge_length_squared <= 0.0001 else clampf((point - start).dot(edge) / edge_length_squared, 0.0, 1.0)
		var closest_point := start + edge * weight
		var distance := point.distance_to(closest_point)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_point = closest_point
	var normalized_point := Vector2(point.x / half.x, point.y / half.y)
	var signed_distance := nearest_distance if Geometry2D.is_point_in_polygon(normalized_point, config.custom_outline) else -nearest_distance
	return Vector3(nearest_point.x, nearest_point.y, signed_distance)


static func _custom_noise_offset(boundary_point: Vector2, config: MapGenerationConfig) -> float:
	if config.naturalization <= 0.0:
		return 0.0
	var half := config.island_size * 0.5
	var normalized := Vector2(boundary_point.x / half.x, boundary_point.y / half.y)
	return _outline_noise(normalized, config.seed, config.noise_scale) * minf(half.x, half.y) * 0.22 * config.naturalization


static func _polygon_signed_area(polygon: PackedVector2Array) -> float:
	var area := 0.0
	for index in range(polygon.size()):
		area += polygon[index].cross(polygon[(index + 1) % polygon.size()])
	return area * 0.5


static func _normalized_polygon_to_world(config: MapGenerationConfig, polygon: PackedVector2Array) -> PackedVector2Array:
	var result := PackedVector2Array()
	var half := config.island_size * 0.5
	for point in polygon:
		result.append(Vector2(point.x * half.x, point.y * half.y))
	return result


static func _distance_to_polygon(point: Vector2, polygon: PackedVector2Array) -> float:
	var nearest_distance := INF
	for index in range(polygon.size()):
		var start := polygon[index]
		var edge := polygon[(index + 1) % polygon.size()] - start
		var weight := 0.0 if edge.length_squared() <= 0.0001 else clampf((point - start).dot(edge) / edge.length_squared(), 0.0, 1.0)
		nearest_distance = minf(nearest_distance, point.distance_to(start + edge * weight))
	return nearest_distance


static func lake_contains(config: MapGenerationConfig, lakes: Array[Vector2], point: Vector2) -> bool:
	for normalized_polygon in config.custom_lakes:
		var polygon := _normalized_polygon_to_world(config, normalized_polygon)
		if polygon.size() >= 3 and Geometry2D.is_point_in_polygon(point, polygon):
			return true
	for index in range(lakes.size()):
		var offset := point - lakes[index]
		var boundary := _lake_boundary_radius(config, index, atan2(offset.y, offset.x))
		if offset.length() < boundary:
			return true
	return false


static func lake_clearance(config: MapGenerationConfig, lakes: Array[Vector2], point: Vector2) -> float:
	var clearance := INF
	for index in range(lakes.size()):
		var offset := point - lakes[index]
		clearance = minf(clearance, offset.length() - _lake_boundary_radius(config, index, atan2(offset.y, offset.x)))
	for normalized_polygon in config.custom_lakes:
		var polygon := _normalized_polygon_to_world(config, normalized_polygon)
		if polygon.size() < 3:
			continue
		var distance := _distance_to_polygon(point, polygon)
		if Geometry2D.is_point_in_polygon(point, polygon):
			distance = -distance
		clearance = minf(clearance, distance)
	return clearance


static func lake_boundary_radius(config: MapGenerationConfig, lake_index: int, angle: float) -> float:
	return _lake_boundary_radius(config, lake_index, angle)


static func custom_lake_world(config: MapGenerationConfig, lake_index: int) -> PackedVector2Array:
	if lake_index < 0 or lake_index >= config.custom_lakes.size():
		return PackedVector2Array()
	return _normalized_polygon_to_world(config, config.custom_lakes[lake_index])


static func create_custom_lake_mesh(config: MapGenerationConfig, lake_index: int) -> ArrayMesh:
	var polygon := custom_lake_world(config, lake_index)
	var vertices := PackedVector3Array()
	for point in polygon:
		vertices.append(Vector3(point.x, 0.0, point.y))
	var triangles := Geometry2D.triangulate_polygon(polygon)
	var indices := PackedInt32Array()
	for index in range(0, triangles.size(), 3):
		indices.append_array(PackedInt32Array([triangles[index], triangles[index + 2], triangles[index + 1]]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


static func estimate_land_area(config: MapGenerationConfig, lakes: Array[Vector2]) -> float:
	var half := config.island_size * 0.5
	var samples_x := int(ceil(config.island_size.x / AREA_SAMPLE_STEP))
	var samples_z := int(ceil(config.island_size.y / AREA_SAMPLE_STEP))
	var land_samples := 0
	for z in range(samples_z):
		for x in range(samples_x):
			var point := Vector2(
				-half.x + (float(x) + 0.5) * AREA_SAMPLE_STEP,
				-half.y + (float(z) + 0.5) * AREA_SAMPLE_STEP
			)
			if is_land(config, point) and not lake_contains(config, lakes, point):
				land_samples += 1
	return float(land_samples) * AREA_SAMPLE_STEP * AREA_SAMPLE_STEP


static func resource_count_for_density(land_area: float, density: float, max_per_100m2: float) -> int:
	return maxi(0, roundi(land_area * clampf(density, 0.0, 1.0) * max_per_100m2 / 100.0))


static func height_at(config: MapGenerationConfig, lakes: Array[Vector2], base_position: Vector2, x: float, z: float) -> float:
	var point := Vector2(x, z)
	if not is_land(config, point) or lake_contains(config, lakes, point):
		return SEA_LEVEL
	var shore_blend := clampf(edge_distance(config, point) / 0.18, 0.0, 1.0)
	if point.distance_to(base_position) < 5.0:
		return 0.08
	var waves := sin(x * 0.52 + float(config.seed % 13)) * cos(z * 0.43 - float(config.seed % 7))
	var low_noise := sin((x + z) * 0.17) * 0.35 + cos((x - z) * 0.21) * 0.25
	var terrain_height := 0.08 + (waves + low_noise) * config.terrain_relief * shore_blend
	return maxf(terrain_height, SEA_LEVEL + 0.04)


static func generate_lakes(config: MapGenerationConfig, base_position: Vector2, rng: RandomNumberGenerator) -> Array[Vector2]:
	var lakes: Array[Vector2] = []
	for index in range(config.lake_count):
		for attempt in range(50):
			var point := Vector2(
				rng.randf_range(-config.island_size.x * 0.28, config.island_size.x * 0.28),
				rng.randf_range(-config.island_size.y * 0.28, config.island_size.y * 0.28)
			)
			if not is_land(config, point) or point.distance_to(base_position) < 7.0:
				continue
			if lake_clearance(config, lakes, point) < config.lake_radius * 2.0:
				continue
			var separated := true
			for lake in lakes:
				if lake.distance_to(point) < config.lake_radius * 3.0:
					separated = false
					break
			if separated:
				lakes.append(point)
				break
	return lakes


static func create_lake_mesh(config: MapGenerationConfig, lake_index: int) -> ArrayMesh:
	var vertices := PackedVector3Array([Vector3.ZERO])
	var normals := PackedVector3Array([Vector3.UP])
	var indices := PackedInt32Array()
	var segments := 64
	for segment in range(segments):
		var angle := TAU * float(segment) / float(segments)
		var radius := _lake_boundary_radius(config, lake_index, angle)
		vertices.append(Vector3(cos(angle) * radius, 0.0, sin(angle) * radius))
		normals.append(Vector3.UP)
	for segment in range(segments):
		var current := segment + 1
		var next := (segment + 1) % segments + 1
		indices.append_array(PackedInt32Array([0, next, current]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


static func _island_boundary_radius(config: MapGenerationConfig, angle: float, inset: float) -> float:
	var half_x := maxf(config.island_size.x * 0.5 - inset, 0.1)
	var half_z := maxf(config.island_size.y * 0.5 - inset, 0.1)
	var direction_x := absf(cos(angle))
	var direction_z := sin(angle)
	var ellipse_radius := 1.0 / sqrt(direction_x * direction_x / (half_x * half_x) + direction_z * direction_z / (half_z * half_z))
	var radius := minf(half_x, half_z)
	match config.island_shape:
		MapGenerationConfig.IslandShape.CIRCLE:
			radius = minf(half_x, half_z)
		MapGenerationConfig.IslandShape.ELLIPSE:
			radius = 1.0 / sqrt(direction_x * direction_x / (half_x * half_x) + direction_z * direction_z / (half_z * half_z))
		MapGenerationConfig.IslandShape.SQUARE:
			var side := minf(half_x, half_z)
			radius = minf(side / maxf(direction_x, 0.0001), side / maxf(absf(direction_z), 0.0001))
		MapGenerationConfig.IslandShape.RECTANGLE:
			radius = minf(half_x / maxf(direction_x, 0.0001), half_z / maxf(absf(direction_z), 0.0001))
		MapGenerationConfig.IslandShape.TRIANGLE:
			var vertical_limit := half_z / maxf(absf(direction_z), 0.0001)
			var side_coefficient := direction_x / half_x + direction_z / (2.0 * half_z)
			radius = vertical_limit
			if side_coefficient > 0.0001:
				radius = minf(radius, 0.5 / side_coefficient)
	var noise_direction := Vector2(cos(angle), sin(angle))
	var naturalization := clampf(config.naturalization, 0.0, 1.0)
	var base_radius := lerpf(ellipse_radius, radius, 1.0 - naturalization)
	var noise_offset := _outline_noise(noise_direction, config.seed, config.noise_scale) * minf(half_x, half_z) * 0.55 * naturalization
	var perturbed_radius := maxf(0.1, base_radius + noise_offset)
	var bounds_radius := minf(half_x / maxf(absf(noise_direction.x), 0.0001), half_z / maxf(absf(noise_direction.y), 0.0001))
	return minf(perturbed_radius, bounds_radius)


static func _lake_boundary_radius(config: MapGenerationConfig, lake_index: int, angle: float) -> float:
	var lake_seed := config.seed + lake_index * 7919
	var direction := Vector2(cos(angle), sin(angle))
	return config.lake_radius * (1.0 + config.naturalization * 0.25 * _outline_noise(direction, lake_seed, config.noise_scale))


static func _outline_noise(direction: Vector2, seed_value: int, noise_scale: float) -> float:
	var noise := _get_outline_noise(seed_value)
	var frequency := 1.0 / maxf(noise_scale, 0.05)
	var broad := noise.get_noise_2d((direction.x * 1.8 + 17.3) * frequency, (direction.y * 1.8 - 8.1) * frequency)
	var medium := noise.get_noise_2d((direction.x * 4.6 - 3.7) * frequency, (direction.y * 4.6 + 21.4) * frequency)
	var fine := noise.get_noise_2d((direction.x * 10.5 + 31.8) * frequency, (direction.y * 10.5 - 16.2) * frequency)
	return clampf(broad * 0.55 + medium * 0.30 + fine * 0.15, -1.0, 1.0)


static func _get_outline_noise(seed_value: int) -> FastNoiseLite:
	if _outline_noise_cache.has(seed_value):
		return _outline_noise_cache[seed_value] as FastNoiseLite
	if _outline_noise_cache.size() >= 16:
		_outline_noise_cache.clear()
	var noise := FastNoiseLite.new()
	noise.seed = seed_value
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = 0.8
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 3
	noise.fractal_lacunarity = 2.0
	noise.fractal_gain = 0.5
	_outline_noise_cache[seed_value] = noise
	return noise
