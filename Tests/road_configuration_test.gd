extends SceneTree

var failed: bool = false

func _initialize() -> void:
	call_deferred("_run")

func _expect(condition: bool, message: String) -> void:
	print("[", "通过" if condition else "失败", "] ", message)
	if not condition:
		failed = true
		push_error(message)

func _texture(mask: int) -> ImageTexture:
	var image := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.12, 0.16, 0.2))
	image.fill_rect(Rect2i(24, 24, 16, 16), Color.WHITE)
	for index: int in range(4):
		if not (mask & (1 << index)): continue
		var strips: Array[Rect2i] = [Rect2i(24, 0, 16, 32), Rect2i(32, 24, 32, 16), Rect2i(24, 32, 16, 32), Rect2i(0, 24, 32, 16)]
		image.fill_rect(strips[index], Color.WHITE)
	return ImageTexture.create_from_image(image)

func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world
	var grid := BuildGrid.new()
	world.add_child(grid)
	var roads = preload("res://Script/world/road_manager.gd").new()
	roads.grid = grid
	world.add_child(roads)
	var dirt: BuildingData = roads.ROAD_DATA[1]
	var stone: BuildingData = roads.ROAD_DATA[2]
	_expect(dirt.road_speed_percent == 5 and stone.road_speed_percent == 10, "迁移后保留土路5%、石路10%")
	var masks: Array[int] = [0, 1, 5, 3, 11, 15]
	var fields: Array[String] = ["road_texture_isolated", "road_texture_end", "road_texture_straight", "road_texture_corner", "road_texture_t", "road_texture_cross"]
	for shape: int in range(6): dirt.set(fields[shape], _texture(masks[shape]))
	dirt.road_material = StandardMaterial3D.new()
	dirt.road_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dirt.road_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	stone.road_material = dirt.road_material.duplicate()
	stone.road_material.albedo_color = Color(0.55, 0.59, 0.63)
	for mask: int in range(16):
		roads.cells.clear()
		roads.cells[Vector2i.ZERO] = 1
		for index: int in range(4):
			if mask & (1 << index): roads.cells[roads.DIRECTIONS[index]] = 2
		var shape: Vector2i = roads.tile_shape(Vector2i.ZERO)
		var rotated: int = masks[shape.x]
		for turn: int in range(shape.y): rotated = ((rotated << 1) & 15) | (rotated >> 3)
		_expect(rotated == mask, "四邻组合%d选择正确形态和旋转" % mask)
	var material: StandardMaterial3D = dirt.road_shape_material(3)
	_expect(material.albedo_texture == dirt.road_texture_corner and material.texture_filter == BaseMaterial3D.TEXTURE_FILTER_NEAREST, "形态贴图继承共享材质设置")
	_expect(dirt.road_material.albedo_texture == null, "形态材质不覆盖共享材质原数据")
	roads.cells = {Vector2i(7, 2): 1}
	roads._commit([Vector2i(7, 2)])
	var original_mesh: Mesh = roads.chunks[Vector2i.ZERO].mesh
	roads.cells[Vector2i(8, 2)] = 2
	roads._commit([Vector2i(8, 2)])
	_expect(roads.tile_shape(Vector2i(7, 2)).x == 1 and roads.chunks[Vector2i.ZERO].mesh != original_mesh, "跨区块铺路刷新邻格，土路石路互相连接")
	original_mesh = roads.chunks[Vector2i.ZERO].mesh
	roads.remove_cells([Vector2i(8, 2)])
	_expect(roads.tile_shape(Vector2i(7, 2)).x == 0 and roads.chunks[Vector2i.ZERO].mesh != original_mesh, "跨区块拆路恢复独立形态")
	var worker = load("res://Scene/unit/villager.tscn").instantiate()
	world.add_child(worker)
	worker.set_process(false)
	worker.set_physics_process(false)
	worker.position = grid.grid_to_world(Vector2i(7, 2))
	for role: int in [0, 1, 2]:
		worker.set_combat_role(role)
		for speed: float in [2.0, 4.0]:
			worker.base_move_speed = speed
			dirt.road_speed_mode = 0
			dirt.road_speed_add = 1
			_expect(is_equal_approx(worker.get_move_speed(), speed + 1), "身份%d基础速度%.0f固定加速+1" % [role, speed])
			dirt.road_speed_mode = 1
			dirt.road_speed_percent = 25
			_expect(is_equal_approx(worker.get_move_speed(), speed * 1.25), "身份%d基础速度%.0f百分比加速+25%%" % [role, speed])
	dirt.road_speed_percent = 0
	_expect(roads.move_speed(worker.position, 4) == 4, "百分比零加成保持基础速度")
	dirt.road_speed_mode = 0
	dirt.road_speed_add = 0
	_expect(roads.move_speed(worker.position, 4) == 4, "固定值零加成保持基础速度")
	dirt.road_speed_mode = 1
	dirt.road_speed_percent = 25
	dirt.road_speed_add = 1
	grid.occupy_area(Vector2i(7, 2), Vector2i.ONE)
	_expect(roads.move_speed(worker.position, 4) == 4, "建筑占地不提供道路加速")
	grid.occupied_cells.clear()
	_expect(roads.move_speed(worker.position + Vector3.UP * 2, 4) == 4 and roads.move_speed(Vector3(30, 0, 30), 4) == 4, "离开道路或不在同一地面时保持基础速度")
	worker.queue_free()
	roads.cells.clear()
	roads.pending[Vector2i.ZERO] = GameTask.new()
	_expect(roads.move_speed(grid.grid_to_world(Vector2i.ZERO), 4) == 4, "待施工道路不提供加速")
	roads.pending.clear()
	# 保存读回只操作隔离测试资源。
	ResourceSaver.save(dirt, "res://.godot/road_configuration.tres")
	var restored: BuildingData = ResourceLoader.load("res://.godot/road_configuration.tres", "", ResourceLoader.CACHE_MODE_IGNORE_DEEP)
	_expect(restored.road_speed_percent == 25 and restored.road_speed_add == 1 and restored.road_texture_corner != null and restored.road_material.texture_filter == BaseMaterial3D.TEXTURE_FILTER_NEAREST, "加速参数、共享材质及形态贴图保存读回")
	# 一张诊断图覆盖全部四邻组合，使用不同类型的邻路。
	for mask: int in range(16):
		var cell := Vector2i((mask % 4) * 4, (mask / 4) * 4)
		roads.cells[cell] = 1
		for index: int in range(4):
			if mask & (1 << index): roads.cells[cell + roads.DIRECTIONS[index]] = 2
	var changed: Array[Vector2i] = []
	for cell: Vector2i in roads.cells: changed.append(cell)
	roads._commit(changed)
	_expect(roads.chunks.size() < roads.cells.size() and roads.shape_materials.size() <= 13, "各区块共用形态材质，继续合并道路网格")
	if DisplayServer.get_name() != "headless":
		root.size = Vector2i(800, 800)
		var camera := Camera3D.new()
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = 17
		world.add_child(camera)
		camera.position = Vector3(6.5, 20, 6.5)
		camera.rotation_degrees.x = -90
		camera.current = true
		for frame: int in range(8): await process_frame
		RenderingServer.force_draw(false)
		root.get_texture().get_image().save_png("res://.godot/road_connection_shapes.png")
	world.queue_free()
	await process_frame
	print("道路配置测试", "失败" if failed else "通过")
	quit(1 if failed else 0)
