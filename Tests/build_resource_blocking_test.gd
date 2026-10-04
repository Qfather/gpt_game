extends SceneTree

var failed: bool = false


func _initialize() -> void:
	call_deferred("_run")


func _expect(value: bool, message: String) -> void:
	if not value:
		failed = true
		push_error("失败：" + message)


func _run() -> void:
	var grid := BuildGrid.new()
	root.add_child(grid)
	var tree: ResourceBase = load("res://Scene/resource/tree.tscn").instantiate() as ResourceBase
	root.add_child(tree)
	tree.position = Vector3(1.4, 0, 1.4)
	_expect(grid.is_area_free(Vector2i.ZERO, Vector2i.ONE), "树木圆形边缘未碰到建筑，不能因外接矩形角落而阻挡")
	_expect(grid.occupy_area(Vector2i.ZERO, Vector2i.ONE), "靠近圆形资源的合法预览也必须允许最终摆放")
	grid.release_area(Vector2i.ZERO, Vector2i.ONE)
	tree.position = Vector3(1.52, 0, 0.5)
	_expect(grid.is_area_free(Vector2i.ZERO, Vector2i.ONE), "建筑与树木之间有2厘米间隙时允许摆放")
	tree.position = Vector3(0.9, 0, 0.9)
	_expect(not grid.is_area_free(Vector2i.ZERO, Vector2i.ONE), "树木没有阻挡预览合法性")
	_expect(not grid.occupy_area(Vector2i.ZERO, Vector2i.ONE), "最终占地没有拦截资源重叠")
	_expect(grid.occupied_cells.is_empty(), "失败的放置污染建筑占地")
	_expect(grid.is_area_free(Vector2i(3, 3), Vector2i.ONE), "空地被错误阻挡")
	var second: ResourceBase = load("res://Scene/resource/tree.tscn").instantiate() as ResourceBase
	root.add_child(second)
	second.position = tree.position
	tree.gather(tree.resource_amount)
	await process_frame
	_expect(not grid.is_area_free(Vector2i.ZERO, Vector2i.ONE), "清除一棵树错误释放另一棵树占地")
	second.gather(second.resource_amount)
	await process_frame
	_expect(grid.is_area_free(Vector2i.ZERO, Vector2i.ONE), "采完后没有恢复建造")
	var stone: ResourceBase = load("res://Scene/resource/stone.tscn").instantiate() as ResourceBase
	root.add_child(stone)
	stone.position = Vector3(4.2, 0, 2.2)
	stone.rotation.y = PI / 4
	stone.scale = Vector3.ONE * 1.2
	_expect(not grid.is_area_free(Vector2i(3, 2), Vector2i.ONE), "只检查资源中心，遗漏旋转缩放后的边缘")
	_expect(grid.is_area_free(Vector2i(1, 1), Vector2i(2, 4)), "未旋转建筑错误阻挡")
	_expect(not grid.is_area_free(Vector2i(1, 1), Vector2i(2, 4), 1), "旋转建筑遗漏资源重叠")
	stone.gather(stone.resource_amount)
	await process_frame
	var rotated_stone: ResourceBase = load("res://Scene/resource/stone.tscn").instantiate()
	root.add_child(rotated_stone)
	var shape := BoxShape3D.new()
	shape.size = Vector3.ONE
	rotated_stone.get_node("StaticBody3D/CollisionShape3D").shape = shape
	rotated_stone.position = Vector3(1.65, 0, 1.65)
	rotated_stone.rotation.y = PI / 4
	_expect(grid.is_area_free(Vector2i.ZERO, Vector2i.ONE), "旋转石头的外接矩形角落不应阻挡没有重叠的建筑")
	rotated_stone.position = Vector3(1.2, 0, 1.2)
	_expect(not grid.is_area_free(Vector2i.ZERO, Vector2i.ONE), "旋转石头真实边缘重叠仍禁止摆放")
	rotated_stone.queue_free()
	await process_frame
	_expect(grid.occupy_area(Vector2i(1, 1), Vector2i(2, 4), 1), "石头采完后仍无法最终放置")
	grid.free()
	await process_frame
	print("建筑资源阻挡测试", "失败" if failed else "通过", "：树石、边缘、旋转缩放、最终占地、采集释放")
	quit(1 if failed else 0)
