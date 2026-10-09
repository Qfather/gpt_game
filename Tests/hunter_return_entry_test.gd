extends SceneTree

class TestMap extends MapGenerateRuntime:
	func _ready() -> void: add_to_group("map_generate_runtime")

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	Engine.print_to_stdout = false
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world
	var region := NavigationRegion3D.new()
	region.name = "NavigationRegion3D"
	world.add_child(region)
	var runtime := TestMap.new()
	world.add_child(runtime)
	runtime._navigation_faces = PackedVector3Array([Vector3(-10,0,-10),Vector3(10,0,-10),Vector3(-10,0,10),Vector3(10,0,-10),Vector3(10,0,10),Vector3(-10,0,10)])
	var house: ResourceBuildingBase = load("res://Scene/building/game/hunter_hut.tscn").instantiate()
	house.set_building_data(load("res://data/buildings/HunterHutData.tres"))
	world.add_child(house)
	house.set_process(false)
	house.processing_min = 0.25
	house.processing_max = 0.25
	var mesh: NavigationMesh = runtime._new_navigation_mesh()
	NavigationServer3D.bake_from_source_geometry_data(mesh, runtime._navigation_geometry())
	region.navigation_mesh = mesh
	for frame: int in range(10): await physics_frame
	var hunter: Node = load("res://Scene/unit/villager.tscn").instantiate()
	world.add_child(hunter)
	hunter.set_physics_process(false)
	hunter.set_process(false)
	hunter.assign_job(hunter.Job.HUNTER, house)
	hunter.hunger_rate = 0.0
	hunter.fatigue_rate = 0.0
	hunter.global_position = Vector3(0, 0, 5)
	hunter.hunting.prey_count = 1
	hunter.hunting.raw_meat = 1.0
	hunter.hunting.update_bundle(hunter)
	hunter.hunting.request_return(hunter)
	var start: Vector3 = hunter.global_position
	var saw_edge_stop := false
	for frame: int in range(600):
		if not hunter.passing_door: hunter.hunting.process(hunter, 1.0 / 60.0)
		await physics_frame
		if not house.is_at_entrance_front(hunter.global_position) and house.is_at_entrance_front(hunter.global_position, 0.2): saw_edge_stop = true
		if house.get_resource_amount(&"meat") >= 1.0 and not hunter.passing_door: break
	if house.get_resource_amount(&"meat") != 1.0:
		push_error("猎户回屋卡住：位置%s 目标%s 路径结束%s 严格入口%s 容差入口%s" % [hunter.global_position, hunter.navigation_agent.target_position, hunter.navigation_agent.is_navigation_finished(), house.is_at_entrance_front(hunter.global_position), house.is_at_entrance_front(hunter.global_position, 0.2)])
		quit(1)
		return
	assert(start.distance_to(hunter.global_position) > 0.2 and saw_edge_stop, "必须实际行走并覆盖严格边界之外的导航停止位置")
	assert(hunter.hunting.prey_count == 0 and hunter.hunting.raw_meat == 0.0 and hunter.indoor_building == null)
	# 新一轮返程被战斗打断，敌人释放后继续走回小屋处理。
	hunter.hunting.prey_count = 1
	hunter.hunting.raw_meat = 1.0
	hunter.hunting.update_bundle(hunter)
	hunter.hunting.request_return(hunter)
	var enemy: EnemyBase = load("res://Scene/unit/enemy_base.tscn").instantiate()
	enemy.enemy_data = load("res://data/enemies/raid/SlimeData.tres").duplicate(true)
	world.add_child(enemy)
	enemy.set_physics_process(false)
	enemy.set_process(false)
	enemy.global_position = hunter.global_position + Vector3(2, 0, 0)
	assert(hunter._process_combat(0.016), "返程猎户应能自卫")
	enemy.free()
	hunter._process_combat(0.016)
	assert(hunter.state == hunter.State.HUNTING and hunter.hunting.returning and hunter.hunting.prey_count == 1)
	for frame: int in range(600):
		if not hunter.passing_door: hunter.hunting.process(hunter, 1.0 / 60.0)
		await physics_frame
		if house.get_resource_amount(&"meat") >= 2.0 and not hunter.passing_door: break
	assert(house.get_resource_amount(&"meat") == 2.0 and hunter.hunting.prey_count == 0, "战斗结束必须完成实际入屋、处理与存肉")
	# 邻近箭塔堵住缓存入口后，猎户必须实际改选正面位置并绕开实体。
	hunter.global_position = Vector3(0, 0, 5)
	hunter.hunting.prey_count = 1
	hunter.hunting.raw_meat = 1.0
	hunter.hunting.update_bundle(hunter)
	hunter.hunting.request_return(hunter)
	var blocked_target: Vector3 = hunter._get_reachable_workplace_position()
	hunter.hunting.return_destination = blocked_target
	hunter.navigation_agent.target_position = blocked_target
	var tower: Barracks = load("res://Scene/building/game/arrow_tower.tscn").instantiate()
	world.add_child(tower)
	tower.position = Vector3(blocked_target.x, 0, blocked_target.z)
	tower.set_process(false)
	mesh = runtime._new_navigation_mesh()
	NavigationServer3D.bake_from_source_geometry_data(mesh, runtime._navigation_geometry())
	region.navigation_mesh = mesh
	for frame: int in range(10): await physics_frame
	var probe := SphereShape3D.new()
	probe.radius = 0.06
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = probe
	query.collision_mask = 1
	query.exclude = [hunter.get_rid(), house.get_node("StaticBody3D").get_rid()]
	for frame: int in range(900):
		if not hunter.passing_door: hunter.hunting.process(hunter, 1.0 / 60.0)
		await physics_frame
		query.transform = Transform3D(Basis.IDENTITY, hunter.global_position + Vector3.UP * 0.5)
		if not world.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty():
			push_error("返程穿过箭塔：位置%s 缓存%s 过门%s" % [hunter.global_position, hunter.hunting.return_destination, hunter.passing_door])
			quit(1)
			return
		if house.get_resource_amount(&"meat") >= 3.0 and not hunter.passing_door: break
	if house.get_resource_amount(&"meat") != 3.0:
		push_error("猎户未绕开被堵入口：位置%s 缓存%s 原目标%s" % [hunter.global_position, hunter.hunting.return_destination, blocked_target])
		quit(1)
		return
	assert(hunter.hunting.return_destination.distance_to(blocked_target) > 0.1, "停滞后必须更新返程缓存并选取其他入口")
	Engine.print_to_stdout = true
	print("猎户入口边缘实际行走、入屋处理、战斗恢复与邻近箭塔绕行测试通过")
	world.queue_free()
	await process_frame
	quit()
