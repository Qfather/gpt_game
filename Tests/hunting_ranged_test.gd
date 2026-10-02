extends SceneTree

var failed: bool = false
var main: Node3D
var base: Node3D

func _init() -> void:
	call_deferred("_run")

func _check(value: bool, text: String) -> void:
	if not value:
		failed = true
		push_error("狩猎与远程测试失败：" + text)

func _wait(condition: Callable, frames: int = 1800) -> bool:
	for i: int in range(frames):
		if condition.call(): return true
		await physics_frame
		await process_frame
	return condition.call()

func _unit(role: int = CombatRole.Type.NONE) -> Node3D:
	var unit: Node3D = load("res://Scene/unit/villager.tscn").instantiate()
	main.add_child(unit)
	unit.set_combat_role(role)
	unit.global_position = base.global_position + Vector3(3, 0, 3)
	unit.hunger_rate = 0.0
	unit.fatigue_rate = 0.0
	return unit

func _building(path: String, offset: Vector3) -> Node3D:
	var data: BuildingData = load(path)
	var building: Node3D = data.building_scene.instantiate()
	building.set_building_data(data)
	main.add_child(building)
	building.global_position = base.global_position + offset
	return building

func _run() -> void:
	Engine.time_scale = 4.0
	main = load("res://Scene/main.tscn").instantiate()
	main.level_preset = main.level_preset.duplicate(true)
	main.level_preset.layout_seed = 418
	main.level_preset.events.clear()
	main.level_preset.camp_config.enabled = false
	main.level_preset.wildlife_config.enabled = false
	root.add_child(main)
	current_scene = main
	for i: int in range(30):
		await physics_frame
		await process_frame
	base = get_first_node_in_group("bases")
	for existing: Node in get_nodes_in_group("villagers"):
		existing.set_physics_process(false)
	for existing: Node in get_nodes_in_group("enemies"): existing.queue_free()
	var manager: Node = main.get_node("Systems/WildlifeManager")
	manager.config.enabled = true
	manager.refill()
	_check(get_nodes_in_group("wildlife").size() == 12, "地图周边生成到数量上限")
	manager.refill()
	_check(get_nodes_in_group("wildlife").size() == 12, "重复补充不超过上限")
	get_nodes_in_group("wildlife")[0].free()
	manager.refill()
	_check(get_nodes_in_group("wildlife").size() == 12, "移除后补充缺额")
	manager.config.enabled = false
	for animal: Node in get_nodes_in_group("wildlife"): animal.free()
	var house: Node3D = _building("res://data/buildings/HunterHutData.tres", Vector3(3, 0, 3))
	var hunter: Node3D = _unit()
	var second: Node3D = _unit()
	_check(house.add_worker(hunter) and house.add_worker(second), "小屋接收两名猎户")
	var spare: Node3D = _unit()
	_check(not house.add_worker(spare), "拒绝第三名猎户")
	second.set_physics_process(false)
	spare.set_physics_process(false)
	hunter.hunger_rate = 0.0
	hunter.fatigue_rate = 0.0
	for name: String in ["rabbit", "pheasant", "boar"]:
		var data: Resource = load("res://data/wildlife/" + name + ".tres")
		var animal: Node3D = data.scene.instantiate()
		animal.data = data
		main.add_child(animal)
		animal.global_position = hunter.global_position + Vector3(1.5, 0, 0)
		_check(animal.claim(hunter) and not animal.claim(second), "猎物独占认领：" + name)
		_check(animal.take_damage(10, spare) == 0, "普通居民不能攻击猎物")
		_check(animal.take_damage(10, second) == 0, "未认领猎户不能攻击猎物")
		hunter.hunting.target = animal
		var old_position: Vector3 = animal.global_position
		var health: float = animal.health
		var animal_ref: WeakRef = weakref(animal)
		hunter.fire_arrow(animal)
		_check(animal.health == health, "发射时不会立刻扣血")
		_check(await _wait(func() -> bool: return animal_ref.get_ref() == null or animal_ref.get_ref().health < health, 120), "箭矢飞行后命中")
		if is_instance_valid(animal) and not animal.is_dead():
			await _wait(func() -> bool: return animal.global_position.x > old_position.x + 0.1, 60)
			_check(animal.global_position.x > old_position.x, "受击远离猎户逃跑")
		_check(await _wait(func() -> bool: return animal_ref.get_ref() == null, 1200), "猎户射杀并自动拾取：" + name)
		_check(hunter.hunting.prey_count <= 3, "携带猎物不超过三只")
	_check(await _wait(func() -> bool: return house.get_resource_amount(&"meat") == 6.0, 2400), "三种猎物回屋处理为1+2+3肉")
	_check(hunter.hunting.prey_count == 0 and not is_instance_valid(hunter.hunting.bundle), "处理后清除原猎物与背包")
	# 同时放置四只猎物，确认第三只拾取后先回屋，第四只留在地图。
	for i: int in range(4):
		var data: Resource = load("res://data/wildlife/rabbit.tres")
		var animal: Node3D = data.scene.instantiate()
		animal.data = data
		main.add_child(animal)
		animal.global_position = hunter.global_position + Vector3(0.4, 0, 0.2 * i)
	_check(await _wait(func() -> bool: return hunter.hunting.prey_count == 3, 900), "实际收集三只猎物")
	_check(get_nodes_in_group("wildlife").size() == 1, "满载后留下第四只猎物")
	_check(await _wait(func() -> bool: return house.get_resource_amount(&"meat") >= 9, 1200), "三只猎物整批处理")
	house.remove_worker(hunter)
	await _wait(func() -> bool: return hunter.job == hunter.Job.NONE, 300)
	_check(hunter.unit_data.id == &"resident", "解雇后恢复普通居民配置")
	var barracks: Node3D = _building("res://data/buildings/BarracksData.tres", Vector3(-6, 0, 0))
	barracks.set_process(false)
	var a: Node3D = _unit(CombatRole.Type.ARCHER)
	var b: Node3D = _unit(CombatRole.Type.ARCHER)
	_check(barracks.register_garrison(a) and barracks.register_garrison(b), "普通军营可接收弓箭手")
	barracks.enter_garrison(a)
	barracks.enter_garrison(b)
	var tower: Node3D = _building("res://data/buildings/ArrowTowerData.tres", Vector3(6, 0, 0))
	tower.add_food(&"grain", 10.0)
	_check(await _wait(func() -> bool: return tower.garrisoned_units.size() == 2, 1200), "两名弓箭手自动走到塔上")
	_check(barracks.get_garrison_count() == 0, "箭塔调入军营待命弓箭手并释放旧名额")
	_check(tower.get_garrison_count() == 2 and tower.get_sight_radius() == 18.0, "双人容量与1.5倍视野")
	_check(a.visible and b.visible and a.global_position.y > tower.global_position.y + 2.0, "弓箭手显示在塔顶")
	_check(not tower.register_garrison(spare), "拒绝非弓箭手驻守")
	var enemy: EnemyBase = load("res://Scene/unit/enemy_base.tscn").instantiate()
	enemy.enemy_data = load("res://data/enemies/raid/SlimeData.tres").duplicate(true)
	enemy.enemy_data.max_health = 100000.0
	main.add_child(enemy)
	enemy.set_physics_process(false)
	enemy.set_process(false)
	enemy.global_position = tower.global_position + Vector3(11, 0, 0)
	var health_before: float = enemy.current_health
	_check(await _wait(func() -> bool: return enemy.current_health <= health_before - 16, 240), "两人分别射箭命中基础射程之外的敌人")
	tower.take_food(&"grain", 10.0)
	_check(await _wait(func() -> bool: return tower.resupply_workers.size() == 1, 180), "缺粮仅派一人出塔")
	_check(tower.garrisoned_units.size() == 1 and tower.get_sight_radius() == 18.0, "另一人仍驻守并保留视野加成")
	health_before = enemy.current_health
	_check(await _wait(func() -> bool: return enemy.current_health < health_before, 240), "补粮期间守卫继续射箭")
	_check(await _wait(func() -> bool: return tower.get_food_amount() >= 10 and tower.garrisoned_units.size() == 2, 2400), "弓箭手实际往返据点补足粮食并归塔")
	_check(a.global_position.distance_to(b.global_position) > 1.0, "补粮归塔后两人占不同站位")
	b.set_physics_process(false)
	tower.remove_unit_from_rosters(b)
	b.set_combat_role(CombatRole.Type.NONE)
	b.leave_garrison()
	tower.take_food(&"grain", 10.0)
	_check(await _wait(func() -> bool: return tower.resupply_workers.size() == 1, 180), "单人驻塔时自行补粮")
	_check(tower.garrisoned_units.is_empty() and tower.get_sight_radius() == 12, "唯一驻军离塔后恢复基础视野")
	a.set_physics_process(false)
	# 等待离塔前已射出的箭落地，再验证空塔不会自己造成伤害。
	for i: int in range(20): await physics_frame
	health_before = enemy.current_health
	for i: int in range(12): await physics_frame
	_check(enemy.current_health == health_before, "无人驻塔时停止射击")
	a.set_physics_process(true)
	_check(await _wait(func() -> bool: return tower.garrisoned_units.size() == 1, 1800), "单人补粮后恢复驻守")
	var camp: Node3D = _building("res://data/buildings/ArcherCampData.tres", Vector3(-3, 0, 0))
	for unit: Node in get_nodes_in_group("villagers"):
		if unit != spare and not unit.has_combat_role(): unit.is_quitting_job = true
	spare.set_physics_process(true)
	_check(camp.request_training(), "弓箭手营创建训练任务")
	_check(await _wait(func() -> bool: return not camp.training_workers.is_empty() and camp.training_workers[0].state == camp.training_workers[0].State.TRAINING, 1200), "居民走进弓箭手营训练")
	if not camp.training_workers.is_empty():
		var trainee: Node = camp.training_workers[0]
		_check(not trainee.visible, "弓箭手训练期间隐藏居民")
		_check(await _wait(func() -> bool: return trainee.get_combat_role() == CombatRole.Type.ARCHER, 600), "训练完成获得弓箭手身份")
		_check(trainee.visible and trainee.unit_data.id == &"archer", "训练后出营并应用弓箭手配置")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/hunting_ranged_runtime.png")
	main.queue_free()
	await process_frame
	print("狩猎与远程运行测试", "失败" if failed else "通过")
	quit(1 if failed else 0)
