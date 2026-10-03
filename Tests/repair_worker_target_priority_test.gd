extends SceneTree

var failed := false

func _init() -> void:
	call_deferred("_run")

func _expect(value: bool, text: String) -> void:
	print("[", "通过" if value else "失败", "] ", text)
	if not value:
		failed = true
		push_error(text)

func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world
	var manager := TaskManager.new()
	world.add_child(manager)
	manager.set_process(false)
	var base: Node3D = load("res://Scene/building/base.tscn").instantiate()
	world.add_child(base)
	base.position = Vector3(-15,0,0)
	var house: BuildingBase = load("res://Scene/building/game/house.tscn").instantiate()
	house.set_building_data(load("res://data/buildings/HouseData.tres"))
	world.add_child(house)
	var enemy: EnemyBase = load("res://Scene/unit/enemy_base.tscn").instantiate()
	enemy.enemy_data = enemy.enemy_data.duplicate(true)
	enemy.enemy_data.raid_objective = EnemyData.RaidObjective.DESTROY_BUILDINGS
	enemy.raid_active = true
	world.add_child(enemy)
	enemy.set_process(false)
	enemy.set_physics_process(false)
	enemy.position = Vector3(3.5,0,0)
	var worker: Node3D = load("res://Scene/unit/villager.tscn").instantiate()
	world.add_child(worker)
	worker.set_process(false)
	worker.set_physics_process(false)
	worker.position = Vector3(4,0,0)
	var region := NavigationRegion3D.new()
	var mesh := NavigationMesh.new()
	mesh.vertices = PackedVector3Array([Vector3(-30,0,-30),Vector3(-30,0,30),Vector3(30,0,30),Vector3(30,0,-30)])
	mesh.add_polygon(PackedInt32Array([0,1,2,3]))
	region.navigation_mesh = mesh
	world.add_child(region)
	for i in range(10): await physics_frame
	var task := GameTask.new(&"test_repair_priority", GameTask.TaskType.REPAIR_BUILDING)
	task.target = house
	manager.register_task(task)
	_expect(manager.claim_task(task, worker), "维修居民持有真实任务预约")
	worker.task_site = house
	worker.state = worker.State.MOVE_TO_REPAIR
	enemy._set_target(house)
	enemy.update_targeting()
	_expect(enemy.target == worker, "拆建筑的敌人优先攻击靠近的维修居民")
	worker.state = worker.State.REPAIRING
	enemy.update_targeting()
	_expect(enemy.target == worker, "正在维修的普通居民成为合法优先目标")
	var health: float = worker.get_health()
	var building_health: float = house.get_health()
	enemy._physics_process(1.0)
	_expect(worker.get_health() < health and house.get_health() == building_health, "敌人实际转火居民而非继续攻击建筑")
	_expect(worker.state == worker.State.RETREAT_TO_BASE and worker.current_task == null, "维修居民受伤后释放任务并逃回据点")
	enemy.update_targeting()
	_expect(enemy.target == worker, "居民撤退后仍在警戒范围内会继续被追击")
	var fighter: Node3D = load("res://Scene/unit/villager.tscn").instantiate()
	world.add_child(fighter)
	fighter.set_process(false)
	fighter.set_physics_process(false)
	fighter.set_combat_role(CombatRole.Type.SWORDSMAN)
	fighter.position = Vector3(4.5,0,0)
	enemy.update_targeting()
	_expect(enemy.target == fighter, "维修居民撤退时，出现剑士后优先迎战剑士")
	health = worker.get_health()
	var fighter_health: float = fighter.get_health()
	enemy._physics_process(1.0)
	_expect(fighter.get_health() < fighter_health and worker.get_health() == health, "实际攻击战斗单位，不再继续伤害撤退居民")
	fighter.position = Vector3(30,0,0)
	enemy.update_targeting()
	_expect(enemy.target == worker, "战斗单位离开警戒范围后沿用原维修居民追击规则")
	var archer: Node3D = load("res://Scene/unit/villager.tscn").instantiate()
	world.add_child(archer)
	archer.set_process(false)
	archer.set_physics_process(false)
	archer.set_combat_role(CombatRole.Type.ARCHER)
	archer.position = Vector3(5,0,0)
	enemy.update_targeting()
	_expect(enemy.target == archer, "弓箭手也优先于维修居民，没有写死剑士")
	archer.hide()
	enemy.update_targeting()
	_expect(enemy.target == worker, "隐藏或驻守建筑内不可直接攻击的战斗单位不触发转火")
	archer.show()
	archer.take_damage(1000.0, enemy)
	enemy.update_targeting()
	_expect(enemy.target == worker, "战斗单位死亡后不继续锁定尸体")
	worker.position = Vector3(30,0,0)
	enemy.update_targeting()
	_expect(enemy.target == house, "居民脱离警戒范围后恢复拆建筑")
	worker.position = Vector3(4,0,0)
	worker.state = worker.State.IDLE
	enemy.update_targeting()
	_expect(enemy.target == house, "附近闲置居民不被误判为维修者")
	var other: BuildingBase = load("res://Scene/building/game/house.tscn").instantiate()
	other.set_building_data(load("res://data/buildings/HouseData.tres"))
	world.add_child(other)
	other.position = Vector3(0,0,12)
	task.target = other
	task.assigned_worker = worker
	task.state = GameTask.State.IN_PROGRESS
	worker.current_task = task
	worker.task_site = other
	worker.state = worker.State.REPAIRING
	enemy.update_targeting()
	_expect(enemy.target == house, "维修另一栋建筑的居民不触发当前建筑的转火")
	task.target = house
	worker.task_site = house
	worker.position = Vector3(30,0,0)
	enemy.update_targeting()
	_expect(enemy.target == house, "警戒范围外的维修居民不会被远距离锁定")
	worker.position = Vector3(4,0,0)
	enemy.update_targeting()
	_expect(enemy.target == worker, "维修者重新靠近后可以再次转火")
	worker.take_damage(1000.0, enemy)
	enemy.update_targeting()
	_expect(worker.is_dead() and enemy.target == house, "维修者死亡后恢复拆建筑")
	world.queue_free()
	await process_frame
	print("建筑攻击者优先维修居民测试", "失败" if failed else "通过")
	quit(1 if failed else 0)
