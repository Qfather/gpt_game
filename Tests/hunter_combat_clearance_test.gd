extends SceneTree

var failed: bool = false

func _initialize() -> void:
	call_deferred("_run")

func _expect(value: bool, message: String) -> void:
	print("[", "通过" if value else "失败", "] ", message)
	if not value:
		failed = true
		push_error(message)

func _unit(world: Node3D) -> Node3D:
	var unit: Node3D = load("res://Scene/unit/villager.tscn").instantiate()
	world.add_child(unit)
	unit.set_physics_process(false)
	unit.hunger_rate = 0
	unit.fatigue_rate = 0
	return unit

func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world
	var region := NavigationRegion3D.new()
	var mesh := NavigationMesh.new()
	mesh.vertices = PackedVector3Array([Vector3(-12, 4, -12), Vector3(-12, 4, 12), Vector3(12, 4, 12), Vector3(12, 4, -12)])
	mesh.add_polygon(PackedInt32Array([0, 1, 2, 3]))
	region.navigation_mesh = mesh
	world.add_child(region)
	var house: Node3D = load("res://Scene/building/game/hunter_hut.tscn").instantiate()
	world.add_child(house)
	house.set_process(false)
	var hunter := _unit(world)
	var resident := _unit(world)
	var soldier := _unit(world)
	soldier.set_combat_role(CombatRole.Type.SWORDSMAN)
	for frame in range(5): await physics_frame
	hunter.assign_job(hunter.Job.HUNTER, house)
	hunter.global_position = Vector3(0, 3.6, 0)
	var animal_data: Resource = load("res://data/wildlife/pheasant.tres")
	var animal: Node3D = animal_data.scene.instantiate()
	animal.data = animal_data
	world.add_child(animal)
	animal.global_position = Vector3(1.78, 4, 0)
	animal.claim(hunter)
	animal.health = 0
	hunter.hunting.target = animal
	_expect(hunter.global_position.distance_to(animal.global_position) > 1.8, "复现野鸡尸体三维距离超出收取阈值")
	hunter.hunting.process(hunter, 0.016)
	_expect(hunter.hunting.prey_count == 1 and hunter.hunting.raw_meat == animal_data.meat_yield and is_instance_valid(hunter.hunting.bundle), "导航高度差不再卡住收尸，猎物与背包实际增加")
	await process_frame
	var enemy: EnemyBase = load("res://Scene/unit/enemy_base.tscn").instantiate()
	enemy.enemy_data = load("res://data/enemies/raid/SlimeData.tres").duplicate(true)
	world.add_child(enemy)
	enemy.set_physics_process(false)
	enemy.set_process(false)
	enemy.global_position = Vector3(2, 3.6, 0)
	var before: float = enemy.current_health
	_expect(not hunter._process_civilian_retreat(0.016), "猎人遇敌不进入居民避难逻辑")
	_expect(hunter._process_combat(0.016) and hunter.state == hunter.State.COMBAT_ATTACK and hunter.visible, "猎人进入远程战斗且保持室外可见")
	for frame in range(30): await physics_frame
	_expect(enemy.current_health < before, "猎人的箭实际命中敌人")
	hunter.hunting.returning = true
	hunter.hunting.inside_processing = true
	hunter.hunting.processing_time = 2.0
	hunter.visible = false
	hunter.global_position = house.get_interior_position()
	hunter._physics_process(0.016)
	for frame in range(180):
		if not hunter.passing_door: break
		await physics_frame
	_expect(not hunter.hunting.inside_processing and not hunter.passing_door and hunter.visible and hunter.indoor_building == null, "小屋内处理猎物的猎人遇敌会实际出门")
	_expect(hunter.hunting.prey_count == 1 and hunter.hunting.processing_time == 2.0, "出门战斗保留未处理猎物和剩余处理时间")
	hunter.global_position = Vector3(0, 3.6, 0)
	_expect(enemy.hit_velocity.x > 0, "敌人受击方向远离猎人")
	var enemy_position: Vector3 = enemy.global_position
	for frame in range(12): enemy._physics_process(1.0 / 60.0)
	_expect(enemy.global_position.x > enemy_position.x and enemy.global_position.x - enemy_position.x < 0.4, "敌人受击产生小幅位移")
	hunter.take_damage(1, enemy)
	var hunter_position: Vector3 = hunter.global_position
	for frame in range(12): hunter._physics_process(1.0 / 60.0)
	_expect(hunter.global_position.x < hunter_position.x and hunter_position.x - hunter.global_position.x < 0.4, "猎人受击小幅后退且没有逃进建筑")
	resident.state = resident.State.RETREAT_TO_BASE
	resident.retreat_threat = enemy
	hunter.combat_target = enemy
	enemy.free()
	_expect(soldier._find_retreat_threat() == null, "剑士忽略居民已释放的威胁引用")
	hunter._process_combat(0.016)
	_expect(hunter.state == hunter.State.HUNTING and hunter.hunting.prey_count == 1, "敌人释放后猎人恢复狩猎并保留猎物")
	world.queue_free()
	await process_frame
	print("猎人战斗、收尸与失效引用测试", "失败" if failed else "通过")
	quit(1 if failed else 0)
