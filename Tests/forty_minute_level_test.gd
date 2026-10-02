extends SceneTree

var failed: bool = false

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var level: LevelFlowData = load("res://data/levels/LevelFlow_40min_Hard.tres")
	_expect(level.events.size() == 27, "困难关卡包含27个出怪事件")
	var previous_time: float = -1.0
	var ids: Dictionary = {}
	var total: int = 0
	for event: LevelEventEntry in level.events:
		var group: RaidGroupData = event.get_monster_group()
		_expect(group != null and not ids.has(group.id), "事件绑定唯一且有效的怪物组")
		if group == null:
			continue
		ids[group.id] = true
		_expect(event.start_time > previous_time and not event.repeat and event.random_offset == 0.0, "时间线递增且不会无限重复或提前")
		previous_time = event.start_time
		var plan: Array[EnemyData] = group.get_spawn_plan()
		_expect(not plan.is_empty() and plan.size() <= 9, "每波实际可生成且不超过9名敌人")
		for unit: EnemyData in plan:
			_expect(group.is_unit_compatible(unit) and unit.visual_scene != null, "敌人阵营、Boss标记与模型和所属组一致")
		total += plan.size() * (event.rift_wave_count if group.group_type == RaidGroupData.GroupType.RIFT else 1)
	var final_event: LevelEventEntry = level.get_final_rift_boss_event()
	_expect(level.events[0].start_time == 150 and final_event == level.events.back() and final_event.start_time == 2400, "前2分半发展，40分钟才出现关底Boss")
	var mid_event: LevelEventEntry = level.events[12]
	_expect(mid_event.get_monster_group().is_boss_group and mid_event != final_event, "20分钟督军不被当成关底胜利事件")
	for faction: String in ["raid", "rift"]:
		for kind: String in ["Skeleton", "Imp", "Ogre"]:
			var unit: EnemyData = load("res://data/enemies/" + faction + "/" + kind + "Data.tres")
			_expect(unit != null and not unit.id.is_empty() and not unit.is_boss, "三种新增普通敌人配置可读回")
	print("40分钟困难关卡配置测试", "失败" if failed else "通过", "，计划总敌人数=", total)
	quit(1 if failed else 0)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		push_error("失败：" + message)
