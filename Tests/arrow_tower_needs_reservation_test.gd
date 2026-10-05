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
	tower.enter_garrison(archers[0])
	var waiting: Node3D = archers[1]
	for needs_state: int in [waiting.State.NEED_EAT, waiting.State.NEED_REST]:
		waiting._remember_garrison_state_before_needs()
		waiting.state = needs_state
		assert(tower.get_garrison_occupancy_count() == 2)
		assert(tower.garrison_reservations.has(waiting), "途中吃饭和休息都应保留驻扎名额")
		assert(waiting._resume_garrison_after_needs())
	# 恢复旧游戏中已丢失预约、实际停在入口的弓箭手。
	tower.garrison_reservations.erase(waiting)
	Engine.time_scale = 3.0
	waiting.set_physics_process(true)
	for frame: int in range(600):
		await physics_frame
		if waiting.garrisoned_in == tower: break
	waiting.set_physics_process(false)
	Engine.time_scale = 1.0
	print("真实物理更新抵达：状态=", waiting.state, " 位置=", waiting.position, " 驻扎=", waiting.garrisoned_in == tower)
	assert(waiting.garrisoned_in == tower)
	assert(waiting.state == waiting.State.GARRISONED)
	assert(tower.get_garrison_count() == 2 and tower.garrison_reservations.is_empty())
	assert(archers[0].global_position.distance_to(waiting.global_position) > 1.0)
	# 重复抵达不得重复加入；第三人即使持有旧目标也不能挤进满塔。
	tower.enter_garrison(waiting)
	assert(tower.garrisoned_units.size() == 2)
	var third: Node3D = load("res://Scene/unit/villager.tscn").instantiate()
	world.add_child(third)
	third.set_physics_process(false)
	third.set_combat_role(CombatRole.Type.ARCHER)
	third.garrison_target = tower
	third.state = third.State.MOVE_TO_BARRACKS
	tower.enter_garrison(third)
	assert(third.garrisoned_in == null and tower.get_garrison_count() == 2)
	print("吃饭／休息预约保留、旧预约丢失恢复、两人分开驻扎、重复抵达和满塔拒绝验证通过")
	if DisplayServer.get_name() != "headless":
		root.size = Vector2i(1280, 720)
		var camera := Camera3D.new()
		world.add_child(camera)
		camera.position = Vector3(7, 10, 10)
		camera.look_at(Vector3(0, 2, 0))
		camera.make_current()
		var light := DirectionalLight3D.new()
		world.add_child(light)
		light.rotation_degrees = Vector3(-60, -30, 0)
		for frame: int in range(3): await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/arrow-tower-two-garrison.png")
	var passed: bool = true
	world.queue_free()
	await process_frame
	print("箭塔需求中断预约回归测试通过")
	quit(0 if passed else 1)
