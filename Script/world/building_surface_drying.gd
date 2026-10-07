extends Node

# 游戏负责把已建成建筑的占地转换成插件的通用影响区域。
var generator: MapGenerateRuntime
var _sources: Array[Dictionary] = []
var _elapsed := 0.0

func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= 0.5:
		_elapsed = 0.0
		refresh()

func refresh() -> void:
	if generator == null or generator.map_data == null:
		return
	var grid := generator.get_node_or_null(generator.build_grid_path) as BuildGrid
	if grid == null:
		return
	var sources: Array[Dictionary] = []
	var half_size := Vector2(generator.map_data.map_size) * generator.map_data.cell_size_m * 0.5
	for node in get_tree().get_nodes_in_group("buildings"):
		var building := node as BuildingBase
		if building == null or building is ConstructionSite or building.is_queued_for_deletion() or not building.build_grid_area_registered:
			continue
		var data := building.building_data
		if data == null or not data.surface_drying_enabled or data.road_kind != 0:
			continue
		var size := grid.get_rotated_size(building.build_grid_size, building.build_grid_rotation_step)
		var corner := grid.global_position + Vector3(building.build_grid_position.x * grid.cell_size, 0, building.build_grid_position.y * grid.cell_size)
		var local := generator.to_local(corner)
		sources.append({
			"bounds": Rect2(Vector2(local.x, local.z) + half_size, Vector2(size) * grid.cell_size),
			"height": generator.to_local(building.global_position).y - WFCHeightControl.LEVEL_HEIGHT * generator.map_data.cell_size_m,
			"strength": data.surface_drying_strength, "reach": data.surface_drying_range,
			"noise": data.surface_drying_noise, "seed": absi(hash(data.id) ^ generator.map_data.generation_seed),
		})
	if sources == _sources:
		return
	_sources = sources
	generator.set_surface_drying_sources(sources)
