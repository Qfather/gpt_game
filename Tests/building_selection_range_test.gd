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
	main.level_preset.fog_of_war_enabled = false
	root.add_child(main)
	current_scene = main
	for i in range(30): await physics_frame
	for unit: Node in get_nodes_in_group("villagers"):
		unit.set_physics_process(false)
	var base: Node3D = get_first_node_in_group("bases")
	var camera: Camera3D = main.get_viewport().get_camera_3d()
	camera.focus_on_position(base.global_position)
	for i in range(4): await physics_frame
	await _click(camera.unproject_position(base.global_position + Vector3.UP * 0.5))
	_expect(main.selected_object == base and main.selected_building_range.visible, "实际点击据点显示待机范围")
	_expect(is_equal_approx(main.selected_building_range.mesh.outer_radius, base.idle_radius), "据点范围使用原有待机半径")
	for id: String in ["lumber_camp", "quarry", "farm", "hunter_hut", "house"]:
		var building: Node3D = load("res://Scene/building/game/" + id + ".tscn").instantiate()
		main.add_child(building)
		main.register_building(building)
		building.global_position = base.global_position + Vector3(6, 0, 3)
		camera.focus_on_position(building.global_position)
		for i in range(4): await physics_frame
		await _click(camera.unproject_position(building.global_position + Vector3.UP * 0.5))
		await create_timer(0.4).timeout
		_expect(main.selected_object == building, "实际点击选择建筑：" + id)
		var ring: MeshInstance3D = main.selected_building_range
		if id == "house":
			_expect(not ring.visible, "没有范围参数的住房不显示虚构范围")
		else:
			var expected_radius: float = building.idle_radius if id == "farm" else building.work_radius
			var center: Vector3 = base.global_position if id == "hunter_hut" else building.global_position
			_expect(ring.visible and is_equal_approx(ring.mesh.outer_radius, expected_radius) and ring.global_position.is_equal_approx(center + Vector3.UP * 0.1), "显示实际范围半径与中心：" + id)
			_expect(ring.mesh.material.albedo_color.b > ring.mesh.material.albedo_color.g if id == "farm" else ring.mesh.material.albedo_color.g > ring.mesh.material.albedo_color.b, "采集绿色、待机蓝色：" + id)
			if id == "lumber_camp":
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("res://.godot/building_range_preview.png")
				paused = true
				await process_frame
				_expect(ring.visible, "暂停时保留选中范围")
				await _click(main.resource_building_panel.close_button.get_global_rect().get_center())
				_expect(not ring.visible and main.selected_object == null, "暂停时关闭面板隐藏范围")
				paused = false
				await _click(camera.unproject_position(building.global_position + Vector3.UP * 0.5))
			building.set_meta("fog_hidden", true)
			for i in range(2): await process_frame
			_expect(not ring.visible, "选中建筑进入迷雾隐藏范围")
			building.set_meta("fog_hidden", false)
			main.clear_selection()
			main._select_world_object(building)
		building.queue_free()
		for i in range(3): await process_frame
		_expect(not ring.visible, "选中建筑被移除后隐藏范围：" + id)
		main.clear_selection()
	main.queue_free()
	await process_frame
	print("建筑选择范围测试", "失败" if failed else "通过")
	quit(1 if failed else 0)
