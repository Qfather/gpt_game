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
	var house: BuildingBase = load("res://Scene/building/game/house.tscn").instantiate()
	world.add_child(house)
	var worker: CharacterBody3D = load("res://Scene/unit/villager.tscn").instantiate()
	world.add_child(worker)
	worker.set_process(false)
	worker.set_physics_process(false)
	worker.position = Vector3(-5,0,0)
	assert(house.has_node("StaticBody3D/CollisionShape3D") and house.is_in_group("navigation_solid_buildings"))
	var solid: CollisionShape3D = house.get_node("StaticBody3D/CollisionShape3D")
	var click: CollisionShape3D = house.get_node("ClickArea/CollisionShape3D")
	assert(is_equal_approx(solid.scale.x, 0.85) and is_equal_approx(click.scale.x, 1.0))
	var mesh: NavigationMesh = runtime._new_navigation_mesh()
	NavigationServer3D.bake_from_source_geometry_data(mesh, runtime._navigation_geometry())
	region.navigation_mesh = mesh
	runtime.navigation_revision = 1
	for frame in range(10): await physics_frame
	# 直接朝墙走也必须被物理碰撞拦住。
	for frame in range(90):
		worker.velocity = Vector3(4,0,0)
		worker.move_and_slide()
		await physics_frame
	assert(worker.position.x < -1.0)
	worker.position = Vector3(-5,0,0)
	worker.navigation_agent.target_position = Vector3(5,0,0)
	var maximum_detour: float = 0.0
	for frame in range(420):
		worker.navigation_agent.get_next_path_position()
		worker.move_along_navigation()
		maximum_detour = maxf(maximum_detour, absf(worker.position.z))
		assert(absf(worker.position.x) >= 1.0 or absf(worker.position.z) >= 1.0)
		if worker.position.distance_to(Vector3(5,0,0)) < 1.6: break
		await physics_frame
	assert(worker.position.distance_to(Vector3(5,0,0)) < 1.6 and maximum_detour > 1.3)
	worker.set_combat_role(CombatRole.Type.SWORDSMAN)
	var enemy: EnemyBase = load("res://Scene/unit/enemy_base.tscn").instantiate()
	world.add_child(enemy)
	enemy.set_process(false)
	enemy.set_physics_process(false)
	enemy.position = Vector3(5,0,0)
	worker.position = Vector3(-5,0,0)
	worker.combat_target = enemy
	maximum_detour = 0.0
	for frame in range(420):
		worker._process_combat(1.0 / 60.0)
		maximum_detour = maxf(maximum_detour, absf(worker.position.z))
		assert(absf(worker.position.x) >= 1.0 or absf(worker.position.z) >= 1.0)
		if worker.position.distance_to(enemy.position) <= 1.6: break
		await physics_frame
	assert(worker.position.distance_to(enemy.position) <= 1.6 and maximum_detour > 1.3)
	worker.set_combat_role(CombatRole.Type.NONE)
	enemy.queue_free()
	var revision: int = runtime.navigation_revision
	house.queue_free()
	for frame in range(180):
		await physics_frame
		if runtime.navigation_revision > revision and not runtime._navigation_dirty and not runtime._navigation_baking and not runtime._navigation_update_queued: break
	assert(runtime.navigation_revision > revision)
	for frame in range(5): await physics_frame
	var path: PackedVector3Array = NavigationServer3D.map_get_path(region.get_navigation_map(), Vector3(-5,0,0),Vector3(5,0,0),true)
	assert(path.size() >= 2)
	for point: Vector3 in path: assert(absf(point.z) < 0.1)
	# 生长资源同时从导航障碍中移除，成熟后才恢复绕行。
	var resources := Node3D.new()
	resources.name = "GeneratedResources"
	runtime.add_child(resources)
	var tree: ResourceBase = load("res://Scene/resource/tree.tscn").instantiate()
	tree.growth_duration = 1.0
	resources.add_child(tree)
	tree.position = Vector3(0,0,6)
	tree.set_process(false)
	mesh = runtime._new_navigation_mesh()
	NavigationServer3D.bake_from_source_geometry_data(mesh, runtime._navigation_geometry())
	region.navigation_mesh = mesh
	for frame in range(10): await physics_frame
	path = NavigationServer3D.map_get_path(region.get_navigation_map(), Vector3(-5,0,6), Vector3(5,0,6), true)
	assert(path.size() >= 2)
	for point: Vector3 in path: assert(absf(point.z - 6.0) < 0.1)
	tree._process(1.0)
	mesh = runtime._new_navigation_mesh()
	NavigationServer3D.bake_from_source_geometry_data(mesh, runtime._navigation_geometry())
	region.navigation_mesh = mesh
	for frame in range(10): await physics_frame
	path = NavigationServer3D.map_get_path(region.get_navigation_map(), Vector3(-5,0,6), Vector3(5,0,6), true)
	var resource_detour: float = 0.0
	for point: Vector3 in path: resource_detour = maxf(resource_detour, absf(point.z - 6.0))
	assert(resource_detour > 0.5)
	tree.queue_free()
	# 全建筑碰撞与功能区域：农场只挡工具屋，城门保留通道。
	for id: String in ["base", "lumber_camp", "quarry", "hunter_hut", "swordsman_camp", "archer_camp", "barracks", "arrow_tower", "torch", "farm", "wall", "gate"]:
		var scene_path: String = "res://Scene/building/base.tscn" if id == "base" else "res://Scene/building/game/%s.tscn" % id
		var building: BuildingBase = load(scene_path).instantiate()
		world.add_child(building)
		assert(building.has_node("StaticBody3D") == (id != "gate"))
		if id == "farm":
			assert(building.get_node("StaticBody3D/CollisionShape3D").position.x == 1)
		building.queue_free()
	world.queue_free()
	await process_frame
	print("建筑阻挡测试通过：实体拦截、实际导航绕路、拆除恢复道路、所有建筑碰撞与农田城门通行")
	quit()
