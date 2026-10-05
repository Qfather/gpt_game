extends SceneTree

var failed: bool = false

func _init() -> void:
	call_deferred("_run")

func _expect(value: bool, message: String) -> void:
	print("[通过] " if value else "[失败] ", message)
	failed = failed or not value

func _capture(name: String) -> void:
	if DisplayServer.get_name() == "headless": return
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png("res://.godot/" + name + ".png")

func _hide_in(resident: Node, building: BuildingBase) -> void:
	resident.shelter_target = building
	_expect(building.reserve_shelter(resident), "建筑能接纳避难居民")
	resident.shelter_exit_position = building.get_interaction_position(resident)
	resident.global_position = building.global_position
	resident.state = resident.State.SHELTERED
	resident.visible = false
	resident.collision_layer = 0
	resident.collision_mask = 0
	resident.set_physics_process(false)

func _run() -> void:
	var main: Node = load("res://Scene/main.tscn").instantiate()
	main.level_preset = main.level_preset.duplicate(true)
	main.level_preset.events.clear()
	main.level_preset.camp_config.first_spawn_time = 86400.0
	main.get_node("Systems/MapGenerateRuntime").settlement_seed = 42
	root.add_child(main)
	current_scene = main
	for frame: int in range(90): await physics_frame
	get_first_node_in_group("population_manager").set_process(false)
	var hud: GameHUD = main.get_node("UI/HUD")
	var first: Node = get_nodes_in_group("villagers")[0]
	first.character_name = "死亡测试甲"
	first.take_damage(100000.0)
	_expect(hud.death_notifications.get_child_count() == 1 and "死亡测试甲" in hud.death_notifications.get_child(0).text, "友方死亡在威胁方向下显示姓名")
	Engine.time_scale = 10.0
	await create_timer(1.0, true, false, true).timeout
	var second: Node = get_nodes_in_group("villagers")[0]
	second.character_name = "死亡测试乙"
	second.take_damage(100000.0)
	_expect(hud.death_notifications.get_child_count() == 2, "多条死亡提示按顺序排列")
	for frame: int in range(2): await process_frame
	_capture("friendly_death_notifications")
	await create_timer(4.2, true, false, true).timeout
	await process_frame
	_expect(hud.death_notifications.get_child_count() == 1 and "死亡测试乙" in hud.death_notifications.get_child(0).text, "满 5 秒移除首条，下方提示补位")
	await create_timer(1.0, true, false, true).timeout
	await process_frame
	_expect(hud.death_notifications.get_child_count() == 0, "每条提示独立到期消失")
	Engine.time_scale = 1.0
	var enemy: EnemyBase = load("res://Scene/unit/enemy_base.tscn").instantiate()
	enemy.enemy_data = load("res://data/enemies/raid/SlimeData.tres").duplicate(true)
	main.get_node("Enemies").add_child(enemy)
	enemy.set_physics_process(false)
	enemy.raid_active = true
	var panel: EnemyPanel = main.get_node("UI/EnemyPanel")
	panel.current_building = enemy
	for objective: int in [EnemyData.RaidObjective.KILL_UNITS, EnemyData.RaidObjective.DESTROY_BUILDINGS, EnemyData.RaidObjective.STEAL_RESOURCES]:
		enemy.enemy_data.raid_objective = objective
		panel.refresh()
		_expect(panel.intention_label.text == "第一意图：" + ["", "击杀单位", "摧毁建筑", "掠夺资源"][objective], "敌人面板显示配置的第一意图")
	panel.show()
	panel.position.x = panel.opened_x
	for frame: int in range(2): await process_frame
	_capture("enemy_first_intention")
	var base: Node3D = get_first_node_in_group("bases")
	var camp: SwordsmanCamp = load("res://Scene/building/game/swordsman_camp.tscn").instantiate()
	camp.building_data = load("res://data/buildings/SwordsmanCampData.tres")
	camp.training_time = 0.5
	camp.training_slots = 1
	main.get_node("buildings").add_child(camp)
	camp.global_position = base.global_position + Vector3(5,0,0)
	var resident: Node = get_first_node_in_group("villagers")
	_hide_in(resident, camp)
	var capacity_probe: Node = load("res://Scene/unit/villager.tscn").instantiate()
	_expect(not camp.can_shelter(capacity_probe), "训练建筑避难容量遵守训练人数上限")
	capacity_probe.free()
	enemy.global_position = camp.global_position + Vector3(0,0,4)
	var manager: TaskManager = get_first_node_in_group("task_manager")
	_expect(camp.request_training(), "营内避难居民可请求训练")
	manager._run_dispatch()
	_expect(resident.state == resident.State.TRAINING and not resident.visible and resident.current_task != null, "营内避难居民直接开始训练")
	_expect(camp.get_shelter_occupants().size() == 1 and camp.shelter_residents.is_empty(), "避难名额转换为训练名额，不重复占位")
	resident.process_training(0.6)
	_expect(resident.has_combat_role() and resident.visible, "避难居民训练完成成为可见剑士")
	resident.queue_free()
	await process_frame
	var house: House = load("res://Scene/building/game/house.tscn").instantiate()
	house.building_data = load("res://data/buildings/HouseData.tres")
	main.get_node("buildings").add_child(house)
	house.global_position = base.global_position + Vector3(-5,0,0)
	var sheltered: Node = load("res://Scene/unit/villager.tscn").instantiate()
	main.get_node("Villagers").add_child(sheltered)
	for frame: int in range(3): await physics_frame
	_hide_in(sheltered, house)
	var population: int = get_nodes_in_group("villagers").size()
	_expect(camp.request_training(), "外面无人时仍可下达训练命令")
	manager._run_dispatch()
	_expect(sheltered.state == sheltered.State.MOVE_TO_TRAINING and sheltered.visible and sheltered.shelter_target == null, "居民从其他避难建筑出来前往训练营")
	_expect(not sheltered._process_civilian_retreat(0.1) and sheltered.current_task != null, "执行训练命令时不因敌人折返避难")
	_expect(get_nodes_in_group("villagers").size() == population, "调用避难居民不新增人口")
	sheltered.set_physics_process(true)
	for frame: int in range(900):
		await physics_frame
		if sheltered.has_combat_role(): break
	_expect(sheltered.has_combat_role() and sheltered.visible, "其他建筑的避难居民实际跑到营地完成训练")
	var notice_count: int = hud.death_notifications.get_child_count()
	enemy.take_damage(100000.0)
	_expect(hud.death_notifications.get_child_count() == notice_count, "敌方死亡不显示友方死亡通知")
	quit(1 if failed else 0)
