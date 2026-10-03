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
	var unit: UnitBase = get_nodes_in_group("villagers")[0] as UnitBase
	unit.set_process(false)
	unit.set_physics_process(false)
	var data: UnitData = load("res://data/units/ResidentData.tres").duplicate(true)
	data.max_health = 100
	data.health_regen = 2.5
	_expect(ResourceSaver.save(data, "res://.godot/unit_regen_config.tres") == OK, "每秒回血量可保存到角色配置")
	data = ResourceLoader.load("res://.godot/unit_regen_config.tres", "", ResourceLoader.CACHE_MODE_IGNORE) as UnitData
	_expect(data.health_regen == 2.5, "重新读取角色配置保留回血数值")
	unit.set_unit_data(data)
	unit.take_damage(50)
	unit._process(2.0)
	_expect(is_equal_approx(unit.get_health(), 55), "配置每秒 2.5 点，2 游戏秒恢复 5 点")
	data.health_regen = 0
	unit.set_unit_data(data)
	unit._process(10)
	_expect(is_equal_approx(unit.get_health(), 55), "设为 0 时停止回血")
	data.health_regen = 2.5
	unit.set_unit_data(data)
	unit._process(100)
	_expect(unit.get_health() == 100, "回血不超过最大血量")
	unit.take_damage(50)
	var before: float = unit.get_health()
	unit.set_process(true)
	paused = true
	await create_timer(0.2, true).timeout
	_expect(unit.get_health() == before, "暂停时不回血")
	paused = false
	Engine.time_scale = 2
	await create_timer(0.3, true, false, true).timeout
	unit.set_process(false)
	Engine.time_scale = 1
	_expect(unit.get_health() > before + 1.0, "倍速下按游戏时间回血")
	var panel: VillagerPanel = main.get_node("UI/VillagerPanel") as VillagerPanel
	panel.open_unit(unit)
	_expect(panel.health_label.text.contains("每秒回血：2.5"), "角色信息显示实际每秒回血量")
	if "--preview" in OS.get_cmdline_user_args():
		await create_timer(0.3).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/unit_regen_panel.png")
	unit.take_damage(1000)
	unit._process(100)
	_expect(unit.is_dead() and unit.get_health() == 0, "死亡角色不会因回血复活")
	var plain := UnitBase.new()
	plain.base_health_regen = 2
	main.add_child(plain)
	plain.set_process(false)
	plain.take_damage(10)
	plain._process(2)
	_expect(plain.get_health() == 94, "无血量组件的单位沿用同样回血规则")
	main.queue_free()
	await process_frame
	print("角色回血测试", "失败" if failed else "通过")
	quit(1 if failed else 0)

func _expect(value: bool, message: String) -> void:
	print("[", "通过" if value else "失败", "] ", message)
	if not value:
		failed = true
		push_error(message)
