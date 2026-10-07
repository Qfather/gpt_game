extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.position = Vector3(0, 8, 14)
	camera.look_at(Vector3(0, 2, 0))
	camera.current = true
	var light := DirectionalLight3D.new()
	world.add_child(light)
	light.rotation_degrees = Vector3(-50, -20, 0)
	for id: String in ["SwordsmanCamp", "ArcherCamp"]:
		var data: BuildingData = load("res://data/buildings/%sData.tres" % id)
		var camp: SwordsmanCamp = data.building_scene.instantiate()
		world.add_child(camp)
		var units: Array[Node] = []
		for index in range(2):
			var unit: Node3D = load("res://Scene/unit/villager.tscn").instantiate()
			world.add_child(unit)
			unit.set_physics_process(false)
			await process_frame
			unit.task_site = camp
			assert(camp.register_training_worker(unit))
			assert(await unit._pass_building_door(camp, true))
			assert(camp.begin_training(unit))
			units.append(unit)
		var indicator: Node = camp.get_node("OccupancyIndicator")
		indicator._process(0)
		var bars: Array = indicator.role_cards[&"resident"].training_bars
		assert(bars.size() == 2 and bars[0].visible and bars[1].visible)
		assert(bars[0].min_value == 0 and bars[0].max_value == 1 and bars[0].value == 0)
		units[0].process_training(camp.get_training_time() * 0.5)
		units[1].process_training(camp.get_training_time() * 0.25)
		indicator._process(0)
		assert(is_equal_approx(bars[0].value, 0.5) and is_equal_approx(bars[1].value, 0.25))
		assert(indicator.panel.visible)
		print(id, "：居民实际入屋后显示独立训练条，0／0.25／0.5进度同步通过")
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://.godot/training_indicator_%s.png" % id)
		units[0].training_elapsed = camp.get_training_time()
		indicator._process(0)
		assert(bars[0].value == 1.0)
		units[0].state = units[0].State.IDLE
		indicator._process(0)
		assert(bars[0].visible and not bars[1].visible and is_equal_approx(bars[0].value, 0.25))
		units[1].state = units[1].State.IDLE
		indicator._process(0)
		assert(not bars[0].visible and not bars[1].visible and indicator.panel.size.y == 76)
		print(id, "：完成或退出训练后进度条隐藏，布局恢复通过")
		for unit: Node in units: unit.queue_free()
		camp.queue_free()
		await process_frame
	world.queue_free()
	await process_frame
	quit()
