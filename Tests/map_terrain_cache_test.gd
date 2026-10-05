extends SceneTree

class CountingHeight extends WFCHeightField:
	var surface_calls: int = 0
	var corner_calls: int = 0
	func get_cell_surface_height(cell: Vector2i) -> float:
		surface_calls += 1
		return super.get_cell_surface_height(cell)
	func get_cell_corners(cell: Vector2i) -> Array[float]:
		corner_calls += 1
		return super.get_cell_corners(cell)

func _init() -> void:
	call_deferred("_run")

func _counting_field(map: WFCMapData) -> CountingHeight:
	var original: WFCHeightField = map.create_height_field()
	var result := CountingHeight.new()
	result.map_size = original.map_size
	result.controls = original.controls
	result.height_step = original.height_step
	return result

func _run() -> void:
	var map := WFCMapData.new()
	map.map_size = Vector2i(6, 4)
	map.cell_size_m = 3.0
	for y: int in range(4):
		for x: int in range(6): map.set_cell(Vector2i(x, y), true)
	map.set_cell(Vector2i.ZERO, false)
	map.set_height_control(Vector2i(2, 1), 3.0, WFCHeightControl.Kind.PLATEAU)
	map.set_height_control(Vector2i(4, 1), 3.0, WFCHeightControl.Kind.SLOPE)
	map.set_height_control(Vector2i(3, 1), 0.0, WFCHeightControl.Kind.STAIRS)
	var runtime := MapGenerateRuntime.new()
	runtime.map_data = map
	var field: CountingHeight = _counting_field(map)
	runtime.height_field = field
	# 同一3米地形格里的九个游戏格，只读取一次高度和可建造性。
	for y: int in range(-3, 0):
		for x: int in range(-3, 0):
			assert(is_equal_approx(runtime._get_grid_ground_height(Vector2i(x, y)), 12.0))
			assert(runtime._is_grid_cell_buildable(Vector2i(x, y)))
	assert(field.surface_calls == 1 and field.corner_calls == 1)
	# 所有格与原始算法对照，覆盖负坐标、边界、空洞、坡道、阶梯和高台。
	var original: WFCHeightField = map.create_height_field()
	var saw_non_buildable: bool = false
	for y: int in range(-8, 8):
		for x: int in range(-11, 11):
			var grid_cell := Vector2i(x, y)
			var map_cell: Vector2i = runtime._grid_to_map_cell(grid_cell)
			var expected_height: float = 0.0
			var expected_buildable: bool = false
			if map.has_cell(map_cell):
				expected_height = (original.get_cell_surface_height(map_cell) + WFCHeightControl.LEVEL_HEIGHT) * map.cell_size_m
				var corners: Array[float] = original.get_cell_corners(map_cell)
				expected_buildable = is_equal_approx(corners[0], corners[1]) and is_equal_approx(corners[0], corners[2]) and is_equal_approx(corners[0], corners[3])
				saw_non_buildable = saw_non_buildable or not expected_buildable
			assert(is_equal_approx(runtime._get_grid_ground_height(grid_cell), expected_height))
			assert(runtime._is_grid_cell_buildable(grid_cell) == expected_buildable)
	assert(saw_non_buildable)
	# 同一运行时替换地形，必须清除旧高度和可建造性缓存。
	map.set_height_control(Vector2i(2, 1), 1.0, WFCHeightControl.Kind.PLATEAU)
	runtime.height_field = _counting_field(map)
	assert(runtime._cell_positions.is_empty() and runtime._map_cell_buildability.is_empty())
	assert(is_equal_approx(runtime._get_grid_ground_height(Vector2i(-3, -3)), 6.0))
	map.set_cell(Vector2i(2, 1), false)
	runtime.height_field = _counting_field(map)
	assert(runtime._get_grid_ground_height(Vector2i(-3, -3)) == 0.0)
	assert(not runtime._is_grid_cell_buildable(Vector2i(-3, -3)))
	runtime.free()
	print("运行时地形缓存验证通过：同格九次仅计算一次、全格原始算法对照、坡道阶梯、边界空洞、重新生成失效")
	quit()
