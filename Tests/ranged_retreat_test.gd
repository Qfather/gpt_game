extends SceneTree

var failed: bool = false

func _initialize() -> void:
	call_deferred("_run")

func _expect(value: bool, message: String) -> void:
	print("[", "通过" if value else "失败", "] ", message)
	if not value:
		failed = true
		push_error(message)

func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world
	var region := NavigationRegion3D.new()
	var mesh := NavigationMesh.new()
	mesh.vertices = PackedVector3Array([Vector3(-20, 4, -20), Vector3(-20, 4, 20), Vector3(20, 4, 20), Vector3(20, 4, -20)])
	mesh.add_polygon(PackedInt32Array([0, 1, 2, 3]))
	region.navigation_mesh = mesh
	world.add_child(region)
	var base: Node3D = load("res://Scene/building/base.tscn").instantiate()
	world.add_child(base)
	base.position = Vector3(-9, 3.5, 0)
	base.set_process(false)
	var house: Node3D = load("res://Scene/building/game/hunter_hut.tscn").instantiate()
	world.add_child(house)
	house.set_process(false)
	var enemy: EnemyBase = load("res://Scene/unit/enemy_base.tscn").instantiate()
	enemy.enemy_data = load("res://data/enemies/raid/SlimeData.tres").duplicate(true)
	enemy.enemy_data.max_health = 10000
	world.add_child(enemy)
	enemy.position = Vector3(4, 3.5, 0)
	enemy.set_process(false)
	enemy.set_physics_process(false)
	for id: String in ["hunter", "archer"]:
		var unit: Node3D = load("res://Scene/unit/villager.tscn").instantiate()
		world.add_child(unit)
		unit.set_physics_process(false)
		for frame in range(5): await physics_frame
		if id == "hunter":
			unit.assign_job(unit.Job.HUNTER, house)
		else:
			unit.set_combat_role(CombatRole.Type.ARCHER)
		unit.position = Vector3(0, 3.5, 0)
		unit.target_base = base
		unit.hunger_rate = 0
		unit.fatigue_rate = 0
		var origin: Vector3 = unit.global_position
		var health_before: float = enemy.current_health
		unit._physics_process(1.0 / 60.0)
		_expect(unit.state == unit.State.COMBAT_ATTACK and unit.ranged_shot_remaining > 0, id + "遇敌停下射箭")
		var held_still: bool = true
		for frame in range(12):
			unit._physics_process(1.0 / 60.0)
			held_still = held_still and unit.global_position.is_equal_approx(origin)
			await physics_frame
		_expect(held_still, id + "射箭停顿期间位置不变")
		var shots: int = 1
		var previous_shot: float = unit.ranged_shot_remaining
		for frame in range(220):
			enemy.global_position = unit.global_position + Vector3(4, 0, 0)
			unit._physics_process(1.0 / 60.0)
			if unit.ranged_shot_remaining > previous_shot: shots += 1
			previous_shot = unit.ranged_shot_remaining
			await physics_frame
		_expect(unit.global_position.x < origin.x - 2, id + "射击间隔实际向据点后撤")
		_expect(shots >= 2 and enemy.current_health < health_before, id + "后撤途中再次停下射击且箭实际命中")
		unit.position = Vector3(0, 3.5, 0)
		enemy.position = Vector3(10, 3.5, 0)
		unit.ranged_shot_remaining = 0
		unit.combat_attack_cooldown = 0
		for frame in range(30):
			unit._physics_process(1.0 / 60.0)
			await physics_frame
		_expect(unit.global_position.x < 0 and unit.state == unit.State.COMBAT_MOVE, id + "敌人在射程外时向据点退，不追敌")
		enemy.position = Vector3(40, 3.5, 0)
		unit.ranged_shot_remaining = 0
		unit._physics_process(1.0 / 60.0)
		_expect(unit.combat_target == null and unit.state not in [unit.State.COMBAT_MOVE, unit.State.COMBAT_ATTACK], id + "敌人离开警戒范围后退出战斗，不永久停在撤退状态")
		unit.queue_free()
		await process_frame
		enemy.position = Vector3(4, 3.5, 0)
	world.queue_free()
	await process_frame
	print("远程单位边打边退测试", "失败" if failed else "通过")
	quit(1 if failed else 0)
