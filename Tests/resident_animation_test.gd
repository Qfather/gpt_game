extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	seed(418)
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world
	var region := NavigationRegion3D.new()
	var navigation := NavigationMesh.new()
	navigation.vertices = PackedVector3Array([Vector3(-10, 0, -10), Vector3(-10, 0, 10), Vector3(10, 0, 10), Vector3(10, 0, -10)])
	navigation.add_polygon(PackedInt32Array([0, 1, 2, 3]))
	region.navigation_mesh = navigation
	world.add_child(region)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.position = Vector3(4, 3, 5)
	camera.look_at(Vector3(0, 0.8, 0))
	var light := DirectionalLight3D.new()
	world.add_child(light)
	light.rotation_degrees = Vector3(-40, -30, 0)
	var worker = load("res://Scene/unit/villager.tscn").instantiate()
	world.add_child(worker)
	worker.set_physics_process(false)
	worker.hunger_rate = 0.0
	worker.fatigue_rate = 0.0
	assert(is_equal_approx(worker.get_move_speed(), 2.0))
	var visual = worker.visual_instance
	var player: AnimationPlayer = visual.get_node("AnimationPlayer")
	for index in range(10): await physics_frame
	var idles: Dictionary = {}
	for index in range(60):
		visual._update_animation(true)
		visual._update_animation(false)
		idles[_animation(visual)] = true
	assert(idles.size() == 3)
	var idle: StringName = _animation(visual)
	for index in range(10): await physics_frame
	assert(_animation(visual) == idle and visual.playback.is_playing())
	worker.navigation_agent.target_position = Vector3(8, 0, 0)
	var start: Vector3 = worker.global_position
	for index in range(30):
		await physics_frame
		worker.move_along_navigation()
	assert(worker.global_position.distance_to(start) > 0.5)
	assert(_animation(visual) == "村民动画/走")
	await _capture("walk", worker)
	worker.carried_amount = 1.0
	worker.carried_resource_id = &"wood"
	for index in range(8):
		await physics_frame
		worker.move_along_navigation()
	assert(_animation(visual) == "村民动画/搬运重物走")
	assert(visual.playback.get_current_node() == &"carry_walk")
	await _capture("carry_walk", worker)
	worker.carried_amount = 0.0
	for index in range(8):
		await physics_frame
		worker.move_along_navigation()
	assert(_animation(visual) == "村民动画/走")
	worker.velocity = Vector3.ZERO
	for index in range(5): await physics_frame
	assert(_animation(visual) in ["村民动画/待机", "村民动画/待机2", "村民动画/待机3"])
	var site := ConstructionSite.new()
	site.building_data = load("res://data/buildings/WoodWallData.tres")
	site.state = ConstructionSite.State.BUILDING
	worker.task_site = site
	worker.state = worker.State.BUILDING
	site.construction_progress = site.get_construction_duration() * 0.699
	for index in range(5): await physics_frame
	assert(_animation(visual) == "村民动画/锤子下蹲建造")
	await _capture("crouch")
	site.construction_progress = site.get_construction_duration() * 0.7
	for index in range(5): await physics_frame
	assert(_animation(visual) in ["村民动画/锤子站立建造", "村民动画/锤子站立建造2"])
	var standings: Dictionary = {}
	for index in range(60):
		visual._update_animation(true)
		visual._update_animation(false)
		standings[_animation(visual)] = true
	assert(standings.size() == 2)
	var standing: StringName = _animation(visual)
	for index in range(30): await physics_frame
	assert(_animation(visual) == standing and visual.playback.is_playing())
	await _capture("standing")
	var builders: Array[Node3D] = []
	var phases: Array[float] = []
	for index in range(3):
		var builder = load("res://Scene/unit/villager.tscn").instantiate()
		world.add_child(builder)
		builder.set_physics_process(false)
		builder.position = worker.position + Vector3((index - 1) * 0.9, 0, 1.5)
		builders.append(builder)
	for index in range(10): await physics_frame
	for builder: Node3D in builders:
		builder.state = builder.State.BUILDING
		builder.task_site = site
		var animation_visual = builder.visual_instance
		animation_visual.previous_position = builder.global_position
		site.construction_progress = site.get_construction_duration() * 0.5
		animation_visual._update_animation(false)
		phases.append(float(animation_visual.animation_tree.get("parameters/crouch/Seek/seek_request")) / player.get_animation("村民动画/锤子下蹲建造").length)
	assert(phases.max() - phases.min() > 0.05)
	print("三人下蹲施工随机起始相位：", phases)
	await _capture("three_builders")
	site.construction_progress = site.get_construction_duration() * 0.8
	for builder: Node3D in builders:
		builder.visual_instance._update_animation(false)
		assert(_animation(builder.visual_instance) in ["村民动画/锤子站立建造", "村民动画/锤子站立建造2"])
		builder.task_site = null
	for index in range(5): await physics_frame
	standing = _animation(visual)
	assert(standing in ["村民动画/锤子站立建造", "村民动画/锤子站立建造2"])
	worker.state = worker.State.BUILD_ROAD
	for index in range(12): await physics_frame
	assert(visual.playback.get_current_node() == &"crouch")
	assert(_animation(visual) == "村民动画/锤子下蹲建造")
	await _capture("road_crouch")
	worker.demolition_target = site
	worker.state = worker.State.DEMOLISHING
	for index in range(12): await physics_frame
	assert(visual.playback.get_current_node() == &"standing")
	standing = _animation(visual)
	await _capture("demolition_standing")
	var position_before_pause: float = visual.playback.get_current_play_position()
	paused = true
	for index in range(10): await process_frame
	assert(is_equal_approx(visual.playback.get_current_play_position(), position_before_pause))
	paused = false
	Engine.time_scale = 3.0
	for index in range(10): await physics_frame
	assert(_animation(visual) == standing and visual.playback.is_playing())
	Engine.time_scale = 1.0
	for animation_name: StringName in ["待机", "待机2", "待机3", "走", "搬运重物走", "锤子下蹲建造", "锤子站立建造", "锤子站立建造2"]:
		assert(player.get_animation("村民动画/" + animation_name).loop_mode == Animation.LOOP_LINEAR)
	var original: AnimationLibrary = load("res://assets/animation/村民动画.glb")
	assert(original.get_animation("走").loop_mode == Animation.LOOP_NONE)
	worker.task_site = null
	worker.demolition_target = null
	site.free()
	world.queue_free()
	await process_frame
	print("[通过] AnimationTree实际状态、基础移速2、导航行走／重物走、随机待机、69.9%／70%、施工随机相位、修路下蹲锤／拆除站立锤、循环、暂停及3倍速；携料与工作阈值为隔离显示验证。")
	quit(0)


func _capture(label: String, moving_worker: Node3D = null) -> void:
	if DisplayServer.get_name() == "headless": return
	for index in range(15):
		await physics_frame
		if moving_worker != null: moving_worker.move_along_navigation()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/animation_check/" + label + ".png")


func _animation(visual: Node3D) -> StringName:
	var node: AnimationRootNode = visual.state_machine.get_node(visual.animation_mode)
	return node.get_node("Animation").animation if node is AnimationNodeBlendTree else node.animation
