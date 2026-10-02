extends SceneTree

var failed: bool = false

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var main: Node3D = load("res://Scene/main.tscn").instantiate()
	main.level_preset = main.level_preset.duplicate(true)
	main.level_preset.layout_seed = 418
	main.level_preset.camp_config.enabled = false
	root.add_child(main)
	current_scene = main
	for index: int in range(20):
		await physics_frame
		await process_frame
	var director: EncounterDirector = get_first_node_in_group("encounter_director") as EncounterDirector
	var rift: RiftManager = get_first_node_in_group("rift_manager") as RiftManager
	var raids: RaidSpawnManager = get_first_node_in_group("raid_spawn_manager") as RaidSpawnManager
	director.set_process(false)
	rift.set_process(false)
	raids.set_process(false)
	for event: LevelEventEntry in main.level_preset.events:
		var group: RaidGroupData = event.get_monster_group()
		director._process(maxf(event.start_time - director.elapsed_time, 0.0))
		_expect(event.triggered, "按时触发：" + event.event_name)
		if group.group_type == RaidGroupData.GroupType.RIFT:
			_expect(rift.rift_active and main.get_node("Enemies").get_child_count() == 0, "裂缝先倒计时再出怪")
			rift._process(event.rift_countdown)
		var waves: int = event.rift_wave_count if group.group_type == RaidGroupData.GroupType.RIFT else 1
		for wave: int in range(waves):
			var enemies: Array[Node] = main.get_node("Enemies").get_children()
			_expect(enemies.size() == group.get_spawn_plan().size(), "实际出生数量：" + event.event_name + " 波" + str(wave + 1))
			for enemy: EnemyBase in enemies:
				enemy.set_process(false)
				enemy.set_physics_process(false)
				_expect(enemy.get_faction() == (EnemyData.Faction.RIFT if group.group_type == RaidGroupData.GroupType.RIFT else EnemyData.Faction.RAID), "出生敌人阵营正确")
				# 本测试验证调度链路；直接清除敌人模拟玩家完成战斗，不作为难度验收。
				enemy.free()
			raids._process(0.0)
			if group.group_type == RaidGroupData.GroupType.RIFT:
				rift._process_wave_interval(0.0)
				if wave + 1 < waves:
					rift._process_wave_interval(event.rift_wave_interval + 0.1)
		if event != main.level_preset.get_final_rift_boss_event():
			_expect(not paused, "非关底事件清除后游戏继续")
	_expect(paused and main.get_node("Systems/GameState").state == GameState.State.VICTORY, "40分钟关底裂缝清除后触发既有胜利流程")
	paused = false
	main.queue_free()
	await process_frame
	print("40分钟困难关卡运行调度测试", "失败" if failed else "通过")
	quit(1 if failed else 0)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		push_error("失败：" + message)
