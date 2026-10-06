extends SceneTree

var failed: bool = false

func _init() -> void:
	call_deferred("_run")

func _expect(value: bool, message: String) -> void:
	print("[通过] " if value else "[失败] ", message)
	failed = failed or not value

func _run() -> void:
	var main: Node = load("res://Scene/main.tscn").instantiate()
	main.get_node("Systems/MapGenerateRuntime").settlement_seed = 42
	root.add_child(main)
	current_scene = main
	var base: Node3D = get_first_node_in_group("bases")
	if DisplayServer.get_name() != "headless":
		var camera: GameCameraController = main.get_node("Systems/Camera3D")
		camera.orbit_yaw = 0.0
		camera.orbit_distance = 9.0
		camera.focus_on_position(base.global_position)
	var residents: Array[Node] = get_nodes_in_group("villagers")
	_expect(residents.size() == main.level_config.initial_villagers, "开局居民人数保持关卡配置")
	for resident: Node3D in residents:
		_expect(resident.global_position.is_equal_approx(base.get_migrant_interior_position()), "开局居民从据点室内生成")
		_expect(resident.leaving_immigration_base and not resident.is_idle(), "出门期间不领取工作任务")
	var interior: Vector3 = base.get_migrant_interior_position()
	var entrance: Vector3 = base.get_migrant_entrance_position()
	var saw_movement: bool = false
	var captured: bool = false
	for frame: int in range(360):
		await physics_frame
		if residents[0].leaving_immigration_base and residents[0].global_position.distance_to(interior) > 0.1:
			saw_movement = true
			if not captured and DisplayServer.get_name() != "headless" and residents[0].global_position.distance_to(entrance) < 0.8:
				RenderingServer.force_draw(false)
				root.get_texture().get_image().save_png("res://.godot/initial_villager_leaving.png")
				captured = true
		var all_arrived: bool = true
		for resident: Node in residents:
			if resident.leaving_immigration_base or resident.initial_idle_position_pending: all_arrived = false
		if all_arrived: break
	_expect(saw_movement, "居民实际从室内走向入口")
	for resident: Node3D in residents:
		var offset: Vector3 = resident.navigation_agent.target_position - resident.global_position
		_expect(not resident.leaving_immigration_base and not resident.initial_idle_position_pending and Vector2(offset.x, offset.z).length() <= 0.25 and absf(offset.y) <= 0.8, "居民走出据点并抵达分配的待命点")
		print("[高度] 地面=", base.global_position.y, " 居民脚底=", resident.global_position.y, " 导航偏移=", resident.navigation_agent.path_height_offset)
		_expect(absf(resident.global_position.y - base.global_position.y) < 0.1, "居民脚底贴合据点周围地面")
		_expect(resident.collision_layer == 2 and resident.collision_mask == 3 and resident.is_idle(), "出门后恢复碰撞并可领取工作")
	for first: int in range(residents.size()):
		for second: int in range(first + 1, residents.size()):
			_expect(residents[first].global_position.distance_to(residents[second].global_position) >= 0.8, "开局居民站位分开，没有重叠")
	if DisplayServer.get_name() != "headless":
		RenderingServer.force_draw(false)
		root.get_texture().get_image().save_png("res://.godot/initial_villager_outside.png")
	quit(1 if failed else 0)
