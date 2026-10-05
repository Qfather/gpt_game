extends SceneTree

const Facing = preload("res://Script/unit/unit_facing.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var probe := Node3D.new()
	root.add_child(probe)
	Facing.face_direction(probe, Vector3.RIGHT)
	assert(is_zero_approx(probe.rotation.y))
	Facing.update(probe, 0.1)
	assert(is_equal_approx(probe.rotation.y, PI / 4.0))
	Facing.update(probe, 0.1)
	assert(is_equal_approx(probe.rotation.y, PI / 2.0))
	probe.rotation.y = 0.0
	Facing.face_direction(probe, Vector3.FORWARD)
	Facing.update(probe, 0.2)
	assert(is_equal_approx(probe.rotation.y, PI / 2.0))
	Facing.update(probe, 0.2)
	assert(probe.basis.z.is_equal_approx(Vector3.FORWARD))
	probe.rotation.y = deg_to_rad(330.0)
	Facing.face_direction(probe, Vector3(sin(deg_to_rad(30.0)), 0, cos(deg_to_rad(30.0))))
	Facing.update(probe, 1.0 / 15.0)
	assert(absf(probe.rotation.y) < 0.0001)
	Facing.update(probe, 1.0 / 15.0)
	assert(is_equal_approx(probe.rotation.y, deg_to_rad(30.0)))
	Facing.face_direction(probe, Vector3(sin(deg_to_rad(330.0)), 0, cos(deg_to_rad(330.0))))
	Facing.update(probe, 1.0 / 15.0)
	assert(absf(probe.rotation.y) < 0.0001)
	Facing.update(probe, 1.0 / 15.0)
	assert(is_equal_approx(probe.rotation.y, deg_to_rad(-30.0)))
	probe.queue_free()
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world
	var region := NavigationRegion3D.new()
	var mesh := NavigationMesh.new()
	mesh.vertices = PackedVector3Array([Vector3(-20,0,-20),Vector3(-20,0,20),Vector3(20,0,20),Vector3(20,0,-20)])
	mesh.add_polygon(PackedInt32Array([0,1,2,3]))
	region.navigation_mesh = mesh
	world.add_child(region)
	var base: Node3D = load("res://Scene/building/base.tscn").instantiate()
	world.add_child(base)
	base.position = Vector3(0,0,12)
	var worker: CharacterBody3D = load("res://Scene/unit/villager.tscn").instantiate()
	world.add_child(worker)
	worker.set_physics_process(false)
	worker.position = Vector3(-6,0,-3)
	var enemy: EnemyBase = load("res://Scene/unit/enemy_base.tscn").instantiate()
	enemy.enemy_data = load("res://data/enemies/raid/WolfData.tres")
	world.add_child(enemy)
	enemy.set_process(false)
	enemy.set_physics_process(false)
	enemy.position = Vector3(-6,0,3)
	for frame: int in range(10): await physics_frame
	var collider_basis: Basis = worker.get_node("CollisionShape3D").global_basis
	worker.navigation_agent.target_position = Vector3(6,0,-3)
	for frame: int in range(60):
		await physics_frame
		worker.move_along_navigation()
		enemy._move_toward_navigation_target(Vector3(6,0,3))
		Facing.update(worker.visual_root, 1.0 / 60.0)
		Facing.update(enemy.visual_root, 1.0 / 60.0)
	assert(worker.position.x > -5.0 and enemy.position.x > -5.0)
	assert(worker.visual_root.global_basis.z.normalized().dot(Vector3.RIGHT) > 0.99)
	assert(enemy.visual_root.global_basis.z.normalized().dot(Vector3.RIGHT) > 0.99)
	worker.navigation_agent.target_position = Vector3(-10,0,-3)
	for frame: int in range(25):
		await physics_frame
		worker.move_along_navigation()
		enemy._move_toward_navigation_target(Vector3(-10,0,3))
		Facing.update(worker.visual_root, 1.0 / 60.0)
		Facing.update(enemy.visual_root, 1.0 / 60.0)
	assert(worker.visual_root.global_basis.z.normalized().dot(Vector3.LEFT) > 0.99)
	assert(enemy.visual_root.global_basis.z.normalized().dot(Vector3.LEFT) > 0.99)
	assert(worker.rotation == Vector3.ZERO and enemy.rotation == Vector3.ZERO)
	assert(worker.get_node("CollisionShape3D").global_basis.is_equal_approx(collider_basis))
	var yaw: float = worker.visual_root.rotation.y
	worker._face_direction(Vector3.ZERO)
	assert(is_equal_approx(yaw, worker.visual_root.rotation.y))
	worker.set_combat_role(CombatRole.Type.SWORDSMAN)
	assert(worker.visual_instance.get_parent() == worker.visual_root)
	assert(is_equal_approx(yaw, worker.visual_root.rotation.y))
	var model_transform: Transform3D = worker.visual_instance.transform
	worker._face_direction(Vector3(0,5,-1))
	Facing.update(worker.visual_root, 0.4)
	assert(worker.visual_root.global_basis.z.normalized().dot(Vector3.FORWARD) > 0.99)
	assert(worker.visual_instance.transform.is_equal_approx(model_transform))
	var tree: ResourceBase = load("res://Scene/resource/tree.tscn").instantiate()
	world.add_child(tree)
	tree.position = worker.position + Vector3(0,0,2)
	worker.target_resource = tree
	worker.gather_resource(0.01)
	Facing.update(worker.visual_root, 0.4)
	assert(worker.visual_root.global_basis.z.normalized().dot(Vector3.BACK) > 0.99)
	worker.target_resource = null
	enemy.target = worker
	enemy.attack_cooldown = 10.0
	enemy.position = worker.position + Vector3(0,0,0.5)
	enemy._physics_process(0.01)
	Facing.update(enemy.visual_root, 0.4)
	assert(enemy.visual_root.global_basis.z.normalized().dot(Vector3.FORWARD) > 0.99)
	if DisplayServer.get_name() != "headless":
		worker._face_direction(Vector3.RIGHT)
		enemy.position = worker.position + Vector3(3,0,0)
		preload("res://Script/unit/unit_facing.gd").face_direction(enemy.visual_root, Vector3.LEFT)
		Facing.update(worker.visual_root, 0.4)
		Facing.update(enemy.visual_root, 0.4)
		var camera := Camera3D.new()
		world.add_child(camera)
		camera.position = worker.position + Vector3(1.5,4,7)
		camera.look_at(worker.position + Vector3(1.5,1,0))
		camera.make_current()
		var light := DirectionalLight3D.new()
		world.add_child(light)
		light.rotation_degrees = Vector3(-45,-30,0)
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/unit-facing.png")
	print("单位朝向验证通过：90度0.2秒、180度0.4秒、跨零双向最短转身、居民与怪物导航往返、采集攻击、静止、转职与碰撞不变")
	world.queue_free()
	await process_frame
	quit()
