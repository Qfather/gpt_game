extends SceneTree

class TestMap extends MapGenerateRuntime:
	func _ready() -> void:
		add_to_group("map_generate_runtime")

func _init() -> void:
	call_deferred("_run")

func _unit(world: Node3D, position: Vector3) -> CharacterBody3D:
	var unit: CharacterBody3D = load("res://Scene/unit/villager.tscn").instantiate()
	world.add_child(unit)
	unit.position = position
	unit.set_process(false)
	unit.set_physics_process(false)
	unit.hunger_rate = 0.0
	unit.fatigue_rate = 0.0
	return unit

func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world
	var region := NavigationRegion3D.new()
	region.name = "NavigationRegion3D"
	world.add_child(region)
	var runtime := TestMap.new()
	world.add_child(runtime)
	runtime._navigation_faces = PackedVector3Array([Vector3(-30,0,-30),Vector3(30,0,-30),Vector3(-30,0,30),Vector3(30,0,-30),Vector3(30,0,30),Vector3(-30,0,30)])
	var base: Node3D = load("res://Scene/building/base.tscn").instantiate()
	world.add_child(base)
	var house: Node3D = load("res://Scene/building/game/hunter_hut.tscn").instantiate()
	world.add_child(house)
	house.position = Vector3(16,0,12)
	var hunter = _unit(world, Vector3(12,0,6))
	assert(house.add_worker(hunter))
	var resident = _unit(world, Vector3(12,0,-6))
	var enemy: EnemyBase = load("res://Scene/unit/enemy_base.tscn").instantiate()
	world.add_child(enemy)
	enemy.position = Vector3(14,0,6)
	enemy.set_process(false)
	enemy.set_physics_process(false)
	enemy.health_component.max_health = 1000.0
	enemy.health_component.current_health = 1000.0
	var manager := TaskManager.new()
	world.add_child(manager)
	manager.set_process(false)
	var mesh = runtime._new_navigation_mesh()
	NavigationServer3D.bake_from_source_geometry_data(mesh, runtime._navigation_geometry())
	region.navigation_mesh = mesh
	for i in range(12): await physics_frame
	# 未受伤居民不因看见敌人逃跑。
	enemy.position = resident.position + Vector3(2,0,0)
	assert(not resident._process_civilian_retreat(0.016))
	var task := GameTask.new(&"retreat_loot", GameTask.TaskType.PICKUP_LOOT)
	task.target = enemy
	manager.register_task(task)
	assert(manager.claim_task(task, resident))
	resident.carried_resource_id = &"wood"
	resident.carried_amount = 2.0
	assert(resident.take_damage(5.0, enemy) > 0.0)
	assert(resident.state == resident.State.RETREAT_TO_BASE)
	assert(resident.current_task == null and task.state == GameTask.State.AVAILABLE and task.assigned_worker == null)
	assert(not resident.is_idle() and not resident.can_take_task(null))
	assert(resident.carried_amount == 2.0)
	manager.set_physics_process(false)
	enemy.position = hunter.position + Vector3(2,0,0)
	hunter.hunting.prey_count = 2
	hunter.hunting.raw_meat = 3.0
	var start: Vector3 = hunter.position
	assert(hunter._process_civilian_retreat(0.016))
	assert(hunter.state == hunter.State.RETREAT_TO_BASE)
	var found_arrow := false
	for child: Node in world.get_children():
		if child.get_script() == hunter.ARROW_SCRIPT:
			assert(child.damage == hunter.ARCHER_DATA.damage * 0.5 and child.target == enemy)
			found_arrow = true
	assert(found_arrow)
	for i in range(60):
		hunter._process_civilian_retreat(1.0 / 60.0)
		resident._process_civilian_retreat(1.0 / 60.0)
		await physics_frame
	assert(hunter.position.distance_to(start) > 1.0)
	assert(enemy.health_component.current_health < 1000.0)
	assert(hunter.hunting.prey_count == 2 and hunter.hunting.raw_meat == 3.0)
	# 保持附近有威胁：抵达据点后继续等待，不能重领任务。
	for i in range(600):
		enemy.position = hunter.position + Vector3(3,0,0)
		hunter._process_civilian_retreat(1.0 / 60.0)
		resident._process_civilian_retreat(1.0 / 60.0)
		await physics_frame
	assert(hunter.state == hunter.State.RETREAT_TO_BASE)
	assert(hunter.position.distance_to(hunter.navigation_agent.target_position) < 2.1)
	enemy.free()
	for i in range(300):
		hunter._process_civilian_retreat(1.0 / 60.0)
		resident._process_civilian_retreat(1.0 / 60.0)
		await physics_frame
	assert(hunter.state == hunter.State.HUNTING and hunter.hunting.returning)
	assert(resident.state == resident.State.DEPOSIT_TO_BASE and resident.carried_amount == 2.0)
	# 狩猎依旧使用猎户伤害，不受对敌伤害影响。
	var prey: Node3D = load("res://data/wildlife/boar.tres").scene.instantiate()
	prey.data = load("res://data/wildlife/boar.tres")
	world.add_child(prey)
	prey.set_physics_process(false)
	prey.position = hunter.position + Vector3(1,0,0)
	assert(prey.claim(hunter))
	hunter.fire_arrow(prey)
	for child: Node in world.get_children():
		if child.get_script() == hunter.ARROW_SCRIPT and child.target == prey:
			assert(child.damage == hunter.HUNTER_DATA.damage)
	var soldier = _unit(world, Vector3(-10,0,0))
	soldier.set_combat_role(CombatRole.Type.SWORDSMAN)
	soldier.take_damage(5.0)
	assert(soldier.state != soldier.State.RETREAT_TO_BASE)
	print("猎户边射边退、伤害比例、猎物伤害、居民受击释放任务与保留货物、抵达安全后恢复、军事单位回归：通过")
	quit()
