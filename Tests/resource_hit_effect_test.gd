extends SceneTree

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	if Engine.is_editor_hint():
		await _editor_test()
		return
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world
	if DisplayServer.get_name() != "headless":
		root.size = Vector2i(800,600)
		var camera := Camera3D.new()
		world.add_child(camera)
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = 8.0
		camera.position = Vector3(5,5,7)
		camera.look_at(Vector3(0,2,0))
		var light := DirectionalLight3D.new()
		world.add_child(light)
		light.rotation_degrees = Vector3(-50,-30,0)
	var attacker := Node3D.new()
	world.add_child(attacker)
	attacker.position = Vector3(-3,0,0)
	var tree: ResourceBase = load("res://Scene/resource/tree.tscn").instantiate()
	world.add_child(tree)
	assert(tree.hit_effect.kind == 1)
	var visual: Node3D = tree.get_node("meshs")
	var rest: Transform3D = visual.transform
	var bounds: AABB = tree.get_build_obstacle_bounds()
	for frame: int in range(15): await process_frame
	for kind: int in [1,2,3]:
		var effect: ResourceHitEffect = tree.hit_effect.duplicate(true)
		effect.kind = kind
		tree.hit_effect = effect
		tree.resource_amount = 100
		assert(tree.gather(1, attacker) == 1)
		await create_timer(effect.hit_time() * 0.6).timeout
		assert(not visual.transform.is_equal_approx(rest), "采集必须触发所选动效")
		assert(tree.get_build_obstacle_bounds() == bounds, "受击期间碰撞占地不能变化")
		assert(visual.position.x >= rest.origin.x, "位移远离左侧攻击者")
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://.godot/resource_hit_mode%d.png" % kind)
		tree.gather(1, attacker)
		await create_timer(effect.hit_time() + effect.return_time() + 0.1).timeout
		assert(visual.transform.is_equal_approx(rest), "连续命中不能累积姿态偏移")
		print("受击类型",kind,"：采集触发、碰撞不变、连续命中归位通过")
		var visible: Array[String] = []
		for property: Dictionary in effect.get_property_list():
			if property.usage & PROPERTY_USAGE_EDITOR: visible.append(property.name)
		assert(visible.has(["", "rotation_angle", "translation_distance", "scale_compression"][kind]))
		assert(not visible.has(["", "translation_distance", "scale_compression", "rotation_angle"][kind]))
	var effect := ResourceHitEffect.new()
	effect.kind = 2
	effect.translation_distance = 0.17
	effect.rotation_angle = 7.0
	assert(ResourceSaver.save(effect,"res://.godot/hit-effect-test.tres") == OK)
	var loaded: ResourceHitEffect = ResourceLoader.load("res://.godot/hit-effect-test.tres","",ResourceLoader.CACHE_MODE_IGNORE)
	assert(is_equal_approx(loaded.translation_distance,0.17) and is_equal_approx(loaded.rotation_angle,7.0))
	loaded.kind = 1
	assert(is_equal_approx(loaded.rotation_angle,7.0), "切换类型保留各自参数")
	world.queue_free()
	await process_frame
	quit()

func _editor_test() -> void:
	var panel = load("res://addons/resource_editor/level_environment_panel.gd").new()
	root.add_child(panel)
	panel.edit_preset(load("res://data/levels/LevelFlow_40min_Hard.tres").duplicate(true))
	panel.resource_list.select(0)
	panel._select_resource(0)
	var config: ResourceHitEffect = panel.preset.map_resources[0].hit_effect
	assert(config != null and panel.hit_preview.mesh_count > 0)
	config.kind = 2
	for frame: int in range(4): await process_frame
	var hit_button: Control = panel.hit_inspector.get_parent().get_child(0)
	assert(panel.hit_inspector.size.y >= 180, "受击属性面板必须分配可见高度")
	assert(panel.hit_inspector.get_global_rect().position.y >= hit_button.get_global_rect().end.y + 7, "预览按钮与属性文本不能重叠")
	panel._preview_hit()
	await create_timer(0.04).timeout
	assert(panel.hit_preview.model.position.x > 0, "编辑器预览复用位移动效")
	panel.hit_animator.reset()
	print("动效保存读回、类型参数隐藏、编辑器预览通过")
	config.translation_distance = 0.21
	assert(ResourceSaver.save(panel.preset,"res://.godot/hit-preset-test.tres") == OK)
	var saved: LevelFlowData = ResourceLoader.load("res://.godot/hit-preset-test.tres","",ResourceLoader.CACHE_MODE_IGNORE)
	assert(is_equal_approx(saved.map_resources[0].hit_effect.translation_distance,0.21))
	panel.queue_free()
	await process_frame
	quit()
