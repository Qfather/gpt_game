extends SceneTree

var _failed: bool = false

func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var map: WFCMapData = WFCMapData.new()
	map.map_size = Vector2i(6, 3)
	for y: int in range(map.map_size.y):
		for x: int in range(map.map_size.x):
			map.set_cell(Vector2i(x, y), true)
	map.set_height_control(Vector2i(2, 1), 1.0, WFCHeightControl.Kind.PLATEAU)
	map.set_height_control(Vector2i(3, 1), 2.0, WFCHeightControl.Kind.PLATEAU)
	map.set_height_control(Vector2i(4, 1), 3.0, WFCHeightControl.Kind.PLATEAU)
	var runtime: MapGenerateRuntime = MapGenerateRuntime.new()
	runtime.map_data = map
	runtime.height_field = map.create_height_field()
	runtime._build_resource_terrain_weights(map.occupied_cells)
	var weights: Dictionary = runtime._resource_terrain_weights.duplicate()
	_expect(weights.size() == 18, "未计算全部平地的权重")
	var open_low: Vector2 = weights[Vector2i(0, 1)] as Vector2
	var cliff_foot: Vector2 = weights[Vector2i(1, 1)] as Vector2
	var upper_level: Vector2 = weights[Vector2i(2, 1)] as Vector2
	var highest_level: Vector2 = weights[Vector2i(4, 1)] as Vector2
	_expect(cliff_foot.x > open_low.x, "崖脚平地没有提高树木权重")
	_expect(cliff_foot.y > open_low.y, "崖脚平地没有提高石头权重")
	_expect(upper_level.y > open_low.y, "高地石头权重没有提高")
	_expect(is_equal_approx(open_low.y, 0.7), "地图边界被误判为悬崖")
	_expect(is_equal_approx(upper_level.y, 2.35), "同时位于崖脚和崖顶的平地权重错误")
	_expect(is_equal_approx(highest_level.y, 1.85), "第三层海拔与崖顶权重错误")
	map.cell_size_m = 3.0
	runtime._build_resource_terrain_weights(map.occupied_cells)
	_expect(runtime._resource_terrain_weights == weights, "地图缩放改变了海拔层权重")
	_expect(is_equal_approx(float(runtime._cliff_foot_distances[Vector2i(1, 1)]), 1.5), "崖脚相邻平地距离没有按半格计算")
	_expect(is_equal_approx(float(runtime._cliff_foot_distances[Vector2i(0, 1)]), 4.5), "距离没有按实际地图格尺寸传播")
	_expect(not runtime._cliff_top_distances.has(Vector2i(0, 1)), "崖顶距离跨海拔传播到低地")
	map.set_height_control(Vector2i(0, 1), 0.0, WFCHeightControl.Kind.STAIRS)
	runtime.height_field = map.create_height_field()
	runtime._build_resource_terrain_weights(map.occupied_cells)
	_expect(not runtime._resource_terrain_weights.has(Vector2i(0, 1)), "阶梯被纳入资源适宜度候选")
	runtime.free()
	if not _failed:
		print("资源地形权重测试通过：三层海拔、崖脚崖顶、地图边界、缩放、距离和阶梯")
	quit(1 if _failed else 0)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		push_error("失败：" + message)
