class_name BuildGrid
extends Node3D

@export_category("网格")
@export var cell_size: float = 1.0
@export var grid_min: Vector2i = Vector2i(-15, -15)
@export var grid_max: Vector2i = Vector2i(14, 14)

var occupied_cells: Dictionary = {}
var buildability_rule: Callable
var ground_height_rule: Callable


func _ready() -> void:

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
	rotation_step: int = 0
) -> bool:
	return is_area_buildable(grid_position, area_size, rotation_step)


func is_cell_buildable(grid_position: Vector2i) -> bool:
	if not _is_in_bounds(grid_position):
		return false
	if buildability_rule.is_valid():
		return bool(buildability_rule.call(grid_position))
	return true


func is_area_buildable(
	grid_position: Vector2i,
	area_size: Vector2i,
	rotation_step: int = 0
) -> bool:

	var first_height: float = get_ground_height(grid_position)
	for cell in _get_area_cells(
		grid_position,
		area_size,
		rotation_step
	):

		if not is_cell_buildable(cell):
			return false
		if not is_equal_approx(get_ground_height(cell), first_height):
			return false

		if occupied_cells.has(cell):
			return false

	return true


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
	rotation_step: int = 0
) -> bool:

	if not is_area_free(
		grid_position,
		area_size,
		rotation_step
	):
		return false

	for cell in _get_area_cells(
		grid_position,
		area_size,
		rotation_step
	):

		occupied_cells[cell] = true

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
