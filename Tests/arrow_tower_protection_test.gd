extends SceneTree

var failed: bool = false

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var main: Node3D = load("res://Scene/main.tscn").instantiate()
	main.level_preset = main.level_preset.duplicate(true)
	main.level_preset.layout_seed = 418
	main.level_preset.events.clear()
	main.level_preset.camp_config.enabled = false
	main.level_preset.wildlife_config.enabled = false
	root.add_child(main)
	current_scene = main
	for index in range(20): await physics_frame
	for unit: Node in get_nodes_in_group("villagers"):
		unit.set_physics_process(false)
	var base: Node3D = get_first_node_in_group("bases") as Node3D
	var data: BuildingData = load("res://data/buildings/ArrowTowerData.tres").duplicate(true)
	data.max_health = 20
	var tower: Barracks = data.building_scene.instantiate() as Barracks
	tower.set_building_data(data)
	main.add_child(tower)
	tower.set_process(false)
	tower.global_position = base.global_position + Vector3(3, 0, 3)
	var archers: Array[Node3D] = []
	for index in range(2):
		var archer: Node3D = load("res://Scene/unit/villager.tscn").instantiate()
		main.add_child(archer)
		archer.set_physics_process(false)
		archer.set_combat_role(CombatRole.Type.ARCHER)
		archer.enter_garrison(tower)
		archers.append(archer)
	var enemy: EnemyBase = load("res://Scene/unit/enemy_base.tscn").instantiate()
	main.add_child(enemy)
	enemy.set_process(false)
	enemy.set_physics_process(false)
	enemy.global_position = tower.global_position + Vector3(0, 0.6, 1)
	enemy.update_targeting()
	_expect(enemy.target == tower, "怪物发现塔上弓箭手后锁定箭塔")
	var health: float = archers[0].get_health()
	_expect(archers[0].take_damage(10, enemy) == 0 and archers[0].get_health() == health, "塔上弓箭手拒绝直接伤害")
	enemy._physics_process(1.0)
	_expect(tower.get_health() == 16 and archers[0].get_health() == health, "怪物实际攻击箭塔，弓箭手不掉血")
	var ability: AbilityData = load("res://data/abilities/GroundSlam.tres").duplicate(true)
	ability.radius = 10
	var targets: Array[Node] = ability._collect_targets(enemy, archers[0], 1)
	_expect(not targets.has(archers[0]) and not targets.has(archers[1]), "范围伤害与击退不命中塔内驻军")
	var enemy_health: float = enemy.current_health
	archers[0]._process_tower_combat(1.0)
	for index in range(90):
		if enemy.current_health < enemy_health: break
		await physics_frame
	_expect(enemy.current_health < enemy_health, "受保护的弓箭手仍可从箭塔射击")
	tower.unregister_garrison(archers[1])
	archers[1].leave_garrison()
	_expect(archers[1].take_damage(5, enemy) == 5, "离塔的地面弓箭手可以被攻击")
	_expect(not archers[1].is_stunned(), "正常下塔不触发晕眩")
	var pending: Node3D = load("res://Scene/unit/villager.tscn").instantiate()
	main.add_child(pending)
	pending.set_physics_process(false)
	pending.set_combat_role(CombatRole.Type.ARCHER)
	_expect(pending.try_assign_to_barracks(tower), "预约尚未上塔的弓箭手")
	tower.take_damage(100, enemy)
	_expect(archers[0].garrisoned_in == null and archers[0].get_damage_protector() == null, "箭塔被毁后驻军离塔并失去保护")
	enemy.update_targeting()
	_expect(enemy.target in archers, "箭塔被毁后怪物可以锁定落地弓箭手")
	_expect(archers[0].take_damage(5, enemy) == 5 and archers[0].get_health() == health - 5, "箭塔被毁后弓箭手正常受到伤害")
	_expect(is_equal_approx(archers[0].stun_remaining, 2.0) and archers[0].is_stunned(), "塔上弓箭手落地触发两秒晕眩")
	_expect(not pending.is_stunned(), "尚未上塔的弓箭手不受坠塔晕眩影响")
	var position: Vector3 = archers[0].global_position
	var arrows_before: int = main.get_child_count()
	archers[0].combat_attack_cooldown = 0.0
	for i in range(3): archers[0]._physics_process(0.5)
	_expect(archers[0].is_stunned() and is_equal_approx(archers[0].stun_remaining, 0.5), "经过1.5秒仍晕眩")
	_expect(archers[0].global_position == position and archers[0].velocity == Vector3.ZERO and main.get_child_count() == arrows_before, "晕眩期间不能移动或射箭")
	_expect(not archers[0].is_idle() and not archers[0].can_accept_treasure_hunt(), "晕眩期间不可重新驻守或接受寻宝")
	var panel: Node = main.villager_panel
	panel.open_unit(archers[0])
	panel.refresh()
	_expect(panel.state_label.text.contains("晕眩") and panel.state_label.text.contains("0.5"), "单位面板显示晕眩剩余时间")
	archers[0].set_physics_process(true)
	paused = true
	for i in range(6): await physics_frame
	_expect(is_equal_approx(archers[0].stun_remaining, 0.5), "暂停游戏时不减少晕眩时间")
	paused = false
	archers[0].set_physics_process(false)
	archers[0]._physics_process(0.5)
	_expect(not archers[0].is_stunned(), "两秒后晕眩解除")
	var children_before_recovery: int = main.get_child_count()
	# 坠塔前的一次射击停顿可能尚未结束，解除晕眩后允许走完停顿再发射。
	for frame: int in range(6):
		archers[0]._physics_process(0.1)
		if main.get_child_count() > children_before_recovery: break
	_expect(main.get_child_count() > children_before_recovery, "晕眩解除后恢复射箭")
	var safe_tower: Barracks = data.building_scene.instantiate()
	safe_tower.set_building_data(data)
	main.add_child(safe_tower)
	safe_tower.set_process(false)
	safe_tower.global_position = base.global_position + Vector3(-4,0,4)
	_expect(safe_tower.register_garrison(archers[1]), "登记拆除测试的箭塔驻军")
	safe_tower.enter_garrison(archers[1])
	_expect(safe_tower.demolish(), "主动拆除箭塔成功")
	_expect(archers[1].garrisoned_in == null and not archers[1].is_stunned(), "主动拆除箭塔正常疏散不触发坠塔晕眩")
	main.queue_free()
	await process_frame
	print("箭塔驻军保护测试", "失败" if failed else "通过")
	quit(1 if failed else 0)

func _expect(value: bool, message: String) -> void:
	print("[", "通过" if value else "失败", "] ", message)
	if not value:
		failed = true
		push_error(message)
