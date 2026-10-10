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
	mesh.vertices = PackedVector3Array([Vector3(-10,0,-10),Vector3(-10,0,10),Vector3(-1.3,0,10),Vector3(-1.3,0,1.3),Vector3(-1.3,0,-1.3),Vector3(-1.3,0,-10),Vector3(1.3,0,-10),Vector3(1.3,0,-1.3),Vector3(1.3,0,1.3),Vector3(1.3,0,10),Vector3(10,0,10),Vector3(10,0,-10)])
	for polygon: PackedInt32Array in [PackedInt32Array([0,1,2,3,4,5]),PackedInt32Array([6,7,8,9,10,11]),PackedInt32Array([5,4,7,6]),PackedInt32Array([3,2,9,8])]:
		mesh.add_polygon(polygon)
	region.navigation_mesh = mesh
	world.add_child(region)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.position = Vector3(0,10,3)
	camera.look_at(Vector3.ZERO)
	var light := DirectionalLight3D.new()
	world.add_child(light)
	light.rotation_degrees = Vector3(-40,-30,0)
	var base = load("res://Scene/building/base.tscn").instantiate()
	base.position = Vector3(-7,0,-7)
	world.add_child(base)
	var initial_wood: float = base.get_resource(&"wood")
	var building := BuildingBase.new()
	building.name = "拆除测试建筑"
	var data := BuildingData.new()
	data.construction_time = 60.0
	data.max_construction_workers = 3
	data.construction_cost = {&"wood": 10.0}
	building.building_data = data
	var shape := BoxShape3D.new()
	shape.size = Vector3(2,2,2)
	var body := StaticBody3D.new()
	building.add_child(body)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position.y = 1
	body.add_child(collision)
	var click := Area3D.new()
	click.name = "ClickArea"
	building.add_child(click)
	var footprint := CollisionShape3D.new()
	footprint.name = "CollisionShape3D"
	footprint.shape = shape
	click.add_child(footprint)
	var box := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = shape.size
	box.mesh = box_mesh
	box.position.y = 1
	building.add_child(box)
	world.add_child(building)
	building.set_process(false)
	var workers: Array[Node3D] = []
	for position: Vector3 in [Vector3(-6,0,4),Vector3(-6,0,-4),Vector3(6,0,-4)]:
		var worker = load("res://Scene/unit/villager.tscn").instantiate()
		worker.position = position
		world.add_child(worker)
		worker.set_physics_process(false)
		worker.hunger_rate = 0.0
		worker.fatigue_rate = 0.0
		workers.append(worker)
	for index in range(15): await physics_frame
	for worker: Node3D in workers:
		worker.state = worker.State.IDLE
	assert(building.demolish())
	building._try_assign_demolition_worker()
	assert(building.demolition_workers.size() == 3)
	assert(not building.begin_demolition_work(workers[0]))
	for index in range(15):
		building._process(1.0/60.0)
		await physics_frame
	assert(building.demolition_progress == 0.0)
	for worker: Node3D in workers:
		worker.set_physics_process(true)
	building.set_process(true)
	var worked: Dictionary = {}
	var captured := false
	for index in range(2000):
		await physics_frame
		await process_frame
		for worker: Node3D in workers:
			assert(absf(worker.position.x) > 1.0 or absf(worker.position.z) > 1.0)
			if worker.state == worker.State.DEMOLISHING:
				assert(worker.has_reached_demolition_position())
				if worker.visual_instance.playback.get_current_node() == &"standing":
					worked[worker.get_instance_id()] = worker.global_position
		if worked.size() == 3 and not captured:
			captured = true
			if DisplayServer.get_name() != "headless":
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("res://.godot/animation_check/demolition_ring.png")
		if not is_instance_valid(building) and is_equal_approx(base.get_resource(&"wood"), initial_wood + 3.0): break
	assert(worked.size() == 3)
	assert(not is_instance_valid(building))
	assert(is_equal_approx(base.get_resource(&"wood"), initial_wood + 3.0))
	print("[通过] 三人真实绕建筑导航到不同外侧站位、到场才拆除、站立锤状态、无穿墙、拆完后实际搬运退款。站位：", worked.values())
	Engine.time_scale = 1.0
	world.queue_free()
	await process_frame
	quit(0)
