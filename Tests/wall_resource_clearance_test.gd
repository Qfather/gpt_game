extends SceneTree

var failed: bool = false
var world: Node3D
var grid: BuildGrid
var ghost: BuildingGhost

func _initialize() -> void:
	call_deferred("_run")

func _expect(value: bool, message: String) -> void:
	print("[", "通过" if value else "失败", "] ", message)
	if not value:
		failed = true
		push_error(message)

func _resource(path: String, point: Vector3) -> ResourceBase:
	var resource: ResourceBase = load(path).instantiate()
	world.add_child(resource)
	resource.position = point
	resource.reserved_by = ghost
	return resource

func _site(data: BuildingData, cell: Vector2i) -> ConstructionSite:
	_expect(ghost._create_construction_site(data, cell, 0, false, Transform3D(Basis.IDENTITY, grid.grid_to_world(cell)), false, true), "覆盖资源的墙蓝图可以放下")
	for node: Node in get_nodes_in_group("construction_sites"):
		if not node.is_queued_for_deletion() and node.grid_position == cell:
			node.set_process(false)
			return node as ConstructionSite
	return null

func _worker(site: ConstructionSite, point: Vector3) -> CharacterBody3D:
	var worker = load("res://Scene/unit/villager.tscn").instantiate()
	world.add_child(worker)
	worker.set_physics_process(false)
	for frame: int in range(5): await physics_frame
	worker.global_position = point
	worker.task_site = site
	var task := GameTask.new(&"clearance_build", GameTask.TaskType.BUILD)
	task.target = site
	worker.current_task = task
	worker._set_task_site_navigation_target()
	worker.state = worker.State.MOVE_TO_BUILD_SITE
	return worker

func _arrive(workers: Array[CharacterBody3D]) -> void:
	for frame: int in range(360):
		var arrived := true
		for worker: CharacterBody3D in workers:
			if worker.state == worker.State.MOVE_TO_BUILD_SITE: worker.move_to_build_site()
			if worker.state != worker.State.BUILDING: arrived = false
		await physics_frame
		if arrived: return
	for worker: CharacterBody3D in workers:
		print("到场诊断：", worker.state, " position=", worker.global_position, " target=", worker.navigation_agent.target_position)
	_expect(false, "施工工人实际走到目标")

func _deliver(site: ConstructionSite) -> void:
	for resource_id: StringName in site.required_resources:
		site.receive_delivery(resource_id, site.get_still_needed(resource_id))

func _run() -> void:
	world = Node3D.new()
	root.add_child(world)
	current_scene = world
	var systems := Node3D.new()
	systems.name = "Systems"
	world.add_child(systems)
	grid = BuildGrid.new()
	grid.name = "BuildGrid"
	systems.add_child(grid)
	var roads = preload("res://Script/world/road_manager.gd").new()
	roads.grid = grid
	world.add_child(roads)
	ghost = BuildingGhost.new()
	systems.add_child(ghost)
	ghost.set_process(false)
	var region := NavigationRegion3D.new()
	var mesh := NavigationMesh.new()
	mesh.vertices = PackedVector3Array([Vector3(-20, 0, -20), Vector3(-20, 0, 20), Vector3(20, 0, 20), Vector3(20, 0, -20)])
	mesh.add_polygon(PackedInt32Array([0, 1, 2, 3]))
	region.navigation_mesh = mesh
	world.add_child(region)
	var remote := _resource("res://Scene/resource/tree.tscn", Vector3(-10, 0, -10))
	for frame: int in range(10): await physics_frame
	var index := 0
	for path: String in ["res://data/buildings/WallData.tres", "res://data/buildings/WoodWallData.tres"]:
		var data: BuildingData = load(path)
		var cell := Vector2i(2 + index * 4, 0)
		var obstacle := _resource("res://Scene/resource/tree.tscn" if index == 0 else "res://Scene/resource/stone.tscn", grid.grid_to_world(cell))
		await physics_frame
		ghost.building_data = data
		_expect(ghost.plan_wall_stroke(cell, cell + Vector2i.RIGHT).has(cell), "墙路线允许覆盖资源")
		_expect(not roads.plan_stroke(cell, cell + Vector2i.RIGHT).has(cell), "道路仍绕过资源")
		var original_time: float = data.construction_time
		var site := _site(data, cell)
		if site == null: break
		_expect(site.get_blocking_resource() == obstacle and not obstacle.is_queued_for_deletion() and obstacle.reserved_by == ghost, "蓝图识别障碍但不立即删除或改变预约")
		_deliver(site)
		var first := await _worker(site, grid.grid_to_world(cell) + Vector3(-2, 0, 0))
		site._process(20)
		_expect(site.clearance_progress == 0 and not obstacle.is_queued_for_deletion(), "工人未到场不能远程清理")
		await _arrive([first])
		var second := await _worker(site, first.global_position + Vector3(0, 0, 0.2))
		await _arrive([first, second])
		site._process(4.9)
		_expect(not obstacle.is_queued_for_deletion() and is_equal_approx(site.clearance_progress, 4.9) and site.construction_progress == 0, "两名工人清理4.9秒仍未完成且不计建造进度")
		_expect(obstacle.gather(1, first) == 0 and first.carried_amount == 0 and second.carried_amount == 0, "清障资源不能采集且工人没有资源收入")
		site._process(0.1)
		_expect(obstacle.is_queued_for_deletion() and obstacle.resource_amount == 0 and site.construction_progress == 0, "满5秒直接销毁资源")
		_expect(first.state == first.State.MOVE_TO_BUILD_SITE and second.state == second.State.MOVE_TO_BUILD_SITE, "清完后工人重新走向墙外施工位置")
		await _arrive([first, second])
		site._process(0.25)
		_expect(site.construction_progress > 0 and data.construction_time == original_time, "清障后开始正常建造且原施工时间不变")
		site._process(original_time)
		_expect(site.state == ConstructionSite.State.COMPLETED, "墙最终施工完成")
		first.free()
		second.free()
		await physics_frame
		index += 1
	_expect(is_instance_valid(remote) and remote.resource_amount > 0 and remote.reserved_by == ghost, "周边不阻挡墙的资源保留")
	var shared := _resource("res://Scene/resource/tree.tscn", Vector3(11, 0, 0.5))
	await physics_frame
	var data: BuildingData = load("res://data/buildings/WoodWallData.tres")
	var left := _site(data, Vector2i(10, 0))
	var right := _site(data, Vector2i(11, 0))
	_expect(left.get_blocking_resource() == shared and right.get_blocking_resource() == shared, "相邻墙工地识别同一阻挡资源")
	_deliver(left)
	_deliver(right)
	var a := await _worker(left, Vector3(8, 0, 0.5))
	var b := await _worker(right, Vector3(8, 0, 1))
	await _arrive([a, b])
	left._process(2)
	right._process(3)
	_expect(shared.construction_clearer == left and right.clearance_progress == 0 and not shared.is_queued_for_deletion(), "同一资源不被两个工地重复加速清理")
	left.cancel_construction()
	_expect(not shared.is_queued_for_deletion() and shared.can_gather(), "取消清障恢复采集且不删除未清完资源")
	right._process(4.9)
	_expect(not shared.is_queued_for_deletion(), "接手清理仍需完整5秒")
	right._process(0.1)
	_expect(shared.is_queued_for_deletion(), "另一工地可以接手并完成清障")
	await physics_frame
	a.free()
	b.free()
	var cluster_cell := Vector2i(-5, 0)
	var tree := _resource("res://Scene/resource/tree.tscn", grid.grid_to_world(cluster_cell))
	var stone := _resource("res://Scene/resource/stone.tscn", grid.grid_to_world(cluster_cell))
	await physics_frame
	var cluster := _site(data, cluster_cell)
	_expect(cluster.blocking_resources.size() == 2, "同一工地登记多个阻挡资源")
	_deliver(cluster)
	var cleaner := await _worker(cluster, grid.grid_to_world(cluster_cell) + Vector3(-3, 0, 0))
	await _arrive([cleaner])
	cluster._process(5)
	_expect(tree.is_queued_for_deletion() and not stone.is_queued_for_deletion() and cluster.construction_progress == 0, "第一个资源5秒清完后仍不建造")
	await _arrive([cleaner])
	cluster._process(4.9)
	_expect(not stone.is_queued_for_deletion(), "第二个资源单独计时")
	cluster._process(0.1)
	_expect(stone.is_queued_for_deletion(), "第二个资源也需完整5秒")
	await _arrive([cleaner])
	cluster._process(0.25)
	_expect(cluster.construction_progress > 0, "所有阻挡资源清完后才能建造")
	cleaner.free()
	world.free()
	print("城墙资源清障测试", "失败" if failed else "通过")
	quit(1 if failed else 0)
