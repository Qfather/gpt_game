class_name TorchBuilding
extends BuildingBase

@export var lifetime: float = 120.0
var elapsed: float = 0.0


func _ready() -> void:
	super._ready()


func _process(delta: float) -> void:
	super._process(delta)
	elapsed += delta
	if elapsed >= lifetime:
		release_build_grid_area()
		queue_free()


func get_remaining_lifetime() -> float:
	return maxf(lifetime - elapsed, 0.0)


func get_lifetime_ratio() -> float:
	return clampf(get_remaining_lifetime() / lifetime, 0.0, 1.0)


func get_sight_radius() -> float:
	var runtime: MapGenerateRuntime = get_tree().get_first_node_in_group("map_generate_runtime") as MapGenerateRuntime
	if runtime == null or runtime.map_data == null:
		return 12.0
	var layer: int = clampi(
		roundi(global_position.y / (runtime.map_data.cell_size_m * WFCHeightControl.LEVEL_HEIGHT)) - 1,
		0,
		WFCHeightControl.MAX_LEVEL
	)
	return 12.0 * (1.0 + float(layer) * 0.2)
