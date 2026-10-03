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
	var tower: Barracks = load("res://Scene/building/game/arrow_tower.tscn").instantiate()
	world.add_child(tower)
	tower.set_process(false)
	var house: BuildingBase = load("res://Scene/building/game/house.tscn").instantiate()
	house.get_node("ClickArea/CollisionShape3D").shape = BoxShape3D.new()
	house.get_node("ClickArea/CollisionShape3D").shape.size = Vector3(4,2,3)
	world.add_child(house)
	house.position = Vector3(0,0,3.5)
	var mesh: NavigationMesh = runtime._new_navigation_mesh()
	NavigationServer3D.bake_from_source_geometry_data(mesh, runtime._navigation_geometry())
	region.navigation_mesh = mesh
	for frame in range(10): await physics_frame
	var archers: Array[Node3D] = []
	for index in range(2):
		var unit: Node3D = load("res://Scene/unit/villager.tscn").instantiate()
		world.add_child(unit)
		unit.set_process(false)
		unit.set_physics_process(false)
		unit.set_combat_role(CombatRole.Type.ARCHER)
		unit.position = Vector3(-6,0,-3 + index)
		archers.append(unit)
	for frame in range(3): await physics_frame
	for unit: Node3D in archers: assert(unit.garrison_target == tower or unit.try_assign_to_barracks(tower))
	# 模拟已经持有旧入口坐标、停在塔下的单位。
	for unit: Node3D in archers:
		unit.navigation_agent.target_position = tower.global_position + Vector3(0,0,2)
	for frame in range(420):
		for unit: Node3D in archers:
			if unit.garrisoned_in == null: unit.move_to_barracks()
		if tower.get_garrison_count() == 2: break
		await physics_frame
	var passed: bool = tower.get_garrison_count() == 2
	passed = passed and archers[0].position.distance_to(archers[1].position) > 1.0
	for unit: Node3D in archers:
		print("上塔：", unit.garrisoned_in == tower, " 位置：", unit.position, " 状态：", unit.state)
	world.queue_free()
	await process_frame
	print("箭塔入口障碍测试", "通过" if passed else "失败")
	quit(0 if passed else 1)
