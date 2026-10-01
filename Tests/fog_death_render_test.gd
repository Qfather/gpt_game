extends SceneTree

var failed: bool = false

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var main: Node3D = load("res://Scene/main.tscn").instantiate()
	main.level_preset = main.level_preset.duplicate(true)
	main.level_preset.layout_seed = 2367371435
	main.level_preset.events.clear()
	main.level_preset.camp_config.first_spawn_time = 86400
	root.add_child(main)
	current_scene = main
	for index: int in range(20):
		await physics_frame
		await process_frame
	var fog: Node = get_first_node_in_group("fog_of_war")
	var base: Node3D = get_first_node_in_group("bases") as Node3D
	var villagers: Array[Node] = get_nodes_in_group("villagers")
	# 使用真实居民死亡流程，反复切换其模型与附近火把的渲染可见性。
	for victim: Node3D in villagers:
		victim.set_physics_process(false)
		# 临时停用测试居民自身提供的视野，以覆盖退出视野的模型显隐。
		victim.remove_from_group("villagers")
		victim.add_to_group("enemies")
		var torch: Node3D = load("res://Scene/building/game/torch.tscn").instantiate()
		main.add_child(torch)
		for index: int in range(8):
			victim.global_position = base.global_position if index % 2 == 0 else Vector3(1000, 0, 1000)
			torch.global_position = victim.global_position
			fog.refresh_visibility()
			if bool(victim.get_meta("fog_hidden")) != (index % 2 == 1):
				failed = true
				push_error("居民模型未按测试视野切换")
			await process_frame
			await RenderingServer.frame_post_draw
		victim.remove_from_group("enemies")
		victim.add_to_group("villagers")
		victim.take_damage(100000.0)
		await create_timer(0.5).timeout
		if is_instance_valid(victim):
			failed = true
			push_error("真实居民死亡后没有释放")
		torch.queue_free()
		await process_frame
		await RenderingServer.frame_post_draw
	print("真实地图迷雾、火把与居民死亡渲染测试", "失败" if failed else "通过", "，居民数量=", villagers.size())
	main.queue_free()
	await process_frame
	quit(1 if failed else 0)
