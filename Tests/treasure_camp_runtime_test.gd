extends SceneTree

var failed: bool = false

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var main: Node3D = load("res://Scene/main.tscn").instantiate()
	main.level_preset = main.level_preset.duplicate(true)
	main.level_preset.events.clear()
	main.level_preset.layout_seed = 418
	main.level_preset.camp_config.first_spawn_time = 86400
	root.add_child(main)
	current_scene = main
	for index: int in range(20):
		await physics_frame
		await process_frame
	var manager: CampSpawnManager = get_first_node_in_group("camp_spawn_manager") as CampSpawnManager
	manager.set_process(false)
	manager.rng.seed = 1234
	var fog: Node = get_first_node_in_group("fog_of_war")
	var base: Node3D = get_first_node_in_group("bases") as Node3D
	var camp: TreasureCamp = manager.try_spawn(0.0)
	_expect(camp != null, "真实生成地图上能找到无视野且可达的营地位置")
	if camp == null:
		main.queue_free()
		await process_frame
		quit(1)
		return
	_expect(not fog.is_area_visible(camp.global_position, camp.footprint_radius), "整片营地在当前视野外")
	_expect(not camp.get_node("ClickArea").input_ray_pickable, "未发现营地不可点击")
	_expect(camp.pickup_task == null and not camp.is_in_group("loot_bundles"), "清剿前不产生搬运任务或计入战利品")
	manager.config.maximum_camps = 1
	_expect(manager.try_spawn(600.0) == null, "达到营地上限时不再生成")
	manager.config.maximum_camps = 2
	var visible_backup: Image = fog.visibility_map.duplicate()
	fog.visibility_map.fill(Color.WHITE)
	_expect(manager.try_spawn(600.0) == null, "地图全部可见时跳过生成")
	fog.visibility_map.copy_from(visible_backup)
	var frozen: Dictionary = camp.resources.duplicate()
	manager.config.camp_pool[0].camp.reward_pool[0].maximum_amount = 999
	main.get_node("Systems/EncounterDirector").elapsed_time = 9999.0
	_expect(camp.resources == frozen and camp.display_name == "史莱姆宝箱营地", "时间与模板修改不会改变已经生成的营地")
	var ordinary: Node3D = main.get_node("Villagers").get_child(0)
	var fighter: Node3D = main.get_node("Villagers").get_child(1)
	await _wait_idle_ready(fighter)
	_expect(not camp.add_participant(ordinary), "普通居民不能接受清剿任务")
	fighter.set_combat_role(99)
	_expect(camp.add_participant(fighter), "清剿接口接受非剑士战斗角色")
	_expect(not camp.add_participant(fighter), "同一单位不能重复分配")
	var initial_position: Vector3 = fighter.global_position
	for index: int in range(40):
		await physics_frame
	_expect(fighter.global_position.distance_to(initial_position) > 0.5, "分配后单位沿导航向营地移动")
	camp.remove_participant(fighter)
	_expect(fighter.treasure_camp == null and camp.participants.is_empty(), "撤回释放寻宝归属")
	await _wait_idle_ready(fighter)
	fighter.set_combat_role(CombatRole.Type.SWORDSMAN)
	var barracks := Barracks.new()
	main.add_child(barracks)
	barracks.set_process(false)
	barracks.global_position = base.global_position + Vector3(4, 0, 0)
	fighter.enter_garrison(barracks)
	_expect(camp.add_participant(fighter) and fighter.visible and fighter.garrisoned_in == null, "驻军可以离营接受寻宝任务")
	camp.remove_participant(fighter)
	_expect(fighter.garrison_target == barracks and fighter.state == fighter.State.MOVE_TO_BARRACKS and fighter.collision_mask != 0, "撤回驻军后自动返回原军营且恢复行走碰撞")
	barracks.unregister_garrison(fighter)
	fighter.garrison_target = null
	fighter.patrol_barracks = barracks
	fighter.state = fighter.State.PATROLLING
	fighter.navigation_agent.target_position = base.global_position
	_expect(camp.add_participant(fighter), "巡逻单位可以接受寻宝任务")
	camp.remove_participant(fighter)
	_expect(fighter.state == fighter.State.MOVE_TO_PATROL_POINT and fighter.navigation_agent.target_position == base.global_position, "撤回巡逻单位后恢复原巡逻目标")
	fighter.patrol_barracks = null
	barracks.free()
	fighter.state = fighter.State.IDLE
	fighter.global_position = camp.global_position + Vector3(0, 0, 1.5)
	# 面板撤回／重加先独立验证，避免等待返程时自动战斗提前清空营地。
	fighter.base_attack_damage = 0.0
	_expect(camp.add_participant(fighter), "可再次分配清剿")
	for guard: EnemyBase in camp.guards:
		guard.damage = 0.0
	fog.refresh_visibility()
	_expect(not bool(camp.get_meta("fog_hidden")) and camp.get_node("ClickArea").input_ray_pickable, "发现后营地可见且可点击")
	main._on_treasure_camp_clicked(camp)
	_expect(main.camp_panel.visible and main.selected_object == camp, "发现后点击营地打开整体面板")
	_expect(main.camp_panel.get_global_rect().intersects(root.get_visible_rect()), "营地面板位于可见屏幕内")
	var withdraw: Button = main.camp_panel.participants_box.get_child(0).get_child(1)
	withdraw.pressed.emit()
	_expect(not camp.participants.has(fighter), "面板撤回按钮实际解除任务")
	await _wait_idle_ready(fighter)
	main.camp_panel.refresh()
	main.camp_panel.add_button.pressed.emit()
	_expect(camp.participants.has(fighter), "面板添加按钮实际分配战斗单位")
	# 清剿仍从原营地附近开始，伤害通过真实单位配置设置。
	fighter.global_position = camp.global_position + Vector3(0, 0, 1.5)
	var fighter_data: UnitData = fighter.unit_data.duplicate(true)
	fighter_data.damage = 100.0
	fighter.set_unit_data(fighter_data)
	_expect(is_equal_approx(fighter.get_attack_damage(), 100.0), "测试伤害通过单位配置实际生效")
	fighter.combat_attack_interval = 0.1
	fighter.combat_detection_range = 20.0
	if "--preview" in OS.get_cmdline_user_args():
		fighter.set_physics_process(false)
		for guard: EnemyBase in camp.guards:
			guard.set_physics_process(false)
		get_viewport_camera(main).focus_on_position(camp.global_position)
		await create_timer(0.2).timeout
		main._on_treasure_camp_clicked(camp)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/camp_runtime_preview.png")
		fighter.set_physics_process(true)
		for guard: EnemyBase in camp.guards:
			guard.set_physics_process(true)
	for index: int in range(600):
		if camp.cleared:
			break
		await physics_frame
		await process_frame
	_expect(camp.cleared, "战斗单位自动击败营地全部守卫")
	_expect(fighter.treasure_camp == null, "清剿完成后释放战斗单位")
	_expect(camp.pickup_task != null, "清剿完成自动发布搬运任务")
	var initial_wood: float = base.storage.get_amount(&"wood")
	var initial_stone: float = base.storage.get_amount(&"stone")
	ordinary.base_move_speed = 30.0
	for unit: Node in get_nodes_in_group("villagers"):
		if not unit.has_combat_role():
			unit.base_move_speed = 30.0
	for index: int in range(3600):
		if base.storage.get_amount(&"wood") >= initial_wood + float(frozen.get(&"wood", 0.0)) and base.storage.get_amount(&"stone") >= initial_stone + float(frozen.get(&"stone", 0.0)):
			break
		await physics_frame
	_expect(base.storage.get_amount(&"wood") >= initial_wood + float(frozen.get(&"wood", 0.0)) and base.storage.get_amount(&"stone") >= initial_stone + float(frozen.get(&"stone", 0.0)), "居民分批将全部物资实际运回据点")
	_expect(not is_instance_valid(camp), "搬空后营地释放")
	manager.next_spawn_time = -1.0
	manager.config.first_spawn_time = 0.0
	manager._process(0.0)
	var replenished: Array[Node] = get_nodes_in_group("treasure_camps")
	_expect(replenished.size() == 1 and replenished[0].display_name == "狼群物资营地", "搬空后计时刷新按后期时间池补充新营地")
	main.queue_free()
	await process_frame
	print("营地运行链路测试", "失败" if failed else "通过")
	quit(1 if failed else 0)

func _wait_idle_ready(unit: Node) -> void:
	# 等实际出门及站位完成，不让旧出门回调覆盖后续驻军／寻宝状态。
	for frame: int in range(900):
		if unit.is_idle() and not unit.passing_door: return
		await physics_frame
		await process_frame
	_expect(false, "士兵在限定时间内实际完成出门和待命站位")

func _expect(condition: bool, message: String) -> void:
	print("[", "通过" if condition else "失败", "] ", message)
	if not condition:
		failed = true
		push_error("失败：" + message)

func get_viewport_camera(main: Node) -> Camera3D:
	return main.get_viewport().get_camera_3d()
