extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world
	var manager := TaskManager.new()
	world.add_child(manager)
	var base: Node3D = load("res://Scene/building/base.tscn").instantiate()
	world.add_child(base)
	var storage: ResourceStorage = base.get_node("ResourceStorage")
	storage.add(&"wood", 100)
	var worker: Node3D = load("res://Scene/unit/villager.tscn").instantiate()
	world.add_child(worker)
	worker.set_physics_process(false)
	worker.collision_mask = 0
	var map: RID = NavigationServer3D.map_create()
	NavigationServer3D.map_set_active(map, true)
	var region: RID = NavigationServer3D.region_create()
	var mesh := NavigationMesh.new()
	mesh.vertices = PackedVector3Array([Vector3(-8,0,-8),Vector3(-8,0,8),Vector3(8,0,8),Vector3(8,0,-8)])
	mesh.add_polygon(PackedInt32Array([0,1,2,3]))
	NavigationServer3D.region_set_navigation_mesh(region, mesh)
	NavigationServer3D.region_set_map(region, map)
	worker.navigation_agent.set_navigation_map(map)
	var house: BuildingBase = load("res://Scene/building/game/house.tscn").instantiate()
	house.building_data = load("res://data/buildings/HouseData.tres").duplicate(true)
	world.add_child(house)
	house.position = Vector3(4,0,0)
	for index in range(10): await physics_frame
	house.take_damage(house.get_max_health() * 0.5 + house.armor)
	for index in range(3): await process_frame
	var task: GameTask = worker.current_task
	assert(task != null and task.type == GameTask.TaskType.REPAIR_BUILDING)
	assert(manager.create_repair_task(house) == task)
	worker._start_current_task()
	for index in range(180):
		worker._process_building_repair(0.0)
		if worker.state == worker.State.REPAIRING: break
		await physics_frame
	assert(worker.state == worker.State.REPAIRING and worker.position.x > 2)
	var before: float = storage.get_amount(&"wood")
	worker._process_building_repair(2.0 / worker.get_work_speed())
	assert(is_equal_approx(house.get_health(), house.get_max_health() * 0.7))
	assert(is_equal_approx(storage.get_amount(&"wood"), before - 8))
	var retained: float = storage.take(&"wood", 1000)
	worker._process_building_repair(1.0)
	assert(task.data["waiting_resources"] and is_equal_approx(house.get_health(), house.get_max_health() * 0.7))
	storage.add(&"wood", retained)
	worker._process_building_repair(3.0 / worker.get_work_speed())
	worker._process_building_repair(0.0)
	assert(is_equal_approx(house.get_health(), house.get_max_health()))
	assert(is_equal_approx(storage.get_amount(&"wood"), before - 20))
	assert(task.state == GameTask.State.COMPLETED and worker.current_task == null)
	house.take_damage(30)
	await process_frame
	var unfinished: GameTask = manager.create_repair_task(house)
	house.queue_free()
	await process_frame
	assert(unfinished.state == GameTask.State.CANCELLED and worker.current_task == null)
	world.queue_free()
	await process_frame
	NavigationServer3D.free_rid(region)
	NavigationServer3D.free_rid(map)
	print("建筑维修测试通过：自动领任务、实际行走、单任务、比例费用与耗时、缺料等待、销毁清理")
	quit()
