extends Node3D

var passenger: Node3D
var occupied: bool = false


func clear_passenger() -> void:
	if is_instance_valid(passenger): passenger.queue_free()
	passenger = null
	occupied = false


var route: Array[Vector3] = []
var graph := AStarGrid2D.new()
var graph_revision: int = -1
var graph_center: Vector2i
var graph_radius: int = -1


func water_clear(grid: BuildGrid, cell: Vector2i) -> bool:
	return grid.is_water_cell(cell) and not grid.occupied_cells.has(cell)


func prepare_graph(grid: BuildGrid, center: Vector3, radius: float) -> void:
	var cell := grid.world_to_grid(center)
	var extent := ceili(radius / grid.cell_size)
	if graph_revision == grid.occupancy_revision and graph_center == cell and graph_radius == extent: return
	graph_center = cell
	graph_radius = extent
	graph_revision = grid.occupancy_revision
	graph.region = Rect2i(cell - Vector2i.ONE * extent, Vector2i.ONE * (extent * 2 + 1))
	graph.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	graph.update()
	for z: int in range(graph.region.position.y, graph.region.end.y):
		for x: int in range(graph.region.position.x, graph.region.end.x):
			var point := Vector2i(x, z)
			graph.set_point_solid(point, not water_clear(grid, point) or Vector2(point - cell).length() * grid.cell_size > radius)


func navigate(grid: BuildGrid, center: Vector3, radius: float, destination: Vector3) -> bool:
	prepare_graph(grid, center, radius)
	route.clear()
	var from := grid.world_to_grid(global_position)
	var to := grid.world_to_grid(destination)
	if not graph.region.has_point(from) or not graph.region.has_point(to): return false
	if graph.is_point_solid(from) or graph.is_point_solid(to): return false
	for cell: Vector2i in graph.get_id_path(from, to):
		var point := grid.grid_to_world(cell)
		point.y = grid.water_height
		route.append(point)
	if not route.is_empty(): route.append(Vector3(destination.x, grid.water_height, destination.z))
	return not route.is_empty()


func choose_fishing_point(grid: BuildGrid, center: Vector3, radius: float, rng: RandomNumberGenerator) -> Vector3:
	prepare_graph(grid, center, radius)
	for attempt: int in range(32):
		var cell := graph_center + Vector2i(rng.randi_range(-graph_radius, graph_radius), rng.randi_range(-graph_radius, graph_radius))
		if not graph.region.has_point(cell) or graph.is_point_solid(cell): continue
		var point := grid.grid_to_world(cell)
		point.y = grid.water_height
		if point.distance_to(global_position) < 2.0: continue
		if navigate(grid, center, radius, point): return point
	return Vector3.INF


func sail(grid: BuildGrid, speed: float, delta: float) -> bool:
	if route.is_empty(): return false
	if not water_clear(grid, grid.world_to_grid(route[0])):
		route.clear()
		return false
	var offset := route[0] - global_position
	var distance := offset.length()
	var movement := minf(speed * delta, distance)
	if distance > 0.001:
		preload("res://Script/unit/unit_facing.gd").face_direction($Visual, offset)
		global_position += offset / distance * movement
	preload("res://Script/unit/unit_facing.gd").update($Visual, delta)
	if global_position.distance_to(route[0]) <= 0.01: route.pop_front()
	return route.is_empty()
