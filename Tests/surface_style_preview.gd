extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	if "--game" in OS.get_cmdline_user_args():
		await _preview_game()
		quit()
		return
	var demo: Node = load("res://addons/MapGenerate/demo/demo.tscn").instantiate()
	root.add_child(demo)
	await process_frame
	assert(demo._surface_runtime.applied_surface_count > 0)
	var moisture_before: PackedByteArray = demo.map_outline.moisture.get_image().get_data()
	var mask_before: PackedByteArray = demo._surface_runtime.image.get_data()
	demo.regenerate_surface()
	assert(demo.map_outline.moisture.get_image().get_data() == moisture_before, "视觉调整不能改变资源使用的湿润度")
	assert(demo._surface_runtime.image.get_data() == mask_before, "视觉调整不能改变自然分布的原始 Mask")
	await create_timer(1.0).timeout
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://.godot/surface_style_demo.png") == OK)
	print("地表风格 Demo 渲染完成，湿润度与原始 Mask 保持一致")
	quit()

func _preview_game() -> void:
	var main: Node = load("res://Scene/main.tscn").instantiate()
	main.level_preset = main.level_preset.duplicate(true)
	main.level_preset.layout_seed = 418
	main.level_preset.events.clear()
	main.level_preset.camp_config.enabled = false
	main.level_preset.fog_of_war_enabled = false
	root.add_child(main)
	current_scene = main
	for frame in range(60): await physics_frame
	paused = true
	var camera := root.get_viewport().get_camera_3d()
	camera.set_process(false)
	camera.global_position = Vector3(8, 28, 36)
	camera.look_at(Vector3(0, 3, 0))
	main.get_node("UI").hide()
	for node: Node in main.find_children("*", "CanvasLayer", true, false):
		node.hide()
	await create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://.godot/surface_style_game.png") == OK)
	print("真实游戏树林与地表风格预览已保存")
