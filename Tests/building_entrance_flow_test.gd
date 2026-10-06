extends SceneTree

var exit_order: Array[int] = []

func _init() -> void:
	call_deferred("_run")

func _worker(world: Node3D) -> Node3D:
	var worker: Node3D = load("res://Scene/unit/villager.tscn").instantiate()
	world.add_child(worker)
	worker.set_physics_process(false)
	return worker

func _exit(worker: Node, index: int) -> void:
	await worker._leave_shelter()
	exit_order.append(index)

func _capture(name: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/" + name + ".png")

func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world
	var region := NavigationRegion3D.new()
	var navigation := NavigationMesh.new()
	navigation.vertices = PackedVector3Array([Vector3(-30,0,-30), Vector3(-30,0,30), Vector3(30,0,30), Vector3(30,0,-30)])
	navigation.add_polygon(PackedInt32Array([0,1,2,3]))
	region.navigation_mesh = navigation
	world.add_child(region)
	if DisplayServer.get_name() != "headless":
		var camera := Camera3D.new()
		world.add_child(camera)
		camera.position = Vector3(13, 13, 16)
		camera.look_at(Vector3(0, 0, -3))
		camera.make_current()
		var light := DirectionalLight3D.new()
		world.add_child(light)
		light.rotation_degrees = Vector3(-55, -20, 0)
		var floor := MeshInstance3D.new()
		var plane := PlaneMesh.new()
		plane.size = Vector2(40,40)
		floor.mesh = plane
		world.add_child(floor)
	var base: Node3D = load("res://Scene/building/base.tscn").instantiate()
	world.add_child(base)
	base.position = Vector3(-8, 0, 0)
	var manager: Node = load("res://Script/task_manager.gd").new()
	world.add_child(manager)
	await process_frame
	manager.dispatch_queued = true
	var house: BuildingBase = load("res://Scene/building/game/house.tscn").instantiate()
	world.add_child(house)
	house.rotation.y = PI / 2
	house.scale.x = -1
	var a: Node = _worker(world)
	var b: Node = _worker(world)
	for frame: int in range(10): await physics_frame
	assert(house.get_interaction_position(a).is_equal_approx(house.get_interaction_position(b)))
	assert(house.to_local(house.get_entrance_position()).z > 0.0)
	for worker: Node in [a, b]:
		worker.shelter_target = house
		house.reserve_shelter(worker)
		worker.position = house.get_interior_position()
		worker.visible = false
		worker.state = worker.State.SHELTERED
	var inside: Vector3 = a.position
	_exit(a, 0)
	_exit(b, 1)
	assert(a.position.is_equal_approx(inside) and a.visible and not b.visible)
	await create_timer(0.1).timeout
	assert(a.position.distance_to(inside) > 0.01 and not b.visible)
	await create_timer(1.6).timeout
	assert(exit_order == [0, 1])
	assert(a.position.distance_to(house.get_entrance_position()) < 0.01)
	assert(b.position.distance_to(house.get_entrance_position()) < 0.01)
	assert(house.door_queue.is_empty())
	var removed := Node.new()
	world.add_child(removed)
	house.join_door_queue(removed)
	removed.free()
	house.join_door_queue(a)
	assert(house.has_door_turn(a))
	house.release_door(a)
	var camp: ResourceBuildingBase = load("res://Scene/building/game/lumber_camp.tscn").instantiate()
	world.add_child(camp)
	camp.position = Vector3(6, 0, 0)
	var carrier: Node = _worker(world)
	for frame: int in range(10): await physics_frame
	carrier.workplace = camp
	carrier.job = carrier.Job.LUMBERJACK
	carrier.position = camp.get_entrance_position()
	carrier.carried_resource_id = &"wood"
	carrier.carried_amount = 4.0
	carrier.state = carrier.State.DEPOSIT_TO_WORKPLACE
	var stored: float = camp.get_resource_amount(&"wood")
	carrier.deposit_to_workplace()
	assert(carrier.passing_door and carrier.carried_amount == 4.0)
	await create_timer(2.0).timeout
	assert(not carrier.passing_door and carrier.visible)
	assert(carrier.carried_amount == 0.0 and camp.get_resource_amount(&"wood") == stored + 4.0)
	assert(carrier.position.distance_to(camp.get_entrance_position()) < 0.01)
	var hut: ResourceBuildingBase = load("res://Scene/building/game/hunter_hut.tscn").instantiate()
	hut.building_data = load("res://data/buildings/HunterHutData.tres")
	world.add_child(hut)
	hut.position = Vector3(8, 0, -8)
	var hunter: Node = _worker(world)
	for frame: int in range(10): await physics_frame
	hunter.workplace = hut
	hunter.job = hunter.Job.HUNTER
	hunter.state = hunter.State.HUNTING
	hunter.position = hut.get_entrance_position()
	hunter.hunting.returning = true
	hunter.hunting.prey_count = 1
	hunter.hunting.raw_meat = 3.0
	hunter.hunting.processing_time = 0.1
	var meat_before: float = hut.get_resource_amount(&"meat")
	hunter.hunting.process(hunter, 0.01)
	await create_timer(1.0).timeout
	assert(hunter.hunting.inside_processing and not hunter.visible)
	hunter.hunting.process(hunter, 1.0)
	await create_timer(1.0).timeout
	assert(hunter.visible and not hunter.hunting.inside_processing)
	assert(hut.get_resource_amount(&"meat") == meat_before + 3.0)
	var site: ConstructionSite = load("res://Scene/building/construction_site.tscn").instantiate()
	var data: BuildingData = load("res://data/buildings/SwordsmanCampData.tres").duplicate(true)
	data.construction_time = 1.0
	site.setup(data, Vector2i.ZERO, 0, false)
	site.delivered_resources = site.required_resources.duplicate()
	world.add_child(site)
	site.position = Vector3(0, 0, -7)
	site.set_process(false)
	var builder: Node = _worker(world)
	for frame: int in range(10): await physics_frame
	site.register_construction_worker(builder)
	site.add_builder(builder)
	site.state = site.State.BUILDING
	builder.task_site = site
	builder.state = builder.State.BUILDING
	builder.position = site.get_worker_target_position(builder)
	var task: GameTask = manager.create_task(GameTask.TaskType.BUILD, site, site)
	task.assigned_worker = builder
	task.state = GameTask.State.IN_PROGRESS
	builder.current_task = task
	site._process(0.6)
	assert(not site.exterior_construction_started and is_equal_approx(site.construction_progress, 0.6))
	site._process(0.2)
	assert(site.exterior_construction_started and builder.construction_repositioning)
	assert(is_equal_approx(site.construction_progress, 0.7))
	site._process(1.0)
	assert(is_equal_approx(site.construction_progress, 0.7))
	await create_timer(2.0).timeout
	assert(not builder.construction_repositioning)
	var outside: Vector3 = site.to_local(builder.position)
	assert(outside.x < site.model_bounds.position.x or outside.x > site.model_bounds.end.x or outside.z < site.model_bounds.position.z or outside.z > site.model_bounds.end.z)
	var builder_visual: Node3D = builder.visual_root if is_instance_valid(builder.visual_instance) else builder.body_mesh
	var toward_building: Vector3 = site.global_position - builder.global_position
	var expected_yaw: float = atan2(toward_building.x, toward_building.z)
	assert(is_equal_approx(float(builder_visual.get_meta("facing_target_yaw")), expected_yaw), "移到外围后应面向建筑")
	preload("res://Script/unit/unit_facing.gd").update(builder_visual, 0.4)
	assert(absf(wrapf(builder_visual.global_rotation.y - expected_yaw, -PI, PI)) < 0.01, "沿用平滑转身后面向建筑施工")
	assert(site.get_node("EntranceArrow") != null)
	await _capture("building-door-exterior")
	var second_builder: Node = _worker(world)
	for frame: int in range(10): await physics_frame
	site.register_construction_worker(second_builder)
	site.add_builder(second_builder)
	second_builder.task_site = site
	second_builder.state = second_builder.State.BUILDING
	second_builder.position = site.position
	second_builder.move_to_construction_position(site, site.get_worker_target_position(second_builder))
	site._process(0.4)
	assert(site.state == site.State.BUILDING and second_builder.construction_repositioning)
	await create_timer(2.0).timeout
	assert(not second_builder.construction_repositioning)
	site._process(0.0)
	await process_frame
	await process_frame
	assert(builder.current_task == null and builder.state == builder.State.RETURN_TO_IDLE)
	print("门口流程通过：旋转镜像、两人依次出门、入屋卸货和猎物处理再出门、70%移出暂停计时并转向建筑、多人全部移出后完工、训练场完工返回据点")
	world.queue_free()
	await process_frame
	quit()
