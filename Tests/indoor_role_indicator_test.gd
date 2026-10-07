extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(640, 360)
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.position = Vector3(0, 7, 12)
	camera.look_at(Vector3(0, 2, 0))
	camera.current = true
	var light := DirectionalLight3D.new()
	world.add_child(light)
	light.rotation_degrees = Vector3(-50, -20, 0)
	var house: BuildingBase = load("res://Scene/building/game/house.tscn").instantiate()
	world.add_child(house)
	var occupants: Array[Node] = []
	for index in range(5):
		var unit: Node3D = load("res://Scene/unit/villager.tscn").instantiate()
		world.add_child(unit)
		unit.set_physics_process(false)
		occupants.append(unit)
	await process_frame
	occupants[1].set_combat_role(CombatRole.Type.SWORDSMAN)
	occupants[2].set_combat_role(CombatRole.Type.ARCHER)
	occupants[3].job = occupants[3].Job.HUNTER
	for unit: Node in occupants:
		unit.indoor_building = house
		unit.hide()
		house.add_indoor_resident(unit)
	occupants[4].state = occupants[4].State.RESTING
	var indicator: Node = house.get_node("OccupancyIndicator")
	indicator._process(0)
	assert(indicator.role_counts == {&"resident": 2, &"swordsman": 1, &"archer": 1, &"hunter": 1})
	assert(indicator.panel.visible and indicator.count_label.text == "×5" and indicator.sleep_label.visible)
	for role: StringName in indicator.ROLE_NAMES:
		assert(indicator.role_cards[role].panel.visible)
	print("同屋居民、剑士、弓箭手、猎人分别显示图标与人数通过")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/indoor_role_indicator_preview.png")
	occupants[1].set_combat_role(CombatRole.Type.ARCHER)
	indicator._process(0)
	assert(not indicator.role_cards[&"swordsman"].panel.visible and indicator.role_counts[&"archer"] == 2)
	occupants[4].state = occupants[4].State.IDLE
	indicator._process(0)
	assert(not indicator.sleep_label.visible)
	house.set_meta("fog_hidden", true)
	indicator._process(0)
	assert(not indicator.panel.visible)
	house.set_meta("fog_hidden", false)
	for unit: Node in occupants:
		house.remove_indoor_resident(unit)
	indicator._process(0)
	assert(not indicator.panel.visible)
	print("身份变化、人数更新、睡觉、迷雾与空屋隐藏通过")
	world.queue_free()
	await process_frame
	quit()
