extends SceneTree

var failed: bool = false

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var main: Node3D = load("res://Scene/main.tscn").instantiate()
	main.level_preset = main.level_preset.duplicate(true)
	main.level_preset.layout_seed = 418
	main.level_preset.events.clear()
	main.level_preset.camp_config.first_spawn_time = 86400
	root.add_child(main)
	current_scene = main
	for index: int in range(20):
		await physics_frame
		await process_frame
	var base: Node3D = get_first_node_in_group("bases") as Node3D
	var camp: SwordsmanCamp = load("res://Scene/building/game/swordsman_camp.tscn").instantiate()
	camp.building_data = load("res://data/buildings/SwordsmanCampData.tres").duplicate(true)
	camp.building_data = camp.building_data.duplicate(true)
	camp.building_data.training_recipes[0].time_seconds = 2.0
	main.add_child(camp)
	camp.global_position = base.global_position + Vector3(5, 0, 0)
	var manager: TaskManager = get_first_node_in_group("task_manager") as TaskManager
	_expect(camp.request_training(), "真实剑士营能发出训练任务")
	var worker: Node = await _wait_training(camp)
	if worker != null:
		_expect(not worker.visible and worker.collision_layer == 0 and worker.collision_mask == 0, "到达训练位后隐藏角色并停用实体碰撞")
		await create_timer(0.5).timeout
		_expect(not worker.visible and worker.get_training_progress() > 0.0 and not worker.has_combat_role(), "隐藏期间训练继续，完成前不变为剑士")
		if DisplayServer.get_name() != "headless":
			var camera: Camera3D = main.get_viewport().get_camera_3d()
			camera.set_process(false)
			camera.global_position = camp.global_position + Vector3(3, 5, 6)
			camera.look_at(camp.global_position + Vector3.UP * 0.5)
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://.godot/training_hidden_preview.png")
		for index: int in range(240):
			await physics_frame
			if worker.has_combat_role():
				break
		_expect(worker.get_combat_role() == CombatRole.Type.SWORDSMAN and worker.visible, "完成训练后剑士恢复显示")
		# 身份转换后还需走完出门动画；位置以建筑当前入口为准。
		for index: int in range(120):
			if not worker.passing_door: break
			await physics_frame
		_expect(worker.collision_layer == 2 and worker.collision_mask == 3 and worker.global_position.distance_to(camp.get_entrance_position()) < 0.6, "训练成功后在营地入口恢复实体碰撞")
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://.godot/training_completed_preview.png")
	for demolition: bool in [false, true]:
		_expect(camp.request_training(), "再次请求训练")
		worker = await _wait_training(camp)
		if worker == null:
			continue
		if demolition:
			_expect(camp.demolish(), "拆除训练建筑")
		else:
			manager.cancel_task(worker.current_task)
		_expect(worker.visible and worker.collision_layer == 2 and worker.collision_mask == 3, "取消训练或拆除建筑后居民不会保持隐藏")
		_expect(not worker.has_combat_role(), "中断训练不会提前获得剑士身份")
	main.queue_free()
	await process_frame
	print("训练角色显隐测试", "失败" if failed else "通过")
	quit(1 if failed else 0)

func _wait_training(camp: SwordsmanCamp) -> Node:
	for index: int in range(600):
		await physics_frame
		for worker: Node in camp.training_workers:
			if worker.state == worker.State.TRAINING:
				return worker
	_expect(false, "居民在限定时间内实际走到训练位")
	return null

func _expect(condition: bool, message: String) -> void:
	print("[", "通过" if condition else "失败", "] ", message)
	if not condition:
		failed = true
		push_error("失败：" + message)
