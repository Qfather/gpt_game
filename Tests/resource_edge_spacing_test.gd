extends SceneTree

var failed: bool = false


func _initialize() -> void:
	call_deferred("_run")


func _expect(value: bool, message: String) -> void:
	if not value:
		failed = true
		push_error("失败：" + message)


func _run() -> void:
	var square := PackedVector2Array([Vector2.ZERO, Vector2.RIGHT, Vector2.ONE, Vector2.DOWN])
	var shifted: PackedVector2Array = ResourceSpacing.transformed(square, Vector2(1.1, 0), 0)
	_expect(is_equal_approx(ResourceSpacing.gap(square, shifted), 0.1), "矩形边缘距离计算错误")
	_expect(ResourceSpacing.gap(square, square) == 0.0, "碰撞重叠没有识别")
	_expect(is_equal_approx(ResourceSpacing.circle_gap(Vector2(1.6, 0.5), 0.5, square), 0.1), "圆形与矩形边缘距离错误")
	var old := MapResourceEntry.new()
	old.scene = load("res://Scene/resource/tree.tscn")
	old.minimum_spacing = 1.1
	old.neighbor_distance_max = 1.8
	old.migrate_spacing()
	old.migrate_spacing()
	_expect(is_equal_approx(old.minimum_spacing, 0.1) and is_equal_approx(old.neighbor_distance_max, 0.8), "旧中心距离迁移或重复迁移错误")
	var dense: float = await _generate(0.1, 0.3)
	var sparse: float = await _generate(1.0, 1.2)
	_expect(sparse > dense + 0.6, "增大留空没有使石群变疏")
	print("资源边缘间距测试", "失败" if failed else "通过", "：紧密平均最近留空=", dense, " 疏松=", sparse)
	quit(1 if failed else 0)


func _generate(minimum: float, maximum: float) -> float:
	var scene: Node = load("res://Scene/main.tscn").instantiate()
	var preset: LevelFlowData = scene.level_preset.duplicate(true) as LevelFlowData
	scene.level_preset = preset
	preset.layout_seed = 42
	preset.map_resources[0].enabled = false
	var entry: MapResourceEntry = preset.map_resources[1]
	entry.spacing_version = 1
	entry.minimum_spacing = minimum
	entry.neighbor_distance_max = maximum
	root.add_child(scene)
	await process_frame
	await process_frame
	var runtime: MapGenerateRuntime = scene.get_node("Systems/MapGenerateRuntime") as MapGenerateRuntime
	var positions: Array[Vector3] = runtime._resource_points
	_expect(positions.size() == 48, "石头未生成满48个")
	var total: float = 0.0
	var neighbors: int = 0
	for a: Vector3 in positions:
		var nearest: float = INF
		for b: Vector3 in positions:
			if a == b:
				continue
			var gap: float = runtime._edge_gap(runtime._point_geometry[a], runtime._point_geometry[b])
			_expect(gap >= minimum - 0.001, "实际边缘留空不足或碰撞重叠")
			nearest = minf(nearest, gap)
		total += nearest
		if nearest <= maximum + 0.01:
			neighbors += 1
	_expect(neighbors >= 36, "簇内扩展失败，石头过于零散")
	var average: float = total / maxf(positions.size(), 1)
	scene.queue_free()
	await process_frame
	await process_frame
	return average
