extends RefCounted

const DIRECTIONS: Array[Vector2i] = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
const SHAPE_MASKS: Array[int] = [0, 1, 5, 3, 11, 15]

static func cells(tree: SceneTree, include_sites: bool = false) -> Dictionary:
	var result: Dictionary = {}
	var grid: BuildGrid = tree.get_first_node_in_group("build_grid") as BuildGrid
	if grid == null: return result
	for node: Node in tree.get_nodes_in_group("buildings"):
		var building: BuildingBase = node as BuildingBase
		if building == null or building.is_queued_for_deletion() or not building.build_grid_area_registered or building.building_data == null: continue
		var data: BuildingData = building.building_data
		if not data.is_wall() and not data.is_gate() and not data.is_wall_tower(): continue
		if building is ConstructionSite:
			if not include_sites or not data.is_wall(): continue
		elif building.is_destroyed() or building.get_health() <= 0: continue
		for cell: Vector2i in grid._get_area_cells(building.build_grid_position, building.build_grid_size, building.build_grid_rotation_step):
			result[cell] = building
	return result

static func connection_mask(cell: Vector2i, layout: Dictionary, grid: BuildGrid) -> int:
	var mask: int = 0
	for index: int in range(4):
		var neighbor: Vector2i = cell + DIRECTIONS[index]
		if not layout.has(neighbor) or absf(grid.get_ground_height(cell) - grid.get_ground_height(neighbor)) > 0.1: continue
		var building: BuildingBase = layout[neighbor]
		if building.building_data.is_gate():
			var area: Array[Vector2i] = grid._get_area_cells(building.build_grid_position, building.build_grid_size, building.build_grid_rotation_step)
			var axis: Vector2i = Vector2i.RIGHT if building.build_grid_rotation_step % 2 == 0 else Vector2i.DOWN
			if cell != area[0] - axis and cell != area[-1] + axis: continue
		mask |= 1 << index
	return mask

static func shape_for_mask(mask: int) -> Vector2i:
	for shape: int in range(SHAPE_MASKS.size()):
		var rotated: int = SHAPE_MASKS[shape]
		for turns: int in range(4):
			if rotated == mask: return Vector2i(shape, turns)
			rotated = ((rotated << 1) & 15) | (rotated >> 3)
	return Vector2i.ZERO

static func refresh(tree: SceneTree) -> void:
	var alarm: Node = tree.get_first_node_in_group("settlement_alarm")
	if alarm != null: alarm.mark_defenses_dirty()
	var grid: BuildGrid = tree.get_first_node_in_group("build_grid") as BuildGrid
	if grid == null: return
	var layout: Dictionary = cells(tree)
	for cell: Vector2i in layout:
		var building: BuildingBase = layout[cell]
		if building.building_data.is_wall() and building.has_method("update_connection"):
			building.update_connection(connection_mask(cell, layout, grid), grid.cell_size)

static func remove_wall(wall: BuildingBase, release_grid: bool = true) -> void:
	if release_grid: wall.release_build_grid_area()
	else: wall.build_grid_area_registered = false
	wall.hide()
	var body: StaticBody3D = wall.get_node_or_null("StaticBody3D") as StaticBody3D
	if body != null:
		body.collision_layer = 0
		body.collision_mask = 0
	wall.queue_free()
	refresh(wall.get_tree())
