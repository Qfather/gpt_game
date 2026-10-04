extends SceneTree

var failed: bool = false

func _initialize() -> void:
	call_deferred("_run")

func _expect(ok: bool, message: String) -> void:
	print("[", "通过" if ok else "失败", "] ", message)
	if not ok:
		failed = true
		push_error(message)

func _run() -> void:
	Engine.time_scale = 3.0
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world
	var grid := BuildGrid.new()
	grid.grid_min = Vector2i(-20, -20)
	grid.grid_max = Vector2i(19, 19)
	world.add_child(grid)
	var roads = preload("res://Script/world/road_manager.gd").new()
	roads.grid = grid
	world.add_child(roads)
	var region := NavigationRegion3D.new()
	world.add_child(region)
	var source := NavigationMeshSourceGeometryData3D.new()
	source.add_faces(PackedVector3Array([Vector3(-20, 0, -20), Vector3(20, 0, -20), Vector3(-20, 0, 20), Vector3(20, 0, -20), Vector3(20, 0, 20), Vector3(-20, 0, 20)]), Transform3D.IDENTITY)
	var mesh := NavigationMesh.new()
	mesh.agent_radius = 0.75
	NavigationServer3D.bake_from_source_geometry_data(mesh, source)
	region.navigation_mesh = mesh
	var base = load("res://Scene/building/base.tscn").instantiate()
	world.add_child(base)
	base.position = Vector3(-15, 0, -15)
	base.take_resource(&"stone", base.get_resource(&"stone"))
	base.add_resource(&"stone", 3)
	for frame: int in range(5): await physics_frame
	var cells: Array[Vector2i] = []
	for x: int in range(-9, 9): cells.append(Vector2i(x, 2))
	_expect(roads.place_cells(cells, 1) == 18 and base.get_resource(&"stone") == 3.0, "土路免费且连续铺设")
	_expect(roads.chunks.size() < roads.cells.size(), "道路按区域合并，不为每格创建节点")
	_expect(roads.place_cells(cells, 1) == 0, "重复铺设不产生额外道路")
	_expect(roads.upgrade_all() == 3 and base.get_resource(&"stone") == 0, "石头不足时只升级可支付数量")
	_expect(roads.cells[cells[0]] == 2 and roads.cells[cells[2]] == 2 and roads.cells[cells[3]] == 1, "升级按铺设先后顺序")
	_expect(is_equal_approx(roads.speed_multiplier(grid.grid_to_world(cells[0])), 1.10) and is_equal_approx(roads.speed_multiplier(grid.grid_to_world(cells[3])), 1.05), "石路10%与土路5%速度加成不叠加")
	_expect(roads.place_cells([Vector2i(10, 2)], 2) == 0, "无石头不能新铺石路")
	var start := Vector3(-8.5, 0, 0.5)
	var goal := Vector3(8.5, 0, 0.5)
	var worker = load("res://Scene/unit/villager.tscn").instantiate()
	world.add_child(worker)
	worker.set_process(false)
	worker.set_physics_process(false)
	worker.position = start
	for frame: int in range(4):
		await process_frame
		await physics_frame
	var planned: Variant = roads.preferred_path(start, goal, region.get_navigation_map())
	_expect(planned != null and not planned.is_empty() and planned[-1].distance_to(goal + Vector3.UP * 0.5) < 0.1, "稍绕的道路优于直接横穿平地")
	for role: int in [0, 1, 2, 3]:
		worker.set_combat_role(role if role < 3 else 0)
		if role == 3: worker.job = worker.Job.HUNTER
		worker.position = start
		worker.road_navigation = preload("res://Script/unit/road_navigation.gd").new()
		worker.navigation_agent.target_position = goal
		var maximum_z: float = 0.0
		var queries: int = roads.route_queries
		for frame: int in range(220):
			worker.navigation_agent.get_next_path_position()
			worker.move_along_navigation()
			maximum_z = maxf(maximum_z, worker.position.z)
			if worker.position.distance_to(goal) < 1.6: break
			await physics_frame
		_expect(worker.position.distance_to(goal) < 1.6 and maximum_z > 2.1, "实际角色沿道路绕行并到达目标：身份%d" % role)
		_expect(roads.route_queries - queries <= 2, "沿途复用路线，不每帧重算：身份%d" % role)
	worker.position = start
	var before: int = roads.route_queries
	roads.remove_cells([Vector2i(0, 2)])
	await physics_frame
	var broken: Variant = roads.preferred_path(start, goal, region.get_navigation_map())
	_expect(broken != null and broken.is_empty(), "道路断开后回退普通导航")
	_expect(roads.speed_multiplier(Vector3(0.5, 0, 2.5)) == 1.0, "拆路后不保留加速")
	roads.place_cells([Vector2i(0, 2)], 1)
	var house: BuildingBase = load("res://Scene/building/game/house.tscn").instantiate()
	world.add_child(house)
	house.position = Vector3(0.5, 0, 2.5)
	grid.occupy_area(Vector2i(-1, 1), Vector2i(3, 3))
	source.add_projected_obstruction(PackedVector3Array([Vector3(-1, 0, 1.5), Vector3(2, 0, 1.5), Vector3(2, 0, 3.5), Vector3(-1, 0, 3.5)]), -0.1, 3.0, false)
	var blocked_mesh := NavigationMesh.new()
	blocked_mesh.agent_radius = 0.75
	NavigationServer3D.bake_from_source_geometry_data(blocked_mesh, source)
	region.navigation_mesh = blocked_mesh
	for frame: int in range(5): await physics_frame
	var blocked: Variant = roads.preferred_path(start, goal, region.get_navigation_map())
	_expect(blocked != null and blocked.is_empty(), "建筑阻断道路后不使用旧道路连接")
	worker.position = start
	worker.road_navigation = preload("res://Script/unit/road_navigation.gd").new()
	worker.navigation_agent.target_position = goal
	var clear: bool = true
	for frame: int in range(220):
		worker.navigation_agent.get_next_path_position()
		worker.move_along_navigation()
		if worker.position.x > -0.5 and worker.position.x < 1.5 and worker.position.z > 1.5 and worker.position.z < 3.5: clear = false
		if worker.position.distance_to(goal) < 1.6: break
		await physics_frame
	_expect(clear and worker.position.distance_to(goal) < 1.6, "道路被建筑阻断后实际角色绕开建筑并到达")
	var cell: Vector2i = Vector2i(-5, 2)
	grid.occupy_area(cell, Vector2i.ONE)
	_expect(not roads.can_place(cell) and roads.speed_multiplier(grid.grid_to_world(cell)) == 1.0, "建筑占地禁止铺路且不提供道路加速")
	var geometry: Dictionary = {"center": Vector2(-4.5, 2.5), "radius": 0.3, "height": 0.0, "circle": true}
	_expect(roads.overlaps_resource(geometry), "资源再生避开道路")
	geometry.center = Vector2(-4.5, 4.5)
	_expect(not roads.overlaps_resource(geometry), "道路不阻止附近未重叠资源再生")
	_expect(before >= 4, "测试确实使用了道路寻路")
	world.queue_free()
	await process_frame
	Engine.time_scale = 1.0
	print("道路系统运行测试", "失败" if failed else "通过")
	quit(1 if failed else 0)
