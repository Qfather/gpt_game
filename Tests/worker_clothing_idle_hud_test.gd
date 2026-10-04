extends SceneTree

var failed: bool = false

func _init() -> void:
	call_deferred("_run")

func _expect(value: bool, message: String) -> void:
	print("[", "通过" if value else "失败", "] ", message)
	if not value:
		failed = true
		push_error(message)

func _color(unit: Node3D, part: String = "Body") -> Color:
	return unit.visual_instance.get_node(part).get_active_material(0).albedo_color

func _run() -> void:
	var world: Node3D = load("res://Scene/main.tscn").instantiate()
	world.level_preset = world.level_preset.duplicate(true)
	world.level_preset.layout_seed = 418
	world.level_preset.map_config.seed_value = 418
	world.level_preset.fog_of_war_enabled = false
	world.level_preset.events.clear()
	world.level_preset.camp_config.enabled = false
	world.level_preset.settlement_config.initial_villagers = 0
	for entry: MapResourceEntry in world.level_preset.map_resources: entry.count = 0
	root.add_child(world)
	current_scene = world
	await process_frame
	await process_frame
	var base: Node3D = get_first_node_in_group("bases")
	var units: Array[Node3D] = []
	for index: int in range(6):
		var unit: Node3D = load("res://Scene/unit/villager.tscn").instantiate()
		world.add_child(unit)
		unit.position = base.position + Vector3((index - 2) * 2.0, 0, 4)
		unit.set_physics_process(false)
		units.append(unit)
	for i in range(5): await physics_frame
	for unit: Node3D in units: unit.state = unit.State.IDLE
	var default_color: Color = _color(units[0])
	var skin: Color = _color(units[0], "Head")
	var hair: Color = _color(units[0], "Hair")
	var paths: Array[String] = ["lumber_camp", "quarry", "farm", "hunter_hut"]
	var data_paths: Array[String] = ["LumberCampData", "QuarryData", "FarmData", "HunterHutData"]
	var buildings: Array[ResourceBuildingBase] = []
	var clothing_colors: Array[Color] = []
	for index: int in range(4):
		var building: ResourceBuildingBase = load("res://Scene/building/game/%s.tscn" % paths[index]).instantiate()
		building.set_building_data(load("res://data/buildings/%s.tres" % data_paths[index]))
		world.add_child(building)
		building.position = base.position + Vector3(-12, 0, 12 + index * 6)
		building.set_process(false)
		buildings.append(building)
		_expect(building.add_worker(units[index]), "居民进入%s岗位" % data_paths[index])
		var actual: Color = _color(units[index])
		_expect(actual == units[index].JOB_CLOTHING_COLORS[units[index].job] and not clothing_colors.has(actual), "各采集岗位使用不同衣服颜色")
		clothing_colors.append(actual)
		_expect(_color(units[index], "Head") == skin and _color(units[index], "Hair") == hair, "换衣保留肤色与头发")
	_expect(_color(units[4]) == default_color, "换衣不污染其他居民共用材质")
	var hud: GameHUD = world.get_node("UI/HUD")
	hud.set_process(false)
	units[5].set_combat_role(CombatRole.Type.ARCHER)
	units[5].state = units[5].State.IDLE
	_expect(hud._get_idle_resident_count() == 1, "有岗位工人和空闲弓箭手不计入空闲居民")
	var idle: Node3D = units[4]
	for state: int in [idle.State.EATING, idle.State.RESTING, idle.State.RETREAT_TO_BASE, idle.State.MOVE_TO_DEMOLITION]:
		idle.state = state
		_expect(hud._get_idle_resident_count() == 0, "进食、休息、撤退或执行拆除时不算待命")
	idle.state = idle.State.IDLE
	idle.current_task = GameTask.new()
	_expect(hud._get_idle_resident_count() == 0, "已领取任务的居民不算空闲")
	idle.current_task = null
	idle.carried_amount = 1.0
	_expect(hud._get_idle_resident_count() == 0, "有资源尚未交清的居民不算空闲")
	idle.carried_amount = 0.0
	idle.state = idle.State.RETURN_TO_IDLE
	_expect(hud._get_idle_resident_count() == 1, "可接任务的待命移动居民计入空闲")
	hud._refresh_population_display(6, 10)
	await process_frame
	_expect(hud.idle_resident_label.text == "空闲居民：1" and hud.idle_resident_label.global_position.x < hud.population_label.global_position.x and absf(hud.idle_resident_label.global_position.y - hud.population_label.global_position.y) < 1.0, "HUD 在人口左侧同一行显示准确空闲人数")
	if DisplayServer.get_name() != "headless":
		var camera: Camera3D = world.get_node("Systems/Camera3D")
		camera.set_process(false)
		camera.set_physics_process(false)
		camera.global_position = base.global_position + Vector3(0, 8, 14)
		camera.look_at(base.global_position + Vector3(0, 1, 4))
		camera.size = 14
		await create_timer(0.2).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/worker_clothing_idle_hud_preview.png")
	units[0].state = units[0].State.RESTING
	_expect(_color(units[0]) == clothing_colors[0], "有岗位居民休息时保留工作配色")
	buildings[0].remove_worker(units[0])
	_expect(units[0].job == units[0].Job.NONE and _color(units[0]) == default_color, "解雇后恢复普通居民衣服")
	buildings[3].remove_worker(units[3])
	_expect(units[3].is_quitting_job and _color(units[3]) == clothing_colors[3], "猎户返回小屋交接期间保留岗位配色")
	units[3].finish_quit_job()
	_expect(units[3].unit_data == units[3].RESIDENT_DATA and _color(units[3]) == default_color, "猎户离职更换模型后也恢复居民配色")
	units[1].abandon_current_work()
	_expect(units[1].job == units[1].Job.NONE and _color(units[1]) == default_color and not units[1].is_idle_resident(), "放弃工作恢复衣服，返回途中仍按放弃工作规则排除空闲")
	units[0].state = units[0].State.IDLE
	units[3].state = units[3].State.IDLE
	_expect(hud._get_idle_resident_count() == 3, "离岗待命后空闲居民数量更新")
	var military_color: Color = _color(units[5])
	units[5].job = units[5].Job.MINER
	_expect(_color(units[5]) == military_color, "军事单位保持原模型配色")
	world.queue_free()
	await process_frame
	quit(1 if failed else 0)
