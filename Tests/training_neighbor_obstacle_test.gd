extends SceneTree
class TestMap extends MapGenerateRuntime:
	func _ready() -> void: add_to_group("map_generate_runtime")
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world
	var region := NavigationRegion3D.new()
	region.name = "NavigationRegion3D"
	world.add_child(region)
	var runtime := TestMap.new()
	world.add_child(runtime)
	runtime._navigation_faces = PackedVector3Array([Vector3(-10,0,-10),Vector3(10,0,-10),Vector3(-10,0,10),Vector3(10,0,-10),Vector3(10,0,10),Vector3(-10,0,10)])
	var camp: SwordsmanCamp = load("res://Scene/building/game/archer_camp.tscn").instantiate()
	world.add_child(camp)
	var tower: Barracks = load("res://Scene/building/game/arrow_tower.tscn").instantiate()
	world.add_child(tower)
	tower.global_position = camp.get_entrance_position()
	tower.set_process(false)
	var mesh: NavigationMesh = runtime._new_navigation_mesh()
	NavigationServer3D.bake_from_source_geometry_data(mesh, runtime._navigation_geometry())
	region.navigation_mesh = mesh
	for frame: int in range(10): await physics_frame
	var manager := TaskManager.new()
	world.add_child(manager)
	manager.set_process(false)
	manager.set_physics_process(false)
	var unit: Node = load("res://Scene/unit/villager.tscn").instantiate()
	world.add_child(unit)
	unit.set_physics_process(false)
	unit.global_position = Vector3(0, 0, 4)
	for frame: int in range(5): await physics_frame
	var task: GameTask = manager.create_task(GameTask.TaskType.TRAIN_SWORDSMAN, camp, camp, 10)
	assert(manager.claim_task(task, unit))
	unit._start_current_task()
	assert(camp.is_at_entrance_front(unit.navigation_agent.target_position))
	var probe := SphereShape3D.new()
	probe.radius = 0.06
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = probe
	query.collision_mask = 1
	query.exclude = [unit.get_rid(), camp.get_node("StaticBody3D").get_rid()]
	for frame: int in range(600):
		if not unit.passing_door: unit.move_to_training()
		await physics_frame
		query.transform = Transform3D(Basis.IDENTITY, unit.global_position + Vector3.UP * 0.5)
		assert(world.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty(), "训练行走和进门动画不能穿过箭塔实体")
		if unit.state == unit.State.TRAINING: break
	if unit.state != unit.State.TRAINING:
		push_error("邻近箭塔阻挡训练入口：position=%s target=%s" % [unit.global_position, unit.navigation_agent.target_position])
		quit(1)
		return
	assert(unit.indoor_building == camp and not unit.visible)
	print("邻近箭塔训练测试通过：中心入口被实体遮挡，居民沿可达正面进入弓箭手训练营")
	world.queue_free()
	await process_frame
	quit()
