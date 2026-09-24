@tool
extends Control
class_name MapPreview2D

signal outline_drawn(outline: PackedVector2Array)
signal lake_drawn(lake: PackedVector2Array)

enum DrawMode { NONE, OUTLINE, LAKE }

var _config: MapGenerationConfig
var _draw_mode := DrawMode.NONE
var _drawing := false
var _drawing_points: PackedVector2Array = PackedVector2Array()
var _zoom := 1.0


func _ready() -> void:
	custom_minimum_size = Vector2(280.0, 240.0)
	mouse_filter = Control.MOUSE_FILTER_STOP


func configure(config: MapGenerationConfig) -> void:
	_config = config
	queue_redraw()


func start_outline_drawing() -> void:
	_start_drawing(DrawMode.OUTLINE)


func start_lake_drawing() -> void:
	_start_drawing(DrawMode.LAKE)


func _start_drawing(mode: DrawMode) -> void:
	_draw_mode = mode
	_drawing = false
	_drawing_points.clear()
	queue_redraw()


func cancel_drawing() -> void:
	_draw_mode = DrawMode.NONE
	_drawing = false
	_drawing_points.clear()
	queue_redraw()


func is_drawing_outline() -> bool:
	return _draw_mode == DrawMode.OUTLINE


func is_drawing_lake() -> bool:
	return _draw_mode == DrawMode.LAKE


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.12, 0.34, 0.52))
	if _config == null or size.x <= 0.0 or size.y <= 0.0:
		return
	var map_scale := minf((size.x - 36.0) / _config.island_size.x, (size.y - 36.0) / _config.island_size.y) * _zoom
	var center := size * 0.5
	var rng := RandomNumberGenerator.new()
	rng.seed = _config.seed
	var lakes := MapGenerationGeometry.generate_lakes(_config, _config.base_position, rng)
	var coastline := PackedVector2Array()
	if _config.island_shape == MapGenerationConfig.IslandShape.CUSTOM and _config.custom_outline.size() >= 3:
		for point in MapGenerationGeometry.custom_outline_preview_world(_config):
			coastline.append(_to_screen(point, center, map_scale))
	else:
		for segment in range(192):
			var angle := TAU * float(segment) / 192.0
			var radius := MapGenerationGeometry.island_boundary_radius(_config, angle)
			coastline.append(_to_screen(Vector2(cos(angle), sin(angle)) * radius, center, map_scale))
	draw_colored_polygon(coastline, Color(0.32, 0.53, 0.25))
	if not coastline.is_empty():
		draw_polyline(PackedVector2Array(coastline + PackedVector2Array([coastline[0]])), Color(0.82, 0.75, 0.52), 2.0, true)
	for lake_index in range(lakes.size()):
		var lake_outline := PackedVector2Array()
		for segment in range(64):
			var angle := TAU * float(segment) / 64.0
			var radius := MapGenerationGeometry.lake_boundary_radius(_config, lake_index, angle)
			lake_outline.append(_to_screen(lakes[lake_index] + Vector2(cos(angle), sin(angle)) * radius, center, map_scale))
		_draw_water_polygon(lake_outline)
	for polygon in _config.custom_lakes:
		if polygon.size() < 3:
			continue
		var lake_outline := PackedVector2Array()
		var half := _config.island_size * 0.5
		for point in polygon:
			lake_outline.append(_to_screen(Vector2(point.x * half.x, point.y * half.y), center, map_scale))
		_draw_water_polygon(lake_outline)
	var used: Array[Vector2] = []
	var land_area := MapGenerationGeometry.estimate_land_area(_config, lakes)
	var tree_count := MapGenerationGeometry.resource_count_for_density(land_area, _config.tree_density, 8.0)
	var stone_count := MapGenerationGeometry.resource_count_for_density(land_area, _config.stone_density, 5.0)
	var resource_rng := RandomNumberGenerator.new()
	resource_rng.seed = _config.resource_seed
	_draw_resource_clusters(lakes, resource_rng, used, tree_count, _config.trees_per_cluster, 3.0, true, center, map_scale)
	_draw_resource_clusters(lakes, resource_rng, used, stone_count, _config.stones_per_cluster, 3.5, false, center, map_scale)
	var base := _to_screen(_config.base_position, center, map_scale)
	draw_circle(base, 6.0, Color(0.87, 0.2, 0.16))
	draw_circle(base, 8.0, Color(0.98, 0.82, 0.32), false, 1.5)
	draw_string(ThemeDB.fallback_font, base + Vector2(10.0, 4.0), "据点", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)
	draw_string(ThemeDB.fallback_font, Vector2(10.0, size.y - 10.0), "俯视预览 | 轮廓与湖泊将生成到3D地形", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.88, 0.92, 0.94))
	if _draw_mode != DrawMode.NONE:
		var sketch := PackedVector2Array()
		for point in _drawing_points:
			sketch.append(_normalized_to_screen(point, center, map_scale))
		if sketch.size() > 1:
			sketch.append(sketch[0])
			if _draw_mode == DrawMode.LAKE and sketch.size() >= 4:
				draw_colored_polygon(sketch, Color(0.12, 0.48, 0.82, 0.78))
			draw_polyline(sketch, Color(1.0, 0.82, 0.18), 3.0, true)
		var instruction := "描绘岛屿轮廓，松开鼠标完成" if _draw_mode == DrawMode.OUTLINE else "描绘湖泊，松开鼠标完成；可继续画多个湖"
		draw_string(ThemeDB.fallback_font, Vector2(10.0, 24.0), instruction, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1.0, 0.92, 0.55))


func _draw_water_polygon(polygon: PackedVector2Array) -> void:
	if polygon.size() < 3:
		return
	draw_colored_polygon(polygon, Color(0.12, 0.38, 0.66))
	draw_polyline(PackedVector2Array(polygon + PackedVector2Array([polygon[0]])), Color(0.61, 0.79, 0.86), 1.5, true)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if _draw_mode == DrawMode.NONE:
			return
		if event.pressed:
			_drawing = true
			_drawing_points.clear()
			_append_drawing_point(_screen_to_normalized(event.position))
		else:
			if _drawing:
				_append_drawing_point(_screen_to_normalized(event.position))
				_finish_polygon()
			event.accept()
	elif event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		_zoom = clampf(_zoom * (1.15 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.15), 0.5, 4.0)
		queue_redraw()
		event.accept()
	elif _draw_mode == DrawMode.NONE:
		return
	elif event is InputEventMouseMotion and _drawing:
		_append_drawing_point(_screen_to_normalized(event.position))
		queue_redraw()
		event.accept()


func _append_drawing_point(point: Vector2) -> void:
	var bounded := Vector2(clampf(point.x, -1.0, 1.0), clampf(point.y, -1.0, 1.0))
	if _drawing_points.is_empty() or _drawing_points[-1].distance_to(bounded) >= 0.012:
		_drawing_points.append(bounded)


func _finish_polygon() -> void:
	_drawing = false
	var polygon := PackedVector2Array()
	var sample_step := maxi(1, int(ceil(float(_drawing_points.size()) / 128.0)))
	for index in range(0, _drawing_points.size(), sample_step):
		polygon.append(_drawing_points[index])
	if polygon.size() >= 3 and polygon[0].distance_to(polygon[-1]) < 0.04:
		polygon.remove_at(polygon.size() - 1)
	var minimum_area := 0.00001 if _draw_mode == DrawMode.LAKE else 0.02
	if polygon.size() >= 3 and absf(_polygon_signed_area(polygon)) >= minimum_area:
		if _draw_mode == DrawMode.OUTLINE:
			outline_drawn.emit(polygon)
			_draw_mode = DrawMode.NONE
		else:
			lake_drawn.emit(polygon)
	_drawing_points.clear()
	queue_redraw()


func _polygon_signed_area(polygon: PackedVector2Array) -> float:
	var area := 0.0
	for index in range(polygon.size()):
		area += polygon[index].cross(polygon[(index + 1) % polygon.size()])
	return area * 0.5


func _screen_to_normalized(screen_point: Vector2) -> Vector2:
	var map_scale := minf((size.x - 36.0) / _config.island_size.x, (size.y - 36.0) / _config.island_size.y) * _zoom
	var world_point := (screen_point - size * 0.5) / map_scale
	var half := _config.island_size * 0.5
	return Vector2(world_point.x / half.x, world_point.y / half.y)


func _normalized_to_screen(point: Vector2, center: Vector2, map_scale: float) -> Vector2:
	return center + Vector2(point.x * _config.island_size.x * 0.5, point.y * _config.island_size.y * 0.5) * map_scale


func _draw_resource_clusters(lakes: Array[Vector2], rng: RandomNumberGenerator, used: Array[Vector2], clusters: int, count: int, spread: float, is_tree: bool, center: Vector2, map_scale: float) -> void:
	var cluster_count := int(ceil(float(clusters) / float(count))) if count > 0 else 0
	var remaining := clusters
	for _cluster_index in range(cluster_count):
		if remaining <= 0:
			break
		var cluster_center := Vector2.ZERO
		var found := false
		for _attempt in range(100):
			var candidate := Vector2(rng.randf_range(-_config.island_size.x * 0.44, _config.island_size.x * 0.44), rng.randf_range(-_config.island_size.y * 0.44, _config.island_size.y * 0.44))
			if _valid_resource_point(candidate, lakes, used):
				cluster_center = candidate
				found = true
				break
		if not found:
			continue
		var cluster_items := mini(count, remaining)
		for _item_index in range(cluster_items):
			var point := Vector2.ZERO
			var point_found := false
			for _point_attempt in range(30):
				var candidate := cluster_center + Vector2(rng.randf_range(-spread, spread), rng.randf_range(-spread, spread))
				if _valid_resource_point(candidate, lakes, used):
					point = candidate
					point_found = true
					break
			if not point_found:
				continue
			used.append(point)
			var screen_point := _to_screen(point, center, map_scale)
			if is_tree:
				draw_circle(screen_point, maxf(2.5, 0.35 * map_scale), Color(0.09, 0.25, 0.11))
			else:
				draw_rect(Rect2(screen_point - Vector2.ONE * 2.5, Vector2.ONE * 5.0), Color(0.48, 0.51, 0.52))
			remaining -= 1


func _valid_resource_point(point: Vector2, lakes: Array[Vector2], used: Array[Vector2]) -> bool:
	if not MapGenerationGeometry.is_land(_config, point, 1.0) or point.distance_to(_config.base_position) < 6.5:
		return false
	if MapGenerationGeometry.lake_clearance(_config, lakes, point) < 1.5:
		return false
	for other in used:
		if point.distance_to(other) < 1.2:
			return false
	return true


func _to_screen(point: Vector2, center: Vector2, map_scale: float) -> Vector2:
	return center + Vector2(point.x, point.y) * map_scale
