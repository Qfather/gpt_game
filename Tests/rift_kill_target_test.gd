extends SceneTree

class UnitTarget extends Node3D:
	var dead: bool = false
	var faction: int = EnemyData.Faction.SETTLEMENT
	func get_combat_role() -> int:
		return CombatRole.Type.NONE
	func has_combat_role() -> bool:
		return false
	func get_faction() -> int:
		return faction
	func is_dead() -> bool:
		return dead
	func take_damage(amount: float, _source: Node = null) -> float:
		return amount

var failed: bool = false


func _initialize() -> void:
	call_deferred("_run")


func _expect(value: bool, message: String) -> void:
	if not value:
		failed = true
		push_error("失败：" + message)


func _run() -> void:
	var wolf: EnemyBase = load("res://Scene/unit/enemy_base.tscn").instantiate() as EnemyBase
	wolf.enemy_data = load("res://data/enemies/rift/WolfData.tres").duplicate() as EnemyData
	wolf.enemy_data.raid_objective = EnemyData.RaidObjective.KILL_UNITS
	wolf.enemy_data.raid_kill_unit_id = &""
	wolf.raid_active = true
	root.add_child(wolf)
	wolf.set_process(false)
	wolf.set_physics_process(false)
	var base := UnitTarget.new()
	root.add_child(base)
	base.add_to_group("bases")
	base.position = Vector3(30, 0, 0)
	wolf.update_targeting()
	_expect(wolf.target == base, "无单位时未保留据点兜底")
	var first := UnitTarget.new()
	var second := UnitTarget.new()
	var ally := UnitTarget.new()
	for unit: UnitTarget in [first, second, ally]:
		root.add_child(unit)
		unit.add_to_group("villagers")
	first.position = Vector3(4, 0, 0)
	second.position = Vector3(6, 0, 0)
	ally.faction = EnemyData.Faction.RIFT
	ally.position = Vector3(1, 0, 0)
	wolf.update_targeting()
	_expect(wolf.target in [first, second], "发现范围内普通居民后仍攻击据点")
	var selected: Node3D = wolf.target
	for index: int in range(20):
		wolf.update_targeting()
		_expect(wolf.target == selected, "随机目标每帧变化")
	if selected is UnitTarget:
		selected.dead = true
	wolf.update_targeting()
	_expect(wolf.target in [first, second] and wolf.target != selected, "目标死亡后没有选择另一居民")
	first.position = Vector3(50, 0, 0)
	second.position = Vector3(60, 0, 0)
	wolf.update_targeting()
	_expect(wolf.target == base, "攻击了仇恨圈外单位或同阵营单位")
	first.dead = false
	first.position = Vector3(3, 0, 0)
	wolf.update_targeting()
	_expect(wolf.target == first, "行进途中重新发现居民后未切换目标")
	for node: Node in [wolf, base, first, second, ally]:
		node.queue_free()
	await process_frame
	print("裂缝击杀目标测试", "失败" if failed else "通过")
	quit(1 if failed else 0)
