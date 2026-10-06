extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world
	var region := NavigationRegion3D.new()
	var mesh := NavigationMesh.new()
	mesh.vertices = PackedVector3Array([Vector3(-10,0,-1.5), Vector3(-10,0,1.5), Vector3(10,0,1.5), Vector3(10,0,-1.5)])
	mesh.add_polygon(PackedInt32Array([0,1,2,3]))
	region.navigation_mesh = mesh
	world.add_child(region)
	if DisplayServer.get_name() != "headless":
		var camera := Camera3D.new()
		world.add_child(camera)
		camera.position = Vector3(0,12,8)
		camera.look_at(Vector3.ZERO)
		camera.make_current()
		var light := DirectionalLight3D.new()
		world.add_child(light)
		light.rotation_degrees.x = -60
	for frame: int in range(6): await physics_frame
	for speed: float in [1.0, 3.0]:
		Engine.time_scale = speed
		var first: Migrant = load("res://Scene/unit/migrant.tscn").instantiate()
		var second: Migrant = load("res://Scene/unit/migrant.tscn").instantiate()
		var first_goal := Node3D.new()
		var second_goal := Node3D.new()
		world.add_child(first_goal)
		world.add_child(second_goal)
		first_goal.position.x = 7
		second_goal.position.x = -7
		world.add_child(first)
		world.add_child(second)
		first.position.x = -5
		second.position.x = 5
		first.collision_mask = 3
		second.collision_mask = 3
		first.setup(first_goal)
		second.setup(second_goal)
		var minimum_separation: float = INF
		for frame: int in range(600):
			await physics_frame
			minimum_separation = minf(minimum_separation, first.position.distance_to(second.position))
			assert(absf(first.position.z) < 1.7 and absf(second.position.z) < 1.7, "避让不能走出导航通道")
			if first._arrival_notified and second._arrival_notified: break
		assert(first._arrival_notified and second._arrival_notified, "对向角色必须能通过一格道路")
		assert(minimum_separation >= 0.29, "角色不能靠穿透通过")
		print("对向避让通过：倍速=", speed, " 最近距离=", minimum_separation)
		first.queue_free()
		second.queue_free()
		first_goal.queue_free()
		second_goal.queue_free()
		await process_frame
	Engine.time_scale = 1.0
	var idle: Node3D = load("res://Scene/unit/villager.tscn").instantiate()
	world.add_child(idle)
	idle.set_physics_process(false)
	for frame: int in range(10): await physics_frame
	idle.position = Vector3.ZERO
	idle.state = idle.State.IDLE
	idle.yield_to_unit(null, Vector3.RIGHT)
	assert(idle.state == idle.State.RETURN_TO_IDLE and idle.initial_idle_position_pending)
	assert(idle.navigation_agent.target_position.distance_to(idle.position) > 0.8)
	assert(not idle.can_take_task(null))
	idle.set_physics_process(true)
	for frame: int in range(150):
		await physics_frame
		if idle.state == idle.State.IDLE: break
	assert(idle.state == idle.State.IDLE and idle.position.distance_to(Vector3.ZERO) > 0.75, "待命者必须实际移开")
	idle.state = idle.State.BUILDING
	var position: Vector3 = idle.navigation_agent.target_position
	idle.yield_cooldown = 0
	idle.yield_to_unit(null, Vector3.RIGHT)
	assert(idle.state == idle.State.BUILDING and idle.navigation_agent.target_position == position, "不能打断施工")
	print("待命角色实际让路、到位后接任务、施工不受影响通过")
	idle.state = idle.State.IDLE
	idle.position = Vector3.ZERO
	idle.yield_cooldown = 0
	idle.idle_reposition_timer = 1000
	var passer: Migrant = load("res://Scene/unit/migrant.tscn").instantiate()
	var goal := Node3D.new()
	world.add_child(goal)
	goal.position.x = 5
	world.add_child(passer)
	passer.position.x = -3
	passer.setup(goal)
	for frame: int in range(300):
		await physics_frame
		if passer._arrival_notified: break
	assert(passer._arrival_notified and absf(idle.position.z) > 0.7, "行人接近时待命者应自动让路")
	print("移民接近触发待命居民自动让路并通过")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/unit-avoidance.png")
	passer.queue_free()
	idle.queue_free()
	goal.queue_free()
	await process_frame
	var enemy_a: EnemyBase = load("res://Scene/unit/enemy_base.tscn").instantiate()
	var enemy_b: EnemyBase = load("res://Scene/unit/enemy_base.tscn").instantiate()
	world.add_child(enemy_a)
	world.add_child(enemy_b)
	for enemy: EnemyBase in [enemy_a, enemy_b]:
		enemy.set_process(false)
		enemy.set_physics_process(false)
	enemy_a.position.x = -5
	enemy_b.position.x = 5
	for frame: int in range(6): await physics_frame
	for frame: int in range(600):
		await physics_frame
		enemy_a._move_toward_navigation_target(Vector3(7,0,0))
		enemy_b._move_toward_navigation_target(Vector3(-7,0,0))
		if enemy_a.position.x > 3 and enemy_b.position.x < -3: break
	assert(enemy_a.position.x > 3 and enemy_b.position.x < -3, "怪物使用同一避让规则并能交错通过")
	print("怪物对向交错通过")
	world.queue_free()
	await process_frame
	quit()
