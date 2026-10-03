extends SceneTree

class TestMap extends MapGenerateRuntime:
	func _ready() -> void:
		add_to_group("map_generate_runtime")

func _init() -> void:
	call_deferred("_run")

func _quad(x0: float, x1: float, y0: float, y1: float) -> PackedVector3Array:
	return PackedVector3Array([Vector3(x0,y0,-12),Vector3(x1,y1,-12),Vector3(x0,y0,12),Vector3(x1,y1,-12),Vector3(x1,y1,12),Vector3(x0,y0,12)])

func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world
	var region := NavigationRegion3D.new()
	region.name = "NavigationRegion3D"
	world.add_child(region)
	var runtime := TestMap.new()
	world.add_child(runtime)
	runtime._navigation_faces = _quad(-15,0,0,0)
	runtime._navigation_faces.append_array(_quad(0,8,0,4))
	runtime._navigation_faces.append_array(_quad(8,20,4,4))
	var base: Node3D = load("res://Scene/building/base.tscn").instantiate()
	world.add_child(base)
	base.position = Vector3(-10,0,6)
	var barracks: Barracks = load("res://Scene/building/game/barracks.tscn").instantiate()
	world.add_child(barracks)
	barracks.position = Vector3(-9,0,-6)
	barracks.set_process(false)
	var mesh: NavigationMesh = runtime._new_navigation_mesh()
	NavigationServer3D.bake_from_source_geometry_data(mesh, runtime._navigation_geometry())
	region.navigation_mesh = mesh
	for i in range(10): await physics_frame
	var supplier: Node3D = load("res://Scene/unit/villager.tscn").instantiate()
	world.add_child(supplier)
	supplier.set_physics_process(false)
	supplier.set_combat_role(CombatRole.Type.ARCHER)
	supplier.position = Vector3(-6,0,-2)
	for i in range(3): await physics_frame
	supplier.resupply_barracks = barracks
	barracks.resupply_workers.append(supplier)
	var archers: Array[Node3D] = []
	for index in range(2):
		var unit: Node3D = load("res://Scene/unit/villager.tscn").instantiate()
		world.add_child(unit)
		unit.set_physics_process(false)
		unit.set_combat_role(CombatRole.Type.ARCHER)
		unit.position = Vector3(-5,0,index * 2)
		archers.append(unit)
	for i in range(3): await physics_frame
	for unit: Node3D in archers:
		assert(unit.garrison_target == barracks and unit.state == unit.State.MOVE_TO_BARRACKS)
	# 通过真实工地完工流程生成高台上的箭塔。
	var site: ConstructionSite = load("res://Scene/building/construction_site.tscn").instantiate()
	site.setup(load("res://data/buildings/ArrowTowerData.tres"), Vector2i(12,0), 0, false)
	site.set_activation_deferred_until_unpause(true)
	world.add_child(site)
	site.position = Vector3(12,4,0)
	site._complete_construction()
	for i in range(3): await physics_frame
	var tower: Barracks
	for building: Node in get_nodes_in_group("buildings"):
		if building.has_method("allows_garrison_attacks"): tower = building
	assert(tower != null)
	tower.set_process(false)
	tower.add_food(&"grain", 10)
	tower.dispatch_available_swordsmen()
	var assigned := true
	for unit: Node3D in archers:
		print("完工后驻军目标：", unit.garrison_target, " 状态：", unit.state)
		assigned = assigned and unit.garrison_target == tower
	if not assigned:
		print("箭塔完工自动分配测试失败：前往普通军营的待命弓箭手没有转向新箭塔")
		world.queue_free()
		await process_frame
		quit(1)
		return
	assert(barracks.garrison_reservations.size() == 1 and barracks.garrison_reservations.has(supplier) and tower.garrison_reservations.size() == 2)
	assert(supplier.garrison_target == barracks and supplier.resupply_barracks == barracks)
	mesh = runtime._new_navigation_mesh()
	NavigationServer3D.bake_from_source_geometry_data(mesh, runtime._navigation_geometry())
	region.navigation_mesh = mesh
	for i in range(10): await physics_frame
	for frame in range(900):
		for unit: Node3D in archers:
			if unit.garrisoned_in == null: unit.move_to_barracks()
		if tower.get_garrison_count() == 2: break
		await physics_frame
	for unit: Node3D in archers:
		print("高台上塔：", unit.garrisoned_in == tower, " 位置：", unit.position)
	assert(tower.get_garrison_count() == 2 and archers[0].position.y == 7.0 and archers[1].position.y == 7.0)
	world.queue_free()
	await process_frame
	print("箭塔完工自动分配测试通过：普通军营预约释放、两名待命弓箭手自动转向新塔并实际走上有坡道的高台")
	quit()
