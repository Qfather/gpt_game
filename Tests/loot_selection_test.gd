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
	var manager: Node = get_first_node_in_group("task_manager")
	manager.set_process(false)
	var base: Node3D = get_first_node_in_group("bases")
	var enemy: EnemyBase = load("res://Scene/unit/enemy_base.tscn").instantiate()
	main.add_child(enemy)
	enemy.set_process(false)
	enemy.set_physics_process(false)
	enemy.global_position = base.global_position + Vector3(6,0,3)
	enemy.stolen_resources = {&"wood": 8.0, &"meat": 2.0}
	enemy._drop_stolen_loot()
	enemy.free()
	var bundle: LootBundle = get_first_node_in_group("loot_bundles")
	for i in range(5): await physics_frame
	var camera: Camera3D = main.get_viewport().get_camera_3d()
	camera.focus_on_position(bundle.global_position)
	for i in range(6): await process_frame
	var screen: Vector2 = camera.unproject_position(bundle.global_position + Vector3(0,0.4,0))
	var query := PhysicsRayQueryParameters3D.create(camera.project_ray_origin(screen), camera.project_ray_origin(screen) + camera.project_ray_normal(screen) * 1000.0, 2)
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var hit: Dictionary = main.get_world_3d().direct_space_state.intersect_ray(query)
	_expect(not hit.is_empty() and hit.collider == bundle.get_node("ClickArea"), "掉落包裹的点击区域可被相机射线命中")
	await _click(screen)
	_expect(main.selected_object == bundle and main.loot_panel.visible, "实际鼠标点击选中包裹并显示面板")
	_expect(main.loot_panel.details.text.contains("木材 × 8") and main.loot_panel.details.text.contains("肉类 × 2"), "面板显示全部物资的中文名称和数量")
	_expect(bundle.get_node("Visual").material_overlay != null and not main.enemy_panel.visible, "包裹高亮且其他信息面板关闭")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/loot_panel_preview.png")
	var original_position: Vector3 = bundle.global_position
	var fog: Node = get_first_node_in_group("fog_of_war")
	bundle.global_position = base.global_position + Vector3(40,0,0)
	fog.refresh_visibility()
	for i in range(2): await process_frame
	_expect(bool(bundle.get_meta("fog_hidden", false)) and not bundle.get_node("ClickArea").input_ray_pickable and not main.loot_panel.visible, "迷雾中的包裹不可点击且关闭信息面板")
	bundle.global_position = original_position
	fog.refresh_visibility()
	for i in range(2): await physics_frame
	await _click(screen)
	_expect(main.loot_panel.visible, "恢复视野后可重新选择包裹")
	var worker: Node = get_nodes_in_group("villagers")[0]
	worker.carry_capacity = 3.0
	worker.current_task = null
	worker.carried_amount = 0.0
	_expect(bundle.pick_up(worker), "居民部分回收包裹")
	for i in range(3): await process_frame
	_expect(main.loot_panel.details.text.contains("木材 × 5"), "部分回收后面板更新剩余数量")
	await _click(main.loot_panel.close_button.get_global_rect().get_center())
	_expect(not main.loot_panel.visible and main.selected_object == null, "点击关闭按钮取消选中")
	await _click(screen)
	_expect(main.loot_panel.visible, "关闭后可重新点击打开")
	worker.carried_amount = 0.0
	worker.carry_capacity = 100.0
	bundle.pick_up(worker)
	worker.carried_amount = 0.0
	bundle.pick_up(worker)
	for i in range(4): await process_frame
	_expect(not is_instance_valid(bundle) and not main.loot_panel.visible and main.selected_object == null, "包裹搬空后删除并自动关闭面板")
	main.queue_free()
	await process_frame
	print("战利品选择与UI测试", "失败" if failed else "通过")
	quit(1 if failed else 0)
