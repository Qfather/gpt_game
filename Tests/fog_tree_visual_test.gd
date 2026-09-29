extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var scene: Node = load("res://Scene/main.tscn").instantiate()
	scene.level_preset = scene.level_preset.duplicate(true)
	scene.level_preset.fog_of_war_enabled = true
	scene.get_node("Systems/MapGenerateRuntime").settlement_seed = 42
	root.add_child(scene)
	current_scene = scene
	for frame: int in range(40):
		await process_frame
	var fog: Node = scene.get_node("FogOfWar")
	var camera: GameCameraController = root.get_camera_3d() as GameCameraController
	camera.orbit_distance = 12.0
	camera.focus_on_position(get_first_node_in_group("bases").global_position + Vector3(8, 0, 3))
	var started: int = Time.get_ticks_usec()
	for index: int in range(5):
		fog.refresh_visibility()
	print("真实树林迷雾刷新：树木数=", get_nodes_in_group("resources").size(), " 平均毫秒=", float(Time.get_ticks_usec() - started) / 5000.0)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/fog_tree_preview.png")
	scene.queue_free()
	await process_frame
	quit()
