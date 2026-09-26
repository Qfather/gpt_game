extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene: Node = load("res://Scene/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	var runtime: MapGenerateRuntime = get_first_node_in_group("map_generate_runtime") as MapGenerateRuntime
	var base: Node3D = get_first_node_in_group("bases") as Node3D
	var resources: Node3D = runtime.get_node("GeneratedResources") as Node3D
	var trees: int = 0
	var stones: int = 0
	var nearby_trees: int = 0
	var positions: Array[Vector2] = []
	var tree_positions: Array[Vector2] = []
	var stone_positions: Array[Vector2] = []
	var offset_positions: int = 0
	for node: Node in resources.get_children():
		var resource: ResourceBase = node as ResourceBase
		var position: Vector2 = Vector2(resource.global_position.x, resource.global_position.z)
		if resource.resource_id == &"stone":
			for other: Vector2 in positions:
				_expect(position.distance_to(other) >= 3.79, "石头与其他资源距离不足")
		else:
			for other: Vector2 in tree_positions:
				_expect(position.distance_to(other) >= 1.09, "树木碰撞体重叠")
		positions.append(position)
		var cell_center: Vector3 = runtime._cell_world_position(runtime._grid_to_map_cell(Vector2i(floori(position.x), floori(position.y))))
		if Vector2(cell_center.x, cell_center.z).distance_to(position) > 0.1:
			offset_positions += 1
		var distance: float = position.distance_to(Vector2(base.global_position.x, base.global_position.z))
		_expect(distance >= 6.5, "资源紧贴 Base")
		if resource.resource_id == &"wood":
			trees += 1
			tree_positions.append(position)
			if distance <= 22.0:
				nearby_trees += 1
		elif resource.resource_id == &"stone":
			for other: Vector2 in stone_positions:
				_expect(position.distance_to(other) >= 3.79, "石头之间无法通行")
			stone_positions.append(position)
			stones += 1
	_expect(runtime.map_data.generation_center_clear_circle, "中心空地不是圆形")
	_expect(trees == 72 and stones == 10, "资源数量错误")
	_expect(nearby_trees >= 30, "Base 附近树木不足")
	_expect(offset_positions >= 75, "资源仍按地图格中心排列")
	var close_trees: int = 0
	for position: Vector2 in tree_positions:
		for other: Vector2 in tree_positions:
			if position != other and position.distance_to(other) <= 1.9:
				close_trees += 1
				break
	_expect(close_trees >= 60, "树林中紧邻的树木不足")
	print("资源布局测试通过：树木=", trees, " 石头=", stones, " Base附近树木=", nearby_trees, " 紧邻树木=", close_trees)
	quit()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		push_error("失败：" + message)
		quit(1)
