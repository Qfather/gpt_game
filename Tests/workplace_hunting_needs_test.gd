extends SceneTree
var failed := false
func _initialize() -> void:
	call_deferred("_run")
func _expect(ok: bool, message: String) -> void:
	print("[通过] " if ok else "[失败] ", message)
	failed = failed or not ok
func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world
	var region := NavigationRegion3D.new()
	var mesh := NavigationMesh.new()
	# 原门点位于不连通的屋内区域，建筑正面右侧有可达通道。
	mesh.vertices = PackedVector3Array([Vector3(-0.1,0,1.4),Vector3(-0.1,0,1.6),Vector3(0.1,0,1.6),Vector3(0.1,0,1.4),Vector3(0.9,0,1.8),Vector3(0.9,0,5),Vector3(5,0,5),Vector3(5,0,1.8)])
	mesh.add_polygon(PackedInt32Array([0,1,2,3]))
	mesh.add_polygon(PackedInt32Array([4,5,6,7]))
	region.navigation_mesh = mesh
	world.add_child(region)
	var camp: ResourceBuildingBase = load("res://Scene/building/game/lumber_camp.tscn").instantiate()
	world.add_child(camp)
	var workers: Array[CharacterBody3D] = []
	for i: int in range(3):
		var worker = load("res://Scene/unit/villager.tscn").instantiate()
		world.add_child(worker)
		worker.set_physics_process(false)
		workers.append(worker)
	for frame: int in range(10): await physics_frame
	for i: int in range(3):
		var worker = workers[i]
		camp.workers.append(worker)
		worker.job = worker.Job.LUMBERJACK
		worker.workplace = camp
		worker.position = Vector3(2 + i * 0.6,0,4)
		worker.carried_resource_id = &"wood"
		worker.carried_amount = 1
		worker.go_to_workplace()
		_expect(is_equal_approx(worker.navigation_agent.target_desired_distance,0.2), "伐木工采用精确到达距离")
		_expect(camp.is_at_entrance_front(worker.navigation_agent.target_position), "选取门正面可进入的导航目标")
	for frame: int in range(600):
		var finished := true
		for worker: CharacterBody3D in workers:
			if worker.state == worker.State.MOVE_TO_WORKPLACE: worker.move_to_workplace()
			elif worker.state == worker.State.DEPOSIT_TO_WORKPLACE and not worker.passing_door: worker.deposit_to_workplace()
			if worker.carried_amount > 0 or worker.passing_door: finished = false
		await physics_frame
		if finished: break
	for worker: CharacterBody3D in workers:
		_expect(worker.carried_amount == 0 and worker.state != worker.State.MOVE_TO_WORKPLACE, "伐木工实际入场并完成卸货")
	_expect(camp.get_resource_amount(&"wood") == 3, "三名工人木材均进入伐木场库存")
	var unit = workers[0]
	unit.set_unit_data(load("res://data/units/ResidentData.tres"))
	_expect(is_equal_approx(unit.hunger_rate,0.3), "普通居民饥饿速率0.3")
	unit.assign_job(unit.Job.HUNTER, camp)
	_expect(is_equal_approx(unit.hunger_rate,0.3), "猎人饥饿速率0.3")
	for role: int in [CombatRole.Type.SWORDSMAN,CombatRole.Type.ARCHER]:
		unit.set_combat_role(role)
		_expect(is_equal_approx(unit.hunger_rate,0.35), "军事单位饥饿速率0.35")
	unit.set_combat_role(CombatRole.Type.NONE)
	unit.assign_job(unit.Job.HUNTER,camp)
	unit.position = Vector3(2,0,3)
	var data: Resource = load("res://data/wildlife/rabbit.tres")
	var prey: Node3D = data.scene.instantiate()
	prey.data = data
	world.add_child(prey)
	prey.position = unit.position
	prey.health = 0
	prey.claim(unit)
	unit.hunting.target = prey
	unit.hunting.process(unit, 0.1)
	_expect(prey.is_queued_for_deletion() and unit.hunting.prey_count == 1 and unit.hunting.target == null, "0血量猎物被拾取一次并立即释放目标")
	# 等待删除的目标不能被再次拾取。
	unit.hunting.target = prey
	unit.hunting.process(unit,0.1)
	_expect(unit.hunting.prey_count == 1, "待删除尸体不能重复拾取")
	var hut: ResourceBuildingBase = load("res://Scene/building/game/hunter_hut.tscn").instantiate()
	world.add_child(hut)
	var base: BuildingBase = load("res://Scene/building/base.tscn").instantiate()
	world.add_child(base)
	base.get_node("ResourceStorage").set_capacity(&"meat", 100)
	hut.workers.append(unit)
	unit.workplace = hut
	unit.target_base = base
	unit.hunting.prey_count = 0
	unit.hunting.raw_meat = 0
	unit.hunting.returning = false
	unit.carried_resource_id = &"meat"
	unit.carried_amount = 1
	unit.state = unit.State.DEPOSIT_TO_BASE
	unit.deposit_to_base()
	_expect(unit.carried_amount == 0 and unit.state == unit.State.HUNTING, "猎人交肉后直接恢复狩猎，不进入普通采集或重复返回据点")
	world.free()
	quit(1 if failed else 0)
