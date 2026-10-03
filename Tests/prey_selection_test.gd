extends SceneTree

var main: Node3D
var failed := false

func _init() -> void:
	call_deferred("_run")

func _expect(value: bool, text: String) -> void:
	print("[", "通过" if value else "失败", "] ", text)
	if not value:
		failed = true
		push_error(text)

func _click(position: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = position
	motion.global_position = position
	root.push_input(motion)
	await physics_frame
	await process_frame
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = position
	event.global_position = position
	root.push_input(event)
	await physics_frame
	await process_frame
	event = event.duplicate()
	event.pressed = false
	root.push_input(event)
	for i in range(4): await process_frame

func _run() -> void:
	main = load("res://Scene/main.tscn").instantiate()
	main.level_preset = main.level_preset.duplicate(true)
	main.level_preset.layout_seed = 418
	main.level_preset.events.clear()
	main.level_preset.camp_config.enabled = false
	main.level_preset.wildlife_config.enabled = false
	root.add_child(main)
	current_scene = main
	for i in range(30):
		await physics_frame
		await process_frame
	for unit: Node in get_nodes_in_group("villagers"):
		unit.set_physics_process(false)
	var base: Node3D = get_first_node_in_group("bases")
	var hunter: Node3D = get_nodes_in_group("villagers")[0]
	hunter.assign_job(hunter.Job.HUNTER, null)
	var camera: Camera3D = main.get_viewport().get_camera_3d()
	var fog: Node = get_first_node_in_group("fog_of_war")
	for id: String in ["rabbit", "pheasant", "boar"]:
		var data: PreyData = load("res://data/wildlife/" + id + ".tres")
		var prey: Node3D = data.scene.instantiate()
		prey.data = data
		main.add_child(prey)
		prey.set_physics_process(false)
		prey.global_position = base.global_position + Vector3(6,0,3)
		camera.focus_on_position(prey.global_position)
		for i in range(4): await physics_frame
		fog.refresh_visibility()
		var point: Vector2 = camera.unproject_position(prey.get_node("ClickArea").global_position)
		await _click(point)
		_expect(main.selected_object == prey and main.prey_panel.visible, "实际点击选择猎物并打开面板：" + id)
		_expect(main.prey_panel.title.text == data.display_name and main.prey_panel.details.text.contains("血量：%d / %d" % [data.health, data.health]) and main.prey_panel.details.text.contains("产肉量：%d" % data.meat_yield), "名称、血量和产肉量来自配置：" + id)
		_expect(prey.get_node("Body").material_overlay != null and not main.loot_panel.visible, "猎物选中高亮，其他面板关闭")
		_expect(prey.claim(hunter) and prey.take_damage(1.0, hunter) == 1.0, "猎户攻击猎物")
		for i in range(3): await process_frame
		_expect(main.prey_panel.details.text.contains("血量：%d / %d" % [data.health - 1, data.health]), "受伤后实时更新血量：" + id)
		if id == "boar":
			if DisplayServer.get_name() != "headless":
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("res://.godot/prey_panel_preview.png")
			var original: Vector3 = prey.global_position
			prey.global_position = base.global_position + Vector3(40,0,0)
			fog.refresh_visibility()
			for i in range(2): await process_frame
			_expect(not main.prey_panel.visible and not prey.get_node("ClickArea").input_ray_pickable, "进入迷雾后隐藏面板并禁止点击")
			prey.global_position = original
			fog.refresh_visibility()
			for i in range(2): await physics_frame
			await _click(point)
			_expect(main.prey_panel.visible, "恢复视野后可重新查看")
			await _click(main.prey_panel.close_button.get_global_rect().get_center())
			_expect(not main.prey_panel.visible and main.selected_object == null, "关闭按钮取消选择")
			prey.take_damage(100.0, hunter)
			for i in range(2): await physics_frame
			point = camera.unproject_position(prey.get_node("ClickArea").global_position)
			await _click(point)
			_expect(main.prey_panel.visible and main.prey_panel.details.text.contains("血量：0 / 3"), "倒下的猎物仍能点击查看产肉量")
		prey.queue_free()
		for i in range(3): await process_frame
		_expect(not main.prey_panel.visible and main.selected_object == null, "猎物被拾取或清理后关闭面板：" + id)
	main.queue_free()
	await process_frame
	print("猎物选择与信息面板测试", "失败" if failed else "通过")
	quit(1 if failed else 0)
