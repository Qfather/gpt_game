extends SceneTree

class TestMap extends MapGenerateRuntime:
	func _ready() -> void:
		add_to_group("map_generate_runtime")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world
	var region := NavigationRegion3D.new()
	region.name = "NavigationRegion3D"
	world.add_child(region)
	var runtime := TestMap.new()
	world.add_child(runtime)
	runtime._navigation_faces = PackedVector3Array([Vector3(-12,0,-12),Vector3(12,0,-12),Vector3(-12,0,12),Vector3(12,0,-12),Vector3(12,0,12),Vector3(-12,0,12)])
	var manager := TaskManager.new()
	world.add_child(manager)
	manager.set_process(false)
	manager.set_physics_process(false)
	var base: BuildingBase = load("res://Scene/building/base.tscn").instantiate()
	world.add_child(base)
	base.position = Vector3(-8,0,-6)
	var storage: ResourceStorage = base.get_node("ResourceStorage")
	storage.add(&"wood", 100)
	storage.add(&"stone", 100)
	var tower: BuildingBase = load("res://Scene/building/game/arrow_tower.tscn").instantiate()
	tower.building_data = load("res://data/buildings/ArrowTowerData.tres")
	world.add_child(tower)
	if "--full-collision" in OS.get_cmdline_user_args():
		tower.get_node("StaticBody3D/CollisionShape3D").scale = Vector3.ONE
	var mesh: NavigationMesh = runtime._new_navigation_mesh()
	NavigationServer3D.bake_from_source_geometry_data(mesh, runtime._navigation_geometry())
	region.navigation_mesh = mesh
	var worker: CharacterBody3D = load("res://Scene/unit/villager.tscn").instantiate()
	world.add_child(worker)
	worker.position = Vector3(-6,0,0)
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--approach="):
			var angle: float = float(argument.trim_prefix("--approach=")) * PI / 2.0
			worker.position = Vector3(cos(angle) * 6.0, 0, sin(angle) * 6.0)
	worker.set_physics_process(false)
	for frame in range(10): await physics_frame
	tower.take_damage(101)
	var task: GameTask = manager.create_repair_task(tower)
	assert(manager.claim_task(task, worker))
	worker._start_current_task()
	var before: float = tower.get_health()
	for frame in range(420):
		worker._process_building_repair(1.0 / 60.0)
		await physics_frame
		if tower.get_health() > before: break
	print("箭塔维修诊断：居民位置=", worker.position, " 导航目标=", worker.navigation_agent.target_position, " 状态=", worker.state, " 血量=", tower.get_health(), " 任务=", task.data)
	if tower.get_health() <= before:
		push_error("居民到箭塔后未开始回血")
		quit(1)
		return
	for frame in range(600):
		worker._process_building_repair(1.0 / 60.0)
		await physics_frame
		if task.state == GameTask.State.COMPLETED: break
	assert(is_equal_approx(tower.get_health(), tower.get_max_health()))
	assert(task.state == GameTask.State.COMPLETED and worker.current_task == null)
	# 排除“等待石头”与实际维修不回血混淆，补齐材料后应继续修。
	var retained: float = storage.take(&"stone", 1000)
	tower.take_damage(51)
	task = manager.create_repair_task(tower)
	assert(manager.claim_task(task, worker))
	worker._start_current_task()
	worker.state = worker.State.REPAIRING
	before = tower.get_health()
	worker._process_building_repair(0.1)
	assert(task.data["waiting_resources"] and tower.get_health() == before)
	storage.add(&"stone", retained)
	worker._process_building_repair(100.0)
	worker._process_building_repair(0.0)
	assert(tower.get_health() == tower.get_max_health() and task.state == GameTask.State.COMPLETED)
	print("箭塔维修通过：真实导航靠近、增加血量、修满后居民释放任务")
	world.queue_free()
	await process_frame
	quit()
