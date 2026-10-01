extends SceneTree

var failed: bool = false

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var main: Node3D = load("res://Scene/main.tscn").instantiate()
	main.level_preset = main.level_preset.duplicate(true)
	main.level_preset.layout_seed = 418
	main.level_preset.events.clear()
	main.level_preset.camp_config.first_spawn_time = 86400
	root.add_child(main)
	current_scene = main
	for index: int in range(20):
		await physics_frame
		await process_frame
	var base: Node3D = get_first_node_in_group("bases") as Node3D
	var barracks: Barracks = load("res://Scene/building/game/barracks.tscn").instantiate()
	main.add_child(barracks)
	# 本测试隔离自动轮换巡逻与补粮，仅验证受击出营、战斗与返营。
	barracks.set_process(false)
	barracks.global_position = base.global_position + Vector3(6, 0, 0)
	var units: Array[Node] = get_nodes_in_group("villagers")
	var defenders: Array[Node] = [units[0], units[1]]
	var patrol: Node = units[2]
	patrol.set_combat_role(CombatRole.Type.SWORDSMAN)
	patrol.set_physics_process(false)
	patrol.patrol_barracks = barracks
	patrol.state = patrol.State.MOVE_TO_PATROL_POINT
	patrol.patrol_target_position = base.global_position + Vector3(0, 0, 10)
	barracks.active_patrol_units.append(patrol)
	for index: int in range(defenders.size()):
		var unit: Node = defenders[index]
		unit.set_combat_role(CombatRole.Type.SWORDSMAN if index == 0 else 99)
		unit.global_position = barracks.get_garrison_entrance_position(unit)
		unit.combat_damage = 100.0
		unit.combat_attack_interval = 0.1
		barracks.garrisoned_units.append(unit)
		unit.enter_garrison(barracks)
	defenders[1].state = defenders[1].State.GARRISON_RESTING
	_expect(not defenders[0]._process_combat(0.1) and not defenders[0].visible, "未受警报时驻军仍在军营内，不隔墙攻击")
	var enemy: EnemyBase = load("res://Scene/unit/enemy_base.tscn").instantiate()
	enemy.enemy_data = load("res://data/enemies/raid/SlimeData.tres").duplicate(true)
	main.add_child(enemy)
	enemy.global_position = base.global_position + Vector3(-6, 0, 0)
	enemy.set_process(false)
	enemy.set_physics_process(false)
	base.take_damage(0.0, enemy)
	base.take_damage(1.0, patrol)
	base.take_damage(1.0)
	_expect(defenders[0].is_garrisoned() and defenders[1].is_garrisoned(), "零伤害、友方来源与无来源扣血不触发出营")
	base.take_damage(1.0, enemy)
	for unit: Node in defenders:
		_expect(unit.visible and unit.garrisoned_in == null and unit.combat_target == enemy, "驻军（含休息及非剑士角色）收到真实受击通知后出营锁定攻击者")
		_expect(unit.collision_layer == 2 and unit.collision_mask != 0, "出营恢复战斗碰撞")
	_expect(barracks.garrisoned_units.is_empty() and barracks.get_garrison_occupancy_count() == 3, "两名出营驻军与原有巡逻单位继续占用原军营床位")
	base.take_damage(1.0, enemy)
	_expect(barracks.garrison_reservations.size() == 2, "连续受击不会重复登记出营单位")
	_expect(patrol.state == patrol.State.MOVE_TO_PATROL_POINT and patrol.patrol_target_position == base.global_position + Vector3(0, 0, 10), "已有巡逻任务不被警报覆盖")
	var initial_position: Vector3 = defenders[0].global_position
	for index: int in range(60):
		await physics_frame
		if not is_instance_valid(enemy) or enemy.is_dead():
			break
	_expect(defenders[0].global_position.distance_to(initial_position) > 0.5, "驻军实际从军营向据点攻击者移动")
	for index: int in range(900):
		await physics_frame
		await process_frame
		if defenders[0].is_garrisoned() and defenders[1].is_garrisoned():
			break
	_expect(not is_instance_valid(enemy) or enemy.is_dead(), "出营单位实际击败攻击者")
	_expect(defenders[0].garrisoned_in == barracks and defenders[1].garrisoned_in == barracks, "战斗结束后两名驻军实际走回原军营")
	_expect(not defenders[0].visible and not defenders[1].visible and barracks.garrison_reservations.is_empty(), "返营后恢复隐藏驻军并清除预留床位")
	main.queue_free()
	await process_frame
	print("据点受击驻军防御测试", "失败" if failed else "通过")
	quit(1 if failed else 0)

func _expect(condition: bool, message: String) -> void:
	print("[", "通过" if condition else "失败", "] ", message)
	if not condition:
		failed = true
		push_error("失败：" + message)
