extends SceneTree
var failed: bool = false
func _initialize() -> void: call_deferred("_run")
func _expect(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		push_error(message)
func _run() -> void:
	var main: Node = load("res://Scene/main.tscn").instantiate()
	main.level_preset = main.level_preset.duplicate(true)
	main.level_preset.layout_seed = 418
	main.level_preset.events.clear()
	main.level_preset.camp_config.enabled = false
	root.add_child(main)
	current_scene = main
	for frame: int in range(30): await physics_frame
	main.get_node("Systems/PopulationManager").set_process(false)
	var base: Node3D = get_first_node_in_group("bases")
	var camp: ResourceBuildingBase = load("res://Scene/building/game/lumber_camp.tscn").instantiate()
	main.add_child(camp)
	camp.global_position = base.global_position + Vector3(7, 0, 3)
	camp.max_workers = 3
	camp.set_process(false)
	main.register_building(camp)
	var units: Array[Node] = []
	var points: Array[Vector3] = []
	for index: int in range(3):
		var unit: Node = load("res://Scene/unit/villager.tscn").instantiate()
		main.add_child(unit)
		unit.global_position = base.global_position + Vector3(index + 1, 0, 4)
		unit.set_physics_process(false)
		_expect(camp.add_worker(unit), "准备三名工人失败")
		units.append(unit)
		points.append(unit.global_position)
	var panel: ResourceBuildingPanel = main.get_node("UI/ResourceBuildingPanel")
	camp.building_clicked.emit(camp)
	var camera: GameCameraController = root.get_camera_3d()
	camera.focus_on_position(camp.global_position + Vector3.UP)
	camera.orbit_distance = 12
	for unit: Node in units: unit.set_physics_process(true)
	paused = true
	for frame: int in range(3): await process_frame
	_expect(panel.worker_label.text.contains("3 / 3"), "暂停详情没有显示三名工人")
	for count: int in [2, 1, 0]:
		panel.fire_button.pressed.emit()
		_expect(camp.get_worker_count() == count and panel.worker_label.text.contains("%d / 3" % count), "暂停解雇没有立即更新实际岗位和详情")
	_expect(main.paused_game_commands.is_empty(), "建筑操作仍进入恢复后队列")
	var elapsed: float = main.get_node("Systems/EncounterDirector").elapsed_time
	units[0].set_combat_role(CombatRole.Type.ARCHER)
	for frame: int in range(15): await process_frame
	var hud: GameHUD = main.get_node("UI/HUD")
	_expect(hud.archer_label.text.contains("1"), "暂停HUD没有更新弓箭手身份数量")
	_expect(main.get_node("Systems/EncounterDirector").elapsed_time == elapsed, "暂停时关卡时间推进")
	for index: int in range(3):
		_expect(units[index].global_position == points[index], "暂停解雇后居民移动")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/paused_building_ui.png")
	paused = false
	main.queue_free()
	await process_frame
	print("暂停建筑UI测试", "失败" if failed else "通过", "：三人解雇至零、HUD身份刷新、无排队、时间和位置保持")
	quit(1 if failed else 0)
