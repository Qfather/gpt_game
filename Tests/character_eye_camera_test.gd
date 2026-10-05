extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _press_t(_camera: GameCameraController) -> void:
	var key := InputEventKey.new()
	key.keycode = KEY_T
	key.pressed = true
	root.push_input(key)


func _run() -> void:
	var main: Node = load("res://Scene/main.tscn").instantiate()
	main.level_preset = main.level_preset.duplicate(true)
	main.level_preset.events.clear()
	main.get_node("Systems/MapGenerateRuntime").settlement_seed = 42
	root.add_child(main)
	current_scene = main
	for frame: int in range(10):
		await process_frame
	var camera: GameCameraController = main.get_node("Systems/Camera3D")
	var motion := InputEventMouseMotion.new()
	camera.middle_button_held = true
	motion.relative = Vector2(20, 200)
	camera._unhandled_input(motion)
	assert(is_equal_approx(camera.orbit_pitch, 0.8))
	motion.relative = Vector2(-20, -200)
	camera._unhandled_input(motion)
	assert(is_equal_approx(camera.orbit_pitch, 0.4))
	camera.orbit_pitch = 0.738
	camera.middle_button_held = false
	main.selected_object = get_first_node_in_group("bases")
	_press_t(camera)
	assert(camera.character_camera == null)
	var villager: UnitBase = get_first_node_in_group("villagers") as UnitBase
	villager.set_physics_process(false)
	main.selected_object = villager
	var saved_focus: Vector3 = camera.focus_target
	var saved_yaw: float = camera.orbit_yaw
	var saved_distance: float = camera.orbit_distance
	_press_t(camera)
	assert(root.get_camera_3d() == camera.character_camera)
	assert(camera.character_camera.get_parent().name == "EyeViewpoint")
	var left_eye: Node3D = villager.find_child("LeftEye", true, false)
	var right_eye: Node3D = villager.find_child("RightEye", true, false)
	assert(camera.character_camera.global_position.distance_to((left_eye.global_position + right_eye.global_position) * 0.5) < 0.04)
	var before: Vector3 = camera.character_camera.global_position
	villager.position.x += 1.0
	assert(camera.character_camera.global_position.is_equal_approx(before + Vector3.RIGHT))
	villager.rotation.y = 0.5
	assert((-camera.character_camera.global_basis.z).is_equal_approx((villager.get_node("VisualRoot") as Node3D).global_basis.z))
	root.push_input(motion)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = Vector2(600, 400)
	root.push_input(click)
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	root.push_input(wheel)
	camera._process(0.1)
	assert(main.selected_object == villager)
	assert(camera.focus_target == saved_focus)
	assert(is_equal_approx(camera.orbit_yaw, saved_yaw))
	assert(is_equal_approx(camera.orbit_pitch, 0.738))
	assert(is_equal_approx(camera.orbit_distance, saved_distance))
	if DisplayServer.get_name() != "headless":
		for frame: int in range(5): await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/character-eye-view.png")
	paused = true
	_press_t(camera)
	assert(root.get_camera_3d() == camera)
	assert(camera.focus_target == saved_focus)
	paused = false
	await process_frame
	# 显式头部视点优先使用，位置、朝向完全继承，后续可放到 BoneAttachment3D 下。
	var head := Node3D.new()
	head.name = "TestHead"
	villager.add_child(head)
	var viewpoint := Marker3D.new()
	viewpoint.name = "EyeViewpoint"
	head.add_child(viewpoint)
	viewpoint.position = Vector3(0, 1.4, 0.25)
	_press_t(camera)
	assert(camera.character_camera.get_parent() == viewpoint)
	head.rotation = Vector3(0.2, 0.3, 0)
	assert(camera.character_camera.global_transform.is_equal_approx(viewpoint.global_transform))
	villager.queue_free()
	await process_frame
	await process_frame
	assert(root.get_camera_3d() == camera)
	assert(camera.character_camera == null)
	print("角色眼睛视角：T 切换、眼位、移动转向跟随、输入冻结、暂停返回、头部挂点、删除返回，以及俯视角 0.4–0.8 验证通过")
	main.queue_free()
	await process_frame
	quit()
