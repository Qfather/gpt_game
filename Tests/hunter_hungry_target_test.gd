extends SceneTree

var failed: bool = false

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world
	var base: Node3D = load("res://Scene/building/base.tscn").instantiate()
	world.add_child(base)
	var worker: Node3D = load("res://Scene/unit/villager.tscn").instantiate()
	world.add_child(worker)
	worker.set_physics_process(false)
	worker.collision_mask = 0
	var map: RID = NavigationServer3D.map_create()
	NavigationServer3D.map_set_active(map, true)
	var region: RID = NavigationServer3D.region_create()
	var mesh := NavigationMesh.new()
	mesh.vertices = PackedVector3Array([Vector3(-8, 4, -8), Vector3(-8, 4, 8), Vector3(8, 4, 8), Vector3(8, 4, -8)])
	mesh.add_polygon(PackedInt32Array([0, 1, 2, 3]))
	NavigationServer3D.region_set_navigation_mesh(region, mesh)
	NavigationServer3D.region_set_map(region, map)
	worker.navigation_agent.set_navigation_map(map)
	for index in range(10): await physics_frame
	worker.global_position = Vector3(0, 4, 0)
	worker.target_base = base
	var house: Node3D = load("res://Scene/building/game/hunter_hut.tscn").instantiate()
	world.add_child(house)
	worker.assign_job(worker.Job.HUNTER, house)
	base.storage.resources.clear()
	worker.hunger = 80
	worker.hunger_rate = 0
	worker.fatigue_rate = 0
	var data: Resource = load("res://data/wildlife/boar.tres")
	var animal: Node3D = data.scene.instantiate()
	animal.data = data
	world.add_child(animal)
	animal.global_position = Vector3(4, 4.4, 0)
	animal.health = 3

	worker.set_physics_process(true)
	for index in range(600):
		if worker.hunting.prey_count > 0: break
		await physics_frame
	worker.set_physics_process(false)
	_expect(worker.hunting.prey_count == 1, "缺粮且饥饿时仍能自动认领、射杀并拾取猎物")
	await process_frame
	var next_animal: Node3D = data.scene.instantiate()
	next_animal.data = data
	world.add_child(next_animal)
	next_animal.claim(worker)
	worker.hunting.target = next_animal
	worker.hunger = 80
	_expect(not worker.begin_eating() and worker.hunting.target == next_animal and next_animal.claimed_by == worker, "无食物时尝试吃饭不会释放猎物")
	base.add_resource(&"grain", 2)
	_expect(worker.begin_eating() and worker.state == worker.State.NEED_EAT, "有食物时仍正常开始吃饭")
	_expect(worker.hunting.target == null and next_animal.claimed_by == null, "真正去吃饭时释放猎物")
	worker.state = worker.State.HUNTING
	next_animal.claim(worker)
	worker.hunting.target = next_animal
	worker.begin_resting()
	_expect(worker.state == worker.State.NEED_REST and worker.hunting.target == null and next_animal.claimed_by == null, "真正去休息时释放猎物，其他猎户可以认领")
	world.queue_free()
	await process_frame
	NavigationServer3D.free_rid(region)
	NavigationServer3D.free_rid(map)
	print("猎户缺粮狩猎测试", "失败" if failed else "通过")
	call_deferred("quit", 1 if failed else 0)

func _expect(value: bool, message: String) -> void:
	print("[", "通过" if value else "失败", "] ", message)
	if not value:
		failed = true
		push_error(message)
