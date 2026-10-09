extends SceneTree

func _initialize() -> void: call_deferred("_run")

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
	var house: Node = load("res://Scene/building/game/hunter_hut.tscn").instantiate()
	world.add_child(house)
	house.set_process(false)
	house.processing_min = 10.0
	house.processing_max = 10.0
	house.get_node("ResourceStorage").set_capacity(&"meat", 100.0)
	var hunter: Node = load("res://Scene/unit/villager.tscn").instantiate()
	world.add_child(hunter)
	hunter.set_physics_process(false)
	hunter.job = hunter.Job.HUNTER
	hunter.workplace = house
	hunter.hunting.prey_count = 1
	hunter.hunting.raw_meat = 1.0
	hunter.hunting.request_return(hunter)
	hunter.global_position = house.get_entrance_position()
	hunter.hunting.process(hunter, 0.01)
	while hunter.passing_door: await physics_frame
	assert(hunter.hunting.inside_processing and not hunter.visible)
	var indicator: Node = house.get_node("OccupancyIndicator")
	indicator._process(0)
	var bars: Array = indicator.role_cards[&"hunter"].training_bars
	assert(bars.size() == 1 and bars[0].visible and bars[0].value == 0.0)
	hunter.hunting.process(hunter, 5.0)
	indicator._process(0)
	assert(is_equal_approx(bars[0].value, 0.5))
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/hunter_processing_indicator.png")
	hunter.hunting.process(hunter, 5.0)
	while hunter.passing_door: await physics_frame
	indicator._process(0)
	assert(not bars[0].visible and hunter.hunting.prey_count == 0)
	var deleted: BuildingBase = load("res://Scene/building/game/hunter_hut.tscn").instantiate()
	world.add_child(deleted)
	hunter.indoor_building = deleted
	deleted.free()
	hunter.state = hunter.State.HUNTING
	assert(hunter.get_damage_protector() == null)
	var enemy: EnemyBase = load("res://Scene/unit/enemy_base.tscn").instantiate()
	world.add_child(enemy)
	enemy.set_process(false)
	enemy.set_physics_process(false)
	enemy._set_target(hunter)
	enemy.update_targeting()
	print("猎人真实处理进度0/50%/完成隐藏、已释放室内建筑及敌人目标查询通过")
	world.queue_free()
	await process_frame
	quit()
