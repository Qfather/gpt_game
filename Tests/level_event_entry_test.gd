extends SceneTree

const LEVEL_FLOW: LevelFlowData = preload("res://data/levels/LevelFlow_V0.tres")

func _init() -> void:
	var group := RaidGroupData.new()
	group.unit_data.append(preload("res://data/enemies/rift/SlimeData.tres"))
	group.group_type = RaidGroupData.GroupType.RIFT
	group.spawn_mode = RaidGroupData.SpawnMode.FIXED
	group.fixed_unit_counts = PackedInt32Array([7])
	var event := LevelEventEntry.new()
	event.monster_group = group
	event.start_time = 10.0
	event.random_offset = 0.0
	event.prepare(0.0)
	_expect(not event.should_trigger(9.9), "关卡事件时间未到不触发")
	_expect(event.should_trigger(10.0), "关卡事件到时触发")
	event.mark_triggered(10.0)
	_expect(not event.should_trigger(10.1), "单次事件只触发一次")
	_expect(group.get_fixed_plan().size() == 7, "固定模式按单位数量精确生成")
	group.spawn_mode = RaidGroupData.SpawnMode.RANDOM
	group.unit_probabilities = PackedFloat32Array([100.0])
	_expect(group.get_random_plan(7).size() == 7, "随机模式仍按事件配置总数生成")
	group.spawn_mode = RaidGroupData.SpawnMode.FIXED
	event.monster_group = group
	event.rift_wave_count = 2
	_expect(event.rift_wave_count == 2, "裂缝事件支持配置波数")
	_expect(LEVEL_FLOW.events.size() == 9, "统一关卡时间线保留现有关卡事件")
	var raid_count := 0
	var rift_count := 0
	for level_event: LevelEventEntry in LEVEL_FLOW.events:
		var monster_group: RaidGroupData = level_event.get_monster_group()
		if monster_group == null:
			continue
		if monster_group.group_type == RaidGroupData.GroupType.RIFT:
			rift_count += 1
		else:
			raid_count += 1
	_expect(rift_count + raid_count == LEVEL_FLOW.events.size(), "时间线事件均引用有效怪物组")
	var flow := LevelFlowData.new()
	var normal_rift_group := RaidGroupData.new()
	normal_rift_group.group_type = RaidGroupData.GroupType.RIFT
	var early_rift_boss := RaidGroupData.new()
	early_rift_boss.group_type = RaidGroupData.GroupType.RIFT
	early_rift_boss.is_boss_group = true
	var raid_boss := RaidGroupData.new()
	raid_boss.group_type = RaidGroupData.GroupType.RAID
	raid_boss.is_boss_group = true
	var late_rift_boss := RaidGroupData.new()
	late_rift_boss.group_type = RaidGroupData.GroupType.RIFT
	late_rift_boss.is_boss_group = true
	var normal_event := LevelEventEntry.new()
	normal_event.monster_group = normal_rift_group
	normal_event.start_time = 900.0
	var early_boss_event := LevelEventEntry.new()
	early_boss_event.monster_group = early_rift_boss
	early_boss_event.start_time = 1100.0
	early_boss_event.random_offset = 3000.0
	var raid_boss_event := LevelEventEntry.new()
	raid_boss_event.monster_group = raid_boss
	raid_boss_event.start_time = 2000.0
	var late_boss_event := LevelEventEntry.new()
	late_boss_event.monster_group = late_rift_boss
	late_boss_event.start_time = 1200.0
	late_boss_event.random_offset = 600.0
	flow.events = [normal_event, early_boss_event, raid_boss_event, late_boss_event]
	_expect(flow.get_final_rift_boss_event() == late_boss_event, "通关目标按基础出现时间选最后的裂缝BOSS，忽略时间偏移、普通裂缝与袭扰BOSS")
	var raid_unit := EnemyData.new()
	raid_unit.faction = EnemyData.Faction.RAID
	var rift_boss_unit := EnemyData.new()
	rift_boss_unit.faction = EnemyData.Faction.RIFT
	rift_boss_unit.is_boss = true
	var rift_boss_group := RaidGroupData.new()
	rift_boss_group.group_type = RaidGroupData.GroupType.RIFT
	rift_boss_group.is_boss_group = true
	rift_boss_group.unit_data = [raid_unit, rift_boss_unit]
	_expect(rift_boss_group.get_valid_units() == [rift_boss_unit], "裂缝BOSS组只接受裂缝阵营BOSS单位")
	print("LevelEventEntry 测试通过")
	quit()

func _expect(condition: bool, message: String) -> void:
	if not condition:
		push_error("失败：" + message)
		quit(1)
