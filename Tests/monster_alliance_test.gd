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
	var data := TreasureCampData.new()
	var monster: EnemyData = load("res://data/enemies/raid/SlimeData.tres").duplicate(true)
	monster.max_health = 100.0
	monster.detection_range = 20.0
	var camp: TreasureCamp = load("res://Scene/world/treasure_camp.tscn").instantiate()
	var positions: Array[Vector3] = [Vector3.ZERO]
	camp.configure_camp(data, {"guards": [monster], "rewards": {&"wood": 3}}, positions, 0.0)
	world.add_child(camp)
	camp.set_process(false)
	var guard: EnemyBase = camp.guards[0]
	guard.set_process(false)
	guard.set_physics_process(false)
	var allies: Array[EnemyBase] = [guard]
	for faction: int in [EnemyData.Faction.RAID, EnemyData.Faction.RIFT]:
		var enemy: EnemyBase = load("res://Scene/unit/enemy_base.tscn").instantiate()
		enemy.enemy_data = monster.duplicate(true)
		enemy.faction_override = faction
		world.add_child(enemy)
		enemy.position = Vector3(0.5 * faction, 0.6, 0)
		enemy.set_process(false)
		enemy.set_physics_process(false)
		allies.append(enemy)
	for enemy: EnemyBase in allies:
		enemy.update_targeting()
		_expect(enemy.target == null, "营地、袭扰、裂缝互不索敌：阵营%d" % enemy.get_faction())
	var ability: AbilityData = load("res://data/abilities/GroundSlam.tres").duplicate(true)
	ability.radius = 10.0
	for attacker: EnemyBase in allies:
		for victim: EnemyBase in allies:
			if attacker == victim: continue
			var health: float = victim.current_health
			_expect(victim.take_damage(5.0, attacker) == 0.0 and victim.current_health == health, "同盟普通伤害不生效：%d→%d" % [attacker.get_faction(), victim.get_faction()])
			_expect(ability._collect_targets(attacker, victim, 1.0).is_empty(), "同盟不进入范围技能目标：%d→%d" % [attacker.get_faction(), victim.get_faction()])
	var player: Node3D = load("res://Scene/unit/villager.tscn").instantiate()
	world.add_child(player)
	player.set_process(false)
	player.set_physics_process(false)
	player.set_combat_role(CombatRole.Type.SWORDSMAN)
	player.position = Vector3(0,0,1)
	for enemy: EnemyBase in allies:
		enemy.update_targeting()
		_expect(enemy.target == player, "同盟怪物仍会攻击玩家：阵营%d" % enemy.get_faction())
		var targets: Array[Node] = ability._collect_targets(enemy, player, 1.0)
		_expect(targets.size() == 1 and targets[0] == player, "敌方范围技能只命中玩家")
	var health: float = player.get_health()
	_expect(ability.try_use(allies[2], player) and player.get_health() < health, "裂缝范围技能仍可实际伤害玩家")
	_expect(player._find_nearest_hostile(20.0) in allies, "玩家仍将三类怪物视为敌人")
	var player_targets: Array[Node] = ability._collect_targets(player, guard, 1.0)
	_expect(player_targets.size() == 3, "玩家技能可命中所有怪物阵营")
	_expect(guard.take_damage(5.0, player) > 0.0, "玩家可正常伤害营地守卫")
	guard.take_damage(1000.0, allies[2])
	camp._process(0.016)
	_expect(not guard.is_dead() and not camp.cleared and not camp.is_in_group("loot_bundles") and camp.pickup_task == null, "裂缝怪物不能清空营地并触发搬运")
	guard.take_damage(1000.0, player)
	camp._process(0.016)
	_expect(guard.is_dead() and camp.cleared and camp.is_in_group("loot_bundles"), "玩家击败全部守卫后仍正常解锁战利品")
	world.queue_free()
	await process_frame
	print("怪物同盟与营地清剿条件测试", "失败" if failed else "通过")
	quit(1 if failed else 0)
