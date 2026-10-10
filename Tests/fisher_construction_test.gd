extends SceneTree

func _init() -> void: call_deferred("_run")

func _run() -> void:
	Engine.time_scale = 6.0
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world
	var grid := BuildGrid.new()
	grid.name = "BuildGrid"
	grid.water_rule = func(cell: Vector2i) -> bool: return cell.y < 0
	grid.buildability_rule = func(cell: Vector2i) -> bool: return cell.y >= 0
	grid.ground_height_rule = func(cell: Vector2i) -> float: return 3.0 if cell.y >= 0 else 0.0
	world.add_child(grid)
	var region := NavigationRegion3D.new()
	var mesh := NavigationMesh.new()
	# 与正式地图一样，导航面绕开据点实体，不能让取料后的路线穿过据点。
	mesh.vertices = PackedVector3Array([Vector3(-15,3,0),Vector3(-15,3,15),Vector3(-1.3,3,15),Vector3(-1.3,3,8.8),Vector3(-1.3,3,5.2),Vector3(-1.3,3,0),Vector3(1.3,3,0),Vector3(1.3,3,5.2),Vector3(1.3,3,8.8),Vector3(1.3,3,15),Vector3(15,3,15),Vector3(15,3,0)])
	for polygon: PackedInt32Array in [PackedInt32Array([0,1,2,3,4,5]),PackedInt32Array([6,7,8,9,10,11]),PackedInt32Array([5,4,7,6]),PackedInt32Array([3,2,9,8])]:
		mesh.add_polygon(polygon)
	region.navigation_mesh = mesh
	world.add_child(region)
	var base: Node3D = load("res://Scene/building/base.tscn").instantiate()
	world.add_child(base)
	base.position = Vector3(0,3,7)
	base.add_resource(&"wood",50.0)
	base.add_resource(&"stone",50.0)
	var manager := TaskManager.new()
	world.add_child(manager)
	for index: int in range(2):
		var worker: Node3D = load("res://Scene/unit/villager.tscn").instantiate()
		world.add_child(worker)
		worker.position = Vector3(3+index,3,8)
		worker.hunger_rate = 0.0
		worker.fatigue_rate = 0.0
	for index: int in range(15): await physics_frame
	var ghost := BuildingGhost.new()
	world.add_child(ghost)
	ghost.set_process(false)
	var data: BuildingData = load("res://data/buildings/FisherHutData.tres")
	assert(ghost._create_construction_site(data,Vector2i(-1,-2),0,false,Transform3D(Basis.IDENTITY,Vector3(0,3,-1)),false,false))
	var site: ConstructionSite = get_first_node_in_group("construction_sites")
	assert(site.exterior_construction_started)
	assert(site.construction_progress == 0.0 and site.get_delivered_amount(&"wood") == 0.0)
	var built: Node3D
	var stayed_on_shore := true
	for index: int in range(4200):
		await physics_frame
		await process_frame
		for candidate: Node in get_nodes_in_group("resource_buildings"):
			if candidate.building_data != null and candidate.building_data.id == &"fisher_hut": built = candidate
		if built != null: break
		if not is_instance_valid(site): break
		for worker: Node in site.builders:
			stayed_on_shore = stayed_on_shore and worker.global_position.z >= 0 and not worker.passing_door
		if index % 600 == 0:
			print("施工状态：",site.state," 材料=",site.delivered_resources," 进度=",site.construction_progress)
			for worker: Node in get_nodes_in_group("villagers"):
				print("工人：",worker.state," 位置=",worker.global_position," 目标=",worker.navigation_agent.target_position," 到达=",worker._has_reached_task_site_navigation_target() if worker.task_site != null else false)
	if built == null:
		for worker: Node in get_nodes_in_group("villagers"):
			print("工人：",worker.state," 位置=",worker.global_position," 目标=",worker.navigation_agent.target_position)
		push_error("渔夫小屋实际运料与施工未完成")
		quit(1)
		return
	assert(stayed_on_shore)
	assert(base.get_resource(&"wood") == 25.0 and base.get_resource(&"stone") == 40.0)
	assert(built.global_position.is_equal_approx(Vector3(0,3,-1)))
	assert(built.workers.size() == 1 and built.workers[0].job == built.workers[0].Job.FISHER)
	print("[通过] 实际放置、据点取料、多次往返运料、岸上施工、20游戏秒竣工及自动任职渔民")
	quit(0)
