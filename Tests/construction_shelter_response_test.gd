extends SceneTree

var failed: bool = false

func _init() -> void:
	call_deferred("_run")

func _expect(value: bool, message: String) -> void:
	print("[通过] " if value else "[失败] ", message)
	failed = failed or not value

func _unit(world: Node3D, position: Vector3) -> CharacterBody3D:
	var unit: CharacterBody3D = load("res://Scene/unit/villager.tscn").instantiate()
	world.add_child(unit)
	unit.position = position
	unit.set_physics_process(false)
	unit.hunger_rate = 0.0
	unit.fatigue_rate = 0.0
	return unit

func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world
	var region := NavigationRegion3D.new()
	var navigation := NavigationMesh.new()
	navigation.vertices = PackedVector3Array([Vector3(-50,0,-50),Vector3(-50,0,50),Vector3(50,0,50),Vector3(50,0,-50)])
	navigation.add_polygon(PackedInt32Array([0,1,2,3]))
	region.navigation_mesh = navigation
	world.add_child(region)
	var base: Node3D = load("res://Scene/building/base.tscn").instantiate()
	world.add_child(base)
	base.position = Vector3(-20,0,0)
	var units: Array[CharacterBody3D] = []
	for index: int in range(5): units.append(_unit(world, Vector3(index * 2,0,0)))
	for frame: int in range(10): await physics_frame
	var manager := TaskManager.new()
	world.add_child(manager)
	manager.set_process(false)
	manager.set_physics_process(false)
	var worker: CharacterBody3D = units[0]
	var panel: VillagerPanel = load("res://UI/unit_panel/villager_panel.tscn").instantiate()
	root.add_child(panel)
	panel.current_unit = worker
	_expect(panel.STATE_DISPLAY_NAMES[worker.State.MOVE_TO_FIELD] == "前往田地" and panel.STATE_DISPLAY_NAMES[worker.State.WORKING_FIELD] == "正在处理田地", "田地状态索引与枚举一致")
	var site: ConstructionSite = load("res://Scene/building/construction_site.tscn").instantiate()
	site.setup(load("res://data/buildings/HouseData.tres"), Vector2i.ZERO, 0, false)
	site.set_activation_deferred_until_unpause(true)
	world.add_child(site)
	site.position = Vector3(0,0,12)
	site.set_process(false)
	for index: int in range(3):
		var point: Vector3 = site.get_worker_target_position(units[index]) - site.global_position
		_expect(point.x >= site.model_bounds.position.x and point.x <= site.model_bounds.end.x and point.z >= site.model_bounds.position.z and point.z <= site.model_bounds.end.z, "施工站位%d位于工地内部" % index)
	worker.wait_at_construction_site(site)
	worker.position = worker.navigation_agent.target_position
	panel.refresh()
	_expect(panel.state_label.text == "状态：等待建材" and not worker.has_idle_warning(), "工人等待建材时显示正确状态、不亮待命感叹号")
	for resource_id: StringName in site.required_resources:
		site.receive_delivery(resource_id, site.required_resources[resource_id])
	var build_task: GameTask = manager.create_task(GameTask.TaskType.BUILD, site, site, 10)
	_expect(manager.claim_task(build_task, worker), "领取真实施工任务")
	worker.position = site.position + Vector3(0,0,5)
	worker._start_current_task()
	for frame: int in range(300):
		worker.move_to_build_site()
		await physics_frame
		if worker.state == worker.State.BUILDING: break
	_expect(worker.state == worker.State.BUILDING and worker._has_reached_task_site_navigation_target(), "居民实际走进工地后才开始施工")
	manager.cancel_task(build_task)
	worker.task_site = null
	var camp: SwordsmanCamp = load("res://Scene/building/game/swordsman_camp.tscn").instantiate()
	world.add_child(camp)
	camp.position = Vector3(10,0,10)
	worker.job = worker.Job.NONE
	worker.state = worker.State.IDLE
	var task: GameTask = manager.create_task(GameTask.TaskType.TRAIN_SWORDSMAN, camp, camp, 10)
	_expect(manager.claim_task(task, worker) and camp.begin_training(worker), "注册并开始真实训练任务")
	worker.idle_reposition_timer = 9.0
	_expect(camp.complete_training(worker), "完成训练任务")
	worker.move_to_idle_area()
	_expect(worker.state == worker.State.RETURN_TO_IDLE and not worker.has_idle_warning(), "训练完成后保持返回状态，不因旧路径结束而原地待命")
	var before: Vector3 = worker.position
	for frame: int in range(20):
		worker.move_to_idle_area()
		await physics_frame
	_expect(worker.position.distance_to(before) > 0.5, "训练完成后一秒内实际开始返回")
	for frame: int in range(600):
		worker.move_to_idle_area()
		await physics_frame
		if worker.state == worker.State.IDLE: break
	_expect(worker.state == worker.State.IDLE and not worker.has_idle_warning() and Vector2(worker.position.x - base.position.x, worker.position.z - base.position.z).length() <= base.idle_radius, "剑士最终在据点待命区停下，不亮异地待命警告")
	# 本测试的满员回据点场景只保留资源建筑和住宅，训练营避难由独立训练测试覆盖。
	camp.remove_from_group("buildings")
	var lumber: ResourceBuildingBase = load("res://Scene/building/game/lumber_camp.tscn").instantiate()
	world.add_child(lumber)
	lumber.position = Vector3(6,0,0)
	lumber.max_workers = 1
	lumber.set_process(false)
	var quarry: ResourceBuildingBase = load("res://Scene/building/game/quarry.tscn").instantiate()
	world.add_child(quarry)
	quarry.position = Vector3(12,0,0)
	quarry.max_workers = 1
	quarry.set_process(false)
	var house: House = load("res://Scene/building/game/house.tscn").instantiate()
	world.add_child(house)
	house.position = Vector3(18,0,0)
	house.housing_capacity = 1
	_expect(lumber.add_worker(units[1]), "伐木场岗位已有一名工人")
	_expect(not lumber.can_shelter(units[2]) and lumber.can_shelter(units[1]), "工人与避难者共享名额，原工人进入不重复计数")
	var enemy: EnemyBase = load("res://Scene/unit/enemy_base.tscn").instantiate()
	world.add_child(enemy)
	enemy.set_process(false)
	enemy.set_physics_process(false)
	enemy.position = Vector3(15,0,0)
	var resident: CharacterBody3D = units[2]
	resident.position = Vector3(10,0,0)
	resident._begin_civilian_retreat(enemy)
	_expect(resident.shelter_target == quarry, "附近伐木场已满，选择采石场并预约名额")
	units[3].position = Vector3(10,0,1)
	units[3]._begin_civilian_retreat(enemy)
	_expect(units[3].shelter_target == house, "采石场被预约后选择住宅，避免同时超员")
	units[4]._begin_civilian_retreat(enemy)
	_expect(units[4].shelter_target == null, "附近建筑全部满员后回据点")
	worker.position = Vector3(-1,0,0)
	worker.state = worker.State.IDLE
	resident.position = Vector3(5,0,0)
	worker.combat_detection_range = 8.0
	worker._process_combat(0.016)
	_expect(worker.combat_target == enemy and worker.state == worker.State.COMBAT_MOVE, "剑士看到逃跑居民，追击自身仇恨范围之外的敌人")
	resident.position = resident.navigation_agent.target_position
	resident._process_civilian_retreat(0.016)
	_expect(resident.state == resident.State.SHELTERED and not resident.visible and not resident.can_take_task(null), "进入避难建筑后隐藏，停止领任务")
	_expect(resident.take_damage(5.0, enemy) == 0.0 and resident.get_damage_protector() == quarry, "建筑保护避难居民，敌人攻击保护建筑")
	quarry.health_destroyed = true
	quarry.destroyed = true
	resident._process_civilian_retreat(0.016)
	_expect(resident.visible and resident.state == resident.State.RETREAT_TO_BASE and resident.shelter_target == null, "避难建筑失效后居民离开，其他建筑已满则回据点")
	units[1].position = Vector3(6,0,2)
	units[1]._begin_civilian_retreat(enemy)
	units[1].position = units[1].navigation_agent.target_position
	units[1]._process_civilian_retreat(0.016)
	_expect(units[1].state == units[1].State.SHELTERED, "原工人可进入自己的满员工作建筑避难")
	enemy.position = Vector3(40,0,40)
	units[1]._process_civilian_retreat(0.016)
	_expect(units[1].visible and units[1].state == units[1].State.FIND_RESOURCE and units[1].workplace == lumber, "附近安全后退出避难并恢复伐木职业")
	panel.queue_free()
	world.queue_free()
	await process_frame
	print("施工、状态、训练、迎敌与避难测试", "失败" if failed else "通过")
	quit(1 if failed else 0)
