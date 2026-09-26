extends SceneTree

var failed: bool = false


func _initialize() -> void:
	call_deferred("_run")


func _expect(value: bool, message: String) -> void:
	if not value:
		failed = true
		push_error("失败：" + message)


func _run() -> void:
	var scene: Node = load("res://Scene/main.tscn").instantiate()
	scene.level_preset = scene.level_preset.duplicate(true)
	scene.level_preset.map_resources.clear()
	root.add_child(scene)
	current_scene = scene
	await process_frame
	await physics_frame
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.make_current()
	root.physics_object_picking = true
	root.size = Vector2i(1280, 720)
	var targets: Array[Node3D] = []
	for path: String in ["res://Scene/unit/villager.tscn", "res://Scene/unit/enemy_base.tscn", "res://Scene/resource/tree.tscn", "res://Scene/building/game/wall.tscn", "res://Scene/building/construction_site.tscn"]:
		var target: Node3D = load(path).instantiate() as Node3D
		if target is ConstructionSite:
			target.setup(load("res://data/buildings/WallData.tres"), Vector2i(100, 100), 0, false)
		scene.add_child(target)
		if target.has_signal("unit_clicked"):
			scene.register_villager(target)
		if target.has_signal("building_clicked"):
			scene.register_building(target)
		target.global_position = Vector3(200 + targets.size() * 10, 0, 0)
		targets.append(target)
	await process_frame
	await physics_frame
	paused = true
	for target: Node3D in targets:
		scene.clear_selection()
		for frame: int in range(20):
			await process_frame
			await physics_frame
		var position_before: Vector3 = target.global_position
		camera.global_position = target.global_position + Vector3(0, 0.8, 6)
		camera.look_at(target.global_position + Vector3(0, 0.8, 0))
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = true
		event.position = camera.unproject_position(target.global_position + Vector3(0, 0.4, 0))
		root.push_input(event, true)
		for frame: int in range(5):
			await process_frame
			await physics_frame
		_expect(scene.selected_object == target, "暂停点击未选中：" + str(target.name))
		_expect(target.global_position == position_before and not target.can_process(), "暂停时世界对象恢复了运行")
		if target is ConstructionSite:
			var panel: ResourceBuildingPanel = scene.resource_building_panel
			(panel.priority_row.get_child(2).get_child(0) as Button).pressed.emit()
			_expect(target.construction_priority == 1, "暂停时工地面板操作无效")
			_expect(is_zero_approx(target.construction_progress), "暂停时施工进度增长")
		event.pressed = false
		root.push_input(event, true)
	paused = false
	camera.queue_free()
	scene.queue_free()
	await process_frame
	print("暂停对象选择测试", "失败" if failed else "通过")
	quit(1 if failed else 0)
