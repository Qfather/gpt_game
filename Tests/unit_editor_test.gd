extends SceneTree
func _init() -> void:
	call_deferred("_schedule")
func _schedule() -> void:
	create_timer(5).timeout.connect(_run)
func _run() -> void:
	var panel: Control = load("res://addons/resource_editor/unit_editor_panel.gd").new()
	var background := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.16, 0.16, 0.16)
	background.add_theme_stylebox_override("panel", style)
	root.add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.add_child(panel)
	await process_frame
	assert(panel.items.size() > 10)
	var resident_index: int = -1
	var sword_index: int = -1
	var enemy_index: int = -1
	for index: int in range(panel.items.size()):
		panel.select_unit(index)
		assert(panel.preview.mesh_count > 0)
		assert(panel.current != panel.items[index])
		if panel.current is UnitData:
			if panel.current.id == &"resident": resident_index = index
			if panel.current.id == &"swordsman": sword_index = index
		else:
			if enemy_index < 0: enemy_index = index
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			panel.preview.viewport.get_texture().get_image().save_png("res://.godot/unit_editor_actual_" + String(panel.current.id) + ".png")
	assert(resident_index >= 0 and sword_index >= 0 and enemy_index >= 0)
	panel.select_unit(resident_index)
	panel.current.move_speed = 99.0
	panel.select_unit(sword_index)
	assert(panel.items[resident_index].move_speed == 3.0)
	var copy: Resource = panel.items[sword_index].duplicate(true)
	assert(ResourceSaver.save(copy, "res://.godot/unit_editor_swordsman.tres") == OK)
	panel.items.append(load("res://.godot/unit_editor_swordsman.tres"))
	panel.select_unit(panel.items.size() - 1)
	panel.current.display_name = "配置剑士"
	panel.current.max_health = 175.0
	panel.current.move_speed = 4.4
	panel.current.damage = 17.0
	panel.current.attack_range = 2.2
	panel.current.attack_interval = 0.8
	panel.current.detection_range = 13.0
	panel.current.carry_capacity = 8.0
	panel.current.hunger_rate = 0.25
	var model_root := Node3D.new()
	model_root.name = "单位测试模型"
	var mesh := MeshInstance3D.new()
	mesh.name = "模型"
	mesh.mesh = BoxMesh.new()
	var material := StandardMaterial3D.new()
	material.albedo_color = Color.BLUE
	mesh.material_override = material
	model_root.add_child(mesh)
	mesh.owner = model_root
	var packed := PackedScene.new()
	assert(packed.pack(model_root) == OK)
	assert(ResourceSaver.save(packed, "res://.godot/unit_editor_model.tscn") == OK)
	model_root.free()
	panel.current.visual_scene = load("res://.godot/unit_editor_model.tscn")
	panel.current.visual_tint = Color.WHITE
	panel.current.attack_interval = 0.0
	assert(not panel.save_current())
	panel.current.attack_interval = 0.8
	assert(panel.save_current())
	var saved: UnitData = ResourceLoader.load(panel.data_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP)
	assert(saved.max_health == 175.0 and saved.damage == 17.0 and saved.carry_capacity == 8.0)
	assert(saved.visual_scene.resource_path == "res://.godot/unit_editor_model.tscn")
	assert(panel.items[sword_index].damage == 10.0)
	copy = panel.items[enemy_index].duplicate(true)
	copy.visual_scene = panel.items[enemy_index].visual_scene
	assert(ResourceSaver.save(copy, "res://.godot/unit_editor_enemy.tres") == OK)
	panel.items.append(load("res://.godot/unit_editor_enemy.tres"))
	panel.select_unit(panel.items.size() - 1)
	panel.current.move_speed = 0.0
	panel.current.attack_interval = 0.0
	panel.current.max_health = 75.0
	panel.current.damage = 7.0
	assert(panel.save_current())
	assert(ResourceLoader.load(panel.data_path, "", ResourceLoader.CACHE_MODE_IGNORE).max_health == 75.0)
	assert(panel.items[enemy_index].max_health != 75.0)
	panel.select_unit(sword_index)
	panel.unit_list.select(sword_index)
	if DisplayServer.get_name() != "headless":
		root.size = Vector2i(1440, 900)
		await process_frame
		await RenderingServer.frame_post_draw
		assert(root.get_texture().get_image().save_png("res://.godot/unit_editor_preview.png") == OK)
	print("单位编辑器测试通过：", panel.items.size() - 2, "份配置、模型预览、隔离编辑、保存读回、非法间隔拒绝")
	background.queue_free()
	await process_frame
	quit()
