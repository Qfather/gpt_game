extends SceneTree

var _failed: bool = false

func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene: Node = load("res://Scene/main.tscn").instantiate()
	var generator: MapGenerateRuntime = scene.get_node("Systems/MapGenerateRuntime") as MapGenerateRuntime
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--seed="):
			scene.level_preset = scene.level_preset.duplicate(true)
			scene.level_preset.map_config.seed_value = int(argument.trim_prefix("--seed="))
		if argument.begins_with("--layout-seed="):
			generator.settlement_seed = int(argument.trim_prefix("--layout-seed="))
	root.add_child(scene)
	await process_frame
	await process_frame
	var runtime: MapGenerateRuntime = get_first_node_in_group("map_generate_runtime") as MapGenerateRuntime
	var base: Node3D = get_first_node_in_group("bases") as Node3D
	var game_camera: GameCameraController = scene.get_node("Systems/Camera3D") as GameCameraController
	_expect(game_camera.focus_target.is_equal_approx(base.global_position), "开局摄像机未聚焦随机据点")
	_expect(game_camera.focus_destination.is_equal_approx(base.global_position), "摄像机仍向旧据点位置平滑移动")
	_expect(game_camera.unproject_position(base.global_position).distance_to(root.get_visible_rect().size * 0.5) < 1.0, "据点没有投影到屏幕中心")
	var base_mesh: BoxMesh = (base.get_node("MeshInstance3D") as MeshInstance3D).mesh as BoxMesh
	_expect(base_mesh.size == Vector3(2, 2, 3), "据点模型不是 2×3 占地")
	var grid: BuildGrid = scene.get_node("Systems/BuildGrid") as BuildGrid
	_expect((base as BuildingBase).build_grid_size == Vector2i(2, 3), "据点未登记 2×3 占地")
	_expect(grid.occupied_cells.size() == 6, "据点占地不是六格")
	var ocean: MeshInstance3D = scene.get_node("Ocean") as MeshInstance3D
	_expect(ocean.global_position.y < base.global_position.y and ocean.mesh is PlaneMesh, "海面没有位于岛屿下方")
	for index: int in range(24):
		var angle: float = TAU * float(index) / 24.0
		game_camera._move_focus(Vector3(cos(angle), 0, sin(angle)) * 1000.0)
		var point: Vector2 = Vector2(game_camera.focus_target.x, game_camera.focus_target.z)
		var on_island: bool = false
		for cell: Rect2 in game_camera.island_cells:
			on_island = on_island or cell.has_point(point)
		_expect(on_island, "镜头焦点移出了岛屿轮廓")
	game_camera.focus_on_position(base.global_position)
	var resources: Node3D = runtime.get_node("GeneratedResources") as Node3D
	var checked_positions: Array[Vector3] = []
	var trees: int = 0
	var stones: int = 0
	var nearby_trees: int = 0
	var nearby_stones: int = 0
	var distant_trees: int = 0
	var distant_stones: int = 0
	var highland_resources: int = 0
	var positions: Array[Vector2] = []
	var tree_positions: Array[Vector2] = []
	var stone_positions: Array[Vector2] = []
	var offset_positions: int = 0
	for node: Node in resources.get_children():
		var resource: ResourceBase = node as ResourceBase
		var position: Vector2 = Vector2(resource.global_position.x, resource.global_position.z)
		for passage: Rect2 in runtime._resource_passages:
			var outline := PackedVector2Array([passage.position, Vector2(passage.end.x, passage.position.y), passage.end, Vector2(passage.position.x, passage.end.y)])
			var passage_geometry: Dictionary = {"circle": false, "outline": outline}
			_expect(runtime._edge_gap(runtime._point_geometry[resource.global_position], passage_geometry) > 0.0, "资源碰撞体侵入坡道出入口或狭窄连接带")
		for other: Vector3 in checked_positions:
			var gap: float = runtime._edge_gap(runtime._point_geometry[resource.global_position], runtime._point_geometry[other])
			var required: float = maxf(runtime._point_spacings[resource.global_position], runtime._point_spacings[other])
			_expect(gap >= required - 0.001, "资源碰撞边缘留空不足")
		checked_positions.append(resource.global_position)
		positions.append(position)
		var cell_center: Vector3 = runtime._cell_world_position(runtime._grid_to_map_cell(Vector2i(floori(position.x), floori(position.y))))
		var resource_cell: Vector2i = runtime._grid_to_map_cell(Vector2i(floori(position.x), floori(position.y)))
		if runtime.height_field.get_cell_surface_height(resource_cell) > 0.0:
			highland_resources += 1
		_expect(is_equal_approx(resource.global_position.y, cell_center.y), "资源没有按所在海拔贴地")
		if Vector2(cell_center.x, cell_center.z).distance_to(position) > 0.1:
			offset_positions += 1
		var distance: float = position.distance_to(Vector2(base.global_position.x, base.global_position.z))
		_expect(distance >= 6.5, "资源紧贴 Base")
		if resource.resource_id == &"wood":
			trees += 1
			tree_positions.append(position)
			if distance <= 22.0:
				nearby_trees += 1
			if distance > 24.0:
				distant_trees += 1
		elif resource.resource_id == &"stone":
			if distance <= 24.0:
				nearby_stones += 1
			else:
				distant_stones += 1
			var visuals: Node3D = resource.get_node("meshs") as Node3D
			var shape: CollisionShape3D = resource.get_node("StaticBody3D/CollisionShape3D") as CollisionShape3D
			_expect(visuals.get_child_count() == 1, "石头没有只保留一种外观")
			_expect(visuals.scale.x >= 0.5 and visuals.scale.x <= 1.5, "石头外观缩放超出范围")
			_expect((shape.shape as BoxShape3D).size == Vector3(1.0, 0.5, 1.0), "石头碰撞体未同步缩小")
			stone_positions.append(position)
			stones += 1
	_expect(runtime.map_data.generation_center_clear_circle, "中心空地不是圆形")
	var base_cell: Vector2i = runtime._grid_to_map_cell(Vector2i(floori(base.global_position.x), floori(base.global_position.z)))
	_expect(runtime._is_safe_base_cell(base_cell), "据点没有落在中心平地安全范围")
	_expect(nearby_stones >= stones * 0.3, "据点附近起步石群不足")
	_expect(distant_stones >= stones * 0.3, "地图远处缺少石群")
	_expect(distant_trees >= trees * 0.3, "地图远处缺少树林")
	_expect(trees == runtime.tree_count and stones == runtime.stone_count, "资源数量错误")
	_expect(nearby_trees >= trees * 0.3, "Base 附近树木不足")
	_expect(offset_positions >= (trees + stones) * 0.9, "资源仍按地图格中心排列")
	var close_trees: int = 0
	for position: Vector2 in tree_positions:
		for other: Vector2 in tree_positions:
			if position != other and position.distance_to(other) <= 1.9:
				close_trees += 1
				break
	_expect(close_trees >= trees * 0.8, "树林中紧邻的树木不足")
	var close_stones: int = 0
	for position: Vector2 in stone_positions:
		for other: Vector2 in stone_positions:
			if position != other and position.distance_to(other) <= 1.91:
				close_stones += 1
				break
	_expect(close_stones >= stones * 0.8, "石群仍然过于分散")
	print("紧邻石头=", close_stones, "/", stones)
	print("远处树木=", distant_trees, " 远处石头=", distant_stones, " 高台资源=", highland_resources)
	var terrain_heights: Array = []
	for cell: Vector2i in runtime.map_data.occupied_cells:
		terrain_heights.append(runtime.height_field.get_cell_corners(cell))
	print("地形签名=", hash([runtime.map_data.occupied_cells, terrain_heights]), " 资源签名=", hash(positions), " 近处石头=", nearby_stones)
	print("资源布局测试", "失败" if _failed else "通过", "：树木=", trees, " 石头=", stones, " Base附近树木=", nearby_trees, " 紧邻树木=", close_trees)
	if "--preview" in OS.get_cmdline_user_args() or "--camera-preview" in OS.get_cmdline_user_args():
		for layer: Node in scene.find_children("*", "CanvasLayer", true, false):
			layer.set("visible", false)
		if "--preview" in OS.get_cmdline_user_args():
			var camera: Camera3D = Camera3D.new()
			camera.projection = Camera3D.PROJECTION_ORTHOGONAL
			camera.size = 100.0
			scene.add_child(camera)
			camera.position = Vector3(0.0, 120.0, 0.0)
			camera.rotation_degrees.x = -90.0
			camera.make_current()
		await process_frame
		await RenderingServer.frame_post_draw
		var screenshot: Image = root.get_texture().get_image()
		var preview_path: String = "res://.godot/startup_camera.png" if "--camera-preview" in OS.get_cmdline_user_args() else "res://.godot/resource_layout_stage2.png"
		var result: Error = screenshot.save_png(preview_path)
		_expect(result == OK, "资源布局预览图保存失败")
	quit(1 if _failed else 0)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		push_error("失败：" + message)
