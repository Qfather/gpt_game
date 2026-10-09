extends RefCounted

var points: Array[Vector3] = []
var free_ratio: float = 1.0
var indoors: bool = false
var next_refresh: int = 0

func refresh(base: Node3D) -> void:
	if Time.get_ticks_msec() < next_refresh: return
	next_refresh = Time.get_ticks_msec() + 1000
	points.clear()
	var grid: BuildGrid = base.get_tree().get_first_node_in_group("build_grid")
	if grid == null: return
	var map: RID = base.get_world_3d().navigation_map
	if NavigationServer3D.map_get_iteration_id(map) == 0: return
	var roads: Node = base.get_tree().get_first_node_in_group("road_manager")
	var own_cells: Array[Vector2i] = []
	if base.build_grid_area_registered:
		own_cells = grid._get_area_cells(base.build_grid_position, base.build_grid_size, base.build_grid_rotation_step)
	var resource_bounds: Array[AABB] = []
	for resource: Node3D in base.get_tree().get_nodes_in_group("resources"):
		if resource.is_queued_for_deletion(): continue
		var bounds: AABB = resource.get_build_obstacle_bounds()
		if bounds.get_center().distance_to(base.global_position) < base.idle_radius + bounds.size.length(): resource_bounds.append(bounds)
	var center: Vector2i = grid.world_to_grid(base.global_position)
	var radius: int = ceili(base.idle_radius / grid.cell_size)
	var total: int = 0
	var entrance: Vector3 = base.get_entrance_position()
	for x: int in range(center.x - radius, center.x + radius + 1):
		for z: int in range(center.y - radius, center.y + radius + 1):
			var cell := Vector2i(x, z)
			var point: Vector3 = grid.grid_to_world(cell)
			if Vector2(point.x - base.global_position.x, point.z - base.global_position.z).length() > base.idle_radius or own_cells.has(cell): continue
			total += 1
			if grid.occupied_cells.has(cell) or not grid.is_cell_buildable(cell, true): continue
			if roads != null and (roads.cells.has(cell) or roads.pending.has(cell)): continue
			if Vector2(point.x - entrance.x, point.z - entrance.z).length() < 1.3: continue
			var blocked: bool = false
			for bounds: AABB in resource_bounds:
				if Rect2(Vector2(bounds.position.x, bounds.position.z), Vector2(bounds.size.x, bounds.size.z)).intersects(Rect2(Vector2(point.x, point.z) - Vector2.ONE * grid.cell_size * 0.5, Vector2.ONE * grid.cell_size)):
					blocked = true
					break
			if blocked: continue
			var projected: Vector3 = NavigationServer3D.map_get_closest_point(map, point)
			if Vector2(projected.x - point.x, projected.z - point.z).length() > 0.25 or absf(projected.y - point.y) > 0.8: continue
			points.append(projected)
	free_ratio = float(points.size()) / float(total) if total > 0 else 0.0
	if free_ratio < 0.5: indoors = true
	elif free_ratio > 0.6: indoors = false

func contains(base: Node3D, point: Vector3) -> bool:
	refresh(base)
	var grid: BuildGrid = base.get_tree().get_first_node_in_group("build_grid")
	if grid == null: return true
	var cell: Vector2i = grid.world_to_grid(point)
	for candidate: Vector3 in points:
		if grid.world_to_grid(candidate) == cell: return true
	return false
