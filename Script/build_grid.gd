class_name BuildGrid
extends Node3D

@export_category("网格")
@export var cell_size: float = 1.0
@export var grid_min: Vector2i = Vector2i(-15, -15)
@export var grid_max: Vector2i = Vector2i(14, 14)

var occupied_cells: Dictionary = {}
var buildability_rule: Callable
var ground_height_rule: Callable
var water_rule: Callable
var water_height: float = 1.8
var occupancy_revision: int = 0


func is_water_cell(cell: Vector2i) -> bool:
	return _is_in_bounds(cell) and water_rule.is_valid() and bool(water_rule.call(cell))


func get_shore_cells(cell: Vector2i, size: Vector2i, turns: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var dimensions := get_rotated_size(size, turns)
	match posmod(turns, 4):
		0:
			for x: int in range(dimensions.x): result.append(cell + Vector2i(x, dimensions.y))
		1:
			for z: int in range(dimensions.y): result.append(cell + Vector2i(dimensions.x, z))
		2:
			for x: int in range(dimensions.x): result.append(cell + Vector2i(x, -1))
		3:
			for z: int in range(dimensions.y): result.append(cell + Vector2i(-1, z))
	return result


func is_building_area_free(data: BuildingData, cell: Vector2i, turns: int, ignored: Array[Vector2i] = []) -> bool:
	if data.placement_surface == 0:
		return is_area_free(cell, data.grid_size, turns, data.is_wall(), true, ignored)
	for water_cell: Vector2i in _get_area_cells(cell, data.grid_size, turns):
		if not is_water_cell(water_cell) or (occupied_cells.has(water_cell) and not ignored.has(water_cell)): return false
	var shore := get_shore_cells(cell, data.grid_size, turns)
	var height := get_ground_height(shore[0])
	if height < water_height or height - water_height > 1.5: return false
	for land_cell: Vector2i in shore:
		if not is_cell_buildable(land_cell, true) or occupied_cells.has(land_cell): return false
		if not is_equal_approx(get_ground_height(land_cell), height): return false
		if _overlaps_resource(land_cell, Vector2i.ONE, 0): return false
	return true


func occupy_building_area(data: BuildingData, cell: Vector2i, turns: int) -> bool:
	if not is_building_area_free(data, cell, turns): return false
	for part: Vector2i in _get_area_cells(cell, data.grid_size, turns): occupied_cells[part] = true
	occupancy_revision += 1
	return true


func get_building_height(data: BuildingData, cell: Vector2i, turns: int) -> float:
	return get_ground_height(get_shore_cells(cell, data.grid_size, turns)[0]) if data.placement_surface == 1 else get_ground_height(cell)


func _ready() -> void:
	add_to_group("build_grid")

	if DevMode.DEV_MODE:
		_debug_test()


func world_to_grid(world_position: Vector3) -> Vector2i:

	return Vector2i(
		floori((world_position.x - global_position.x) / cell_size),
		floori((world_position.z - global_position.z) / cell_size)
	)


func grid_to_world(grid_position: Vector2i) -> Vector3:

	return global_position + Vector3(
		(float(grid_position.x) + 0.5) * cell_size,
		get_ground_height(grid_position),
		(float(grid_position.y) + 0.5) * cell_size
	)


func get_rotated_size(
	area_size: Vector2i,
	rotation_step: int
) -> Vector2i:

	if posmod(rotation_step, 2) == 1:
		return Vector2i(area_size.y, area_size.x)

	return area_size


func is_area_free(
	grid_position: Vector2i,
	area_size: Vector2i,
	rotation_step: int = 0,
	ignore_resources: bool = false,
	ignore_fog: bool = false,
	ignored_cells: Array[Vector2i] = []
) -> bool:
	return is_area_buildable(grid_position, area_size, rotation_step, ignore_resources, ignore_fog, ignored_cells)


func is_cell_buildable(grid_position: Vector2i, ignore_fog: bool = false) -> bool:
	var fog: Node = get_tree().get_first_node_in_group("fog_of_war") if is_inside_tree() else null
	if not ignore_fog and fog != null and not fog.is_visible_at(grid_to_world(grid_position)):
		return false
	if not _is_in_bounds(grid_position):
		return false
	if buildability_rule.is_valid():
		return bool(buildability_rule.call(grid_position))
	return true


func is_area_buildable(
	grid_position: Vector2i,
	area_size: Vector2i,
	rotation_step: int = 0,
	ignore_resources: bool = false,
	ignore_fog: bool = false,
	ignored_cells: Array[Vector2i] = []
) -> bool:

	var first_height: float = get_ground_height(grid_position)
	for cell in _get_area_cells(
		grid_position,
		area_size,
		rotation_step
	):

		if not is_cell_buildable(cell, ignore_fog):
			return false
		if not is_equal_approx(get_ground_height(cell), first_height):
			return false

		if occupied_cells.has(cell) and not ignored_cells.has(cell):
			return false

	return ignore_resources or not _overlaps_resource(grid_position, area_size, rotation_step)


func _overlaps_resource(grid_position: Vector2i, area_size: Vector2i, rotation_step: int) -> bool:
	if not is_inside_tree():
		return false
	var size: Vector2i = get_rotated_size(area_size, rotation_step)
	var footprint := Rect2(
		Vector2(global_position.x, global_position.z) + Vector2(grid_position) * cell_size,
		Vector2(size) * cell_size
	)
	for node: Node in get_tree().get_nodes_in_group("resources"):
		var resource: ResourceBase = node as ResourceBase
		if resource == null or resource.is_queued_for_deletion():
			continue
		var bounds: AABB = resource.get_build_obstacle_bounds()
		if bounds.size == Vector3.ZERO:
			continue
		var building_bounds := AABB(
			Vector3(footprint.position.x, bounds.position.y, footprint.position.y),
			Vector3(footprint.size.x, bounds.size.y, footprint.size.y)
		)
		if resource.overlaps_clearance_box(building_bounds, Transform3D.IDENTITY):
			return true
	return false


func set_buildability_rule(rule: Callable) -> void:
	buildability_rule = rule


func set_ground_height_rule(rule: Callable) -> void:
	ground_height_rule = rule


func get_ground_height(grid_position: Vector2i) -> float:
	if ground_height_rule.is_valid():
		return float(ground_height_rule.call(grid_position))
	return 0.0


func occupy_area(
	grid_position: Vector2i,
	area_size: Vector2i,
	rotation_step: int = 0,
	ignore_resources: bool = false,
	ignore_fog: bool = false
) -> bool:

	if not is_area_free(
		grid_position,
		area_size,
		rotation_step,
		ignore_resources,
		ignore_fog
	):
		return false

	for cell in _get_area_cells(
		grid_position,
		area_size,
		rotation_step
	):

		occupied_cells[cell] = true

	occupancy_revision += 1
	return true


func release_area(
	grid_position: Vector2i,
	area_size: Vector2i,
	rotation_step: int = 0
) -> bool:

	var cells = _get_area_cells(
		grid_position,
		area_size,
		rotation_step
	)

	for cell in cells:

		if not occupied_cells.has(cell):
			return false

	for cell in cells:
		occupied_cells.erase(cell)

	occupancy_revision += 1
	return true


func _get_area_cells(
	grid_position: Vector2i,
	area_size: Vector2i,
	rotation_step: int
) -> Array[Vector2i]:

	var rotated_size: Vector2i = get_rotated_size(
		area_size,
		rotation_step
	)
	var cells: Array[Vector2i] = []

	for z in range(rotated_size.y):
		for x in range(rotated_size.x):
			cells.append(
				grid_position + Vector2i(x, z)
			)

	return cells


func _is_in_bounds(grid_position: Vector2i) -> bool:

	return (
		grid_position.x >= grid_min.x
		and grid_position.x <= grid_max.x
		and grid_position.y >= grid_min.y
		and grid_position.y <= grid_max.y
	)


func _debug_test() -> void:

	var test_world_position := Vector3(0.0, 0.0, 0.0)
	var test_grid_position := world_to_grid(test_world_position)
	var test_area := Vector2i(3, 2)

	print("BuildGrid world_to_grid: ", test_grid_position)
	print(
		"BuildGrid grid_to_world: ",
		grid_to_world(test_grid_position)
	)
	print(
		"BuildGrid rotated 3x2: ",
		get_rotated_size(test_area, 1)
	)
	print(
		"BuildGrid occupy 3x2: ",
		occupy_area(test_grid_position, test_area)
	)
	print(
		"BuildGrid occupied area free: ",
		is_area_free(test_grid_position, test_area)
	)
	print(
		"BuildGrid release 3x2: ",
		release_area(test_grid_position, test_area)
	)
	print(
		"BuildGrid released area free: ",
		is_area_free(test_grid_position, test_area)
	)
