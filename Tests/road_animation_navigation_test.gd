extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	Engine.time_scale = 3.0
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world
	var region := NavigationRegion3D.new()
	var mesh := NavigationMesh.new()
	mesh.vertices = PackedVector3Array([Vector3(-10,0,-10),Vector3(-10,0,10),Vector3(10,0,10),Vector3(10,0,-10)])
	mesh.add_polygon(PackedInt32Array([0,1,2,3]))
	region.navigation_mesh = mesh
	world.add_child(region)
	var grid := BuildGrid.new()
	world.add_child(grid)
	var roads = load("res://Script/world/road_manager.gd").new()
	roads.grid = grid
	world.add_child(roads)
	var tasks := TaskManager.new()
	world.add_child(tasks)
	var base = load("res://Scene/building/base.tscn").instantiate()
	base.position = Vector3(-7,0,-7)
	world.add_child(base)
	var worker = load("res://Scene/unit/villager.tscn").instantiate()
	worker.position = Vector3(-3,0,0)
	world.add_child(worker)
	worker.set_physics_process(false)
	worker.hunger_rate = 0.0
	worker.fatigue_rate = 0.0
	for index in range(15): await physics_frame
	worker.state = worker.State.IDLE
	var cell := Vector2i(3,0)
	var cells: Array[Vector2i] = [cell]
	assert(roads.queue_cells(cells,1) == 1)
	tasks._dispatch_available_tasks()
	assert(worker.current_task != null)
	worker.set_physics_process(true)
	var start: Vector3 = worker.position
	var walking := false
	var crouching := false
	for index in range(1000):
		await physics_frame
		await process_frame
		walking = walking or worker.visual_instance.playback.get_current_node() == &"walk"
		if worker.state == worker.State.BUILD_ROAD and worker.visual_instance.playback.get_current_node() == &"crouch":
			crouching = true
			assert(worker.position.distance_to(grid.grid_to_world(cell)) <= 0.65)
		if roads.cells.has(cell): break
	assert(worker.position.distance_to(start) > 3.0)
	assert(walking and crouching and roads.cells.get(cell) == 1)
	print("[通过] 居民实际导航到道路蓝图，行走切换下蹲锤状态，真实施工完成土路。")
	Engine.time_scale = 1.0
	world.queue_free()
	await process_frame
	quit(0)
