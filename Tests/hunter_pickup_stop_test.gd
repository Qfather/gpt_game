extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world
	var region := NavigationRegion3D.new()
	var mesh := NavigationMesh.new()
	mesh.vertices = PackedVector3Array([Vector3(-10, 4, -10), Vector3(-10, 4, 10), Vector3(10, 4, 10), Vector3(10, 4, -10)])
	mesh.add_polygon(PackedInt32Array([0, 1, 2, 3]))
	region.navigation_mesh = mesh
	world.add_child(region)
	var hunter: Node3D = load("res://Scene/unit/villager.tscn").instantiate()
	world.add_child(hunter)
	hunter.set_physics_process(false)
	var house: Node3D = load("res://Scene/building/game/hunter_hut.tscn").instantiate()
	world.add_child(house)
	house.set_process(false)
	for frame in range(5): await physics_frame
	hunter.assign_job(hunter.Job.HUNTER, house)
	hunter.hunger_rate = 0
	hunter.fatigue_rate = 0
	hunter.global_position = Vector3(2.1, 3.5, 0)
	var data: Resource = load("res://data/wildlife/pheasant.tres")
	var animal: Node3D = data.scene.instantiate()
	animal.data = data
	world.add_child(animal)
	animal.position = Vector3(4, 4, 0)
	animal.health = 0
	animal.claim(hunter)
	hunter.hunting.target = animal
	# 猎物最后逃跑不到半米：旧移动逻辑沿用上一个导航目标。
	hunter.navigation_agent.target_position = Vector3(3.55, 4, 0)
	for frame in range(5):
		hunter.navigation_agent.get_next_path_position()
		await physics_frame
	for frame in range(180):
		hunter.hunting.process(hunter, 1.0 / 60.0)
		if hunter.hunting.prey_count > 0: break
		await physics_frame
	assert(hunter.hunting.prey_count == 1, "猎物移动不足半米后死亡，猎人不能停在收尸范围外等待疲劳")
	assert(hunter.hunting.raw_meat == data.meat_yield and is_instance_valid(hunter.hunting.bundle))
	print("猎物移动不足半米后的实际导航、收尸与背包回归通过")
	world.queue_free()
	await process_frame
	quit()
