extends SceneTree

class TestMap extends MapGenerateRuntime:
	func _ready() -> void: add_to_group("map_generate_runtime")

class BlockedInteractionBase extends Node3D:
	func get_interaction_position(_unit: Node) -> Vector3: return Vector3(0, 0, 5.0)

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1280, 720)
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world
	if DisplayServer.get_name() != "headless":
		debug_navigation_hint = true
		var camera := Camera3D.new()
		world.add_child(camera)
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = 22.0
		camera.position = Vector3(0,20,2)
		camera.look_at(Vector3(0,0,2), Vector3.FORWARD)
		camera.make_current()
		var light := DirectionalLight3D.new()
		world.add_child(light)
		light.rotation_degrees = Vector3(-70,0,0)
	var region := NavigationRegion3D.new()
	region.name = "NavigationRegion3D"
	world.add_child(region)
	var runtime := TestMap.new()
	world.add_child(runtime)
	runtime._navigation_faces = PackedVector3Array([Vector3(-12,0,-10),Vector3(12,0,-10),Vector3(-12,0,10),Vector3(12,0,-10),Vector3(12,0,10),Vector3(-12,0,10)])
	var grid := BuildGrid.new()
	world.add_child(grid)
	var roads = load("res://Script/world/road_manager.gd").new()
	roads.grid = grid
	world.add_child(roads)
	for z: float in [-1.0, 2.0]:
		var house: Node3D = load("res://Scene/building/game/house.tscn").instantiate()
		world.add_child(house)
		house.position = Vector3(0, 0, z)
	var mesh: NavigationMesh = runtime._new_navigation_mesh()
	NavigationServer3D.bake_from_source_geometry_data(mesh, runtime._navigation_geometry())
	region.navigation_mesh = mesh
	for frame: int in range(6): await physics_frame
	var passage: PackedVector3Array = NavigationServer3D.map_get_path(region.get_navigation_map(), Vector3(-7,0,0.5), Vector3(7,0,0.5), true)
	var middle_clear: bool = not passage.is_empty()
	for point: Vector3 in passage:
		if absf(point.z - 0.5) > 0.35: middle_clear = false
	print("一格路中间导航连通：", middle_clear, " 路径=", passage)
	if "--baseline" not in OS.get_cmdline_user_args(): assert(middle_clear, "两房之间一格道路必须直接连通，不能被迫绕到建筑外侧")
	var cells: Array[Vector2i] = []
	for x: int in range(-9, 9): cells.append(Vector2i(x, 0))
	roads.place_cells(cells, 1)
	var goal := Node3D.new()
	world.add_child(goal)
	goal.position = Vector3(7,0,0.5)
	var failed: bool = false
	for speed: float in [1.0, 3.0, 10.0]:
		Engine.time_scale = speed
		var migrant: Migrant = load("res://Scene/unit/migrant.tscn").instantiate()
		world.add_child(migrant)
		migrant.position = Vector3(-7,0,0.5)
		var arrived: Array[bool] = [false]
		migrant.arrived.connect(func(_unit: Node3D, _base: Node3D) -> void: arrived[0] = true)
		migrant.setup(goal)
		var crossed_middle: bool = false
		for frame: int in range(700):
			await physics_frame
			if absf(migrant.position.x) < 0.6:
				assert(absf(migrant.position.z - 0.5) < 0.35, "移民必须通过一格道路，不能绕到房屋外侧")
				if not crossed_middle and speed == 1.0 and DisplayServer.get_name() != "headless":
					await RenderingServer.frame_post_draw
					root.get_texture().get_image().save_png("res://.godot/one_cell_road_navigation.png")
				crossed_middle = true
			if arrived[0]: break
		print("移民两房夹路 倍速=", speed, " 抵达=", arrived[0], " 位置=", migrant.position, " 导航完成=", migrant.navigation_agent.is_navigation_finished())
		failed = failed or not arrived[0] or not crossed_middle
		migrant.queue_free()
		await process_frame
	var large_house: Node3D = load("res://Scene/building/game/house.tscn").instantiate()
	world.add_child(large_house)
	large_house.position = Vector3(0,0,5)
	large_house.scale = Vector3(2.0,1.0,2.0)
	mesh = runtime._new_navigation_mesh()
	NavigationServer3D.bake_from_source_geometry_data(mesh, runtime._navigation_geometry())
	region.navigation_mesh = mesh
	for frame: int in range(6): await physics_frame
	Engine.time_scale = 3.0
	var blocked_base := BlockedInteractionBase.new()
	world.add_child(blocked_base)
	blocked_base.position = Vector3(3,0,0.5)
	var migrant: Migrant = load("res://Scene/unit/migrant.tscn").instantiate()
	world.add_child(migrant)
	migrant.position = Vector3(-7,0,0.5)
	var arrived: Array[bool] = [false]
	migrant.arrived.connect(func(_unit: Node3D, _base: Node3D) -> void: arrived[0] = true)
	migrant.setup(blocked_base)
	for frame: int in range(350):
		await physics_frame
		if arrived[0]: break
	print("交互点被旁屋挡住 抵达=", arrived[0], " 位置=", migrant.position, " 导航目标=", migrant.navigation_agent.target_position, " 完成=", migrant.navigation_agent.is_navigation_finished())
	failed = failed or not arrived[0]
	var resting_position: Vector3 = migrant.position
	for frame: int in range(6): await physics_frame
	assert(migrant.position.distance_to(resting_position) < 0.001, "抵达后不能继续在终点来回晃动")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/migrant_corridor_fixed.png")
	world.queue_free()
	await process_frame
	Engine.time_scale = 1.0
	quit(1 if failed else 0)
