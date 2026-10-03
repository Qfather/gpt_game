extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var main = load("res://Scene/main.tscn").instantiate()
	main.level_preset = main.level_preset.duplicate(true)
	main.level_preset.layout_seed = 418
	main.level_preset.events.clear()
	main.level_preset.camp_config.enabled = false
	root.add_child(main)
	current_scene = main
	var animals: Array[Node] = []
	for i in range(180):
		await physics_frame
		await process_frame
		animals = get_nodes_in_group("wildlife")
		if not animals.is_empty(): break
	var houses: Array[Node] = main.find_children("HunterHut", "", true, false)
	assert(houses.is_empty())
	assert(animals.size() == 12)
	var base = get_first_node_in_group("bases")
	for animal: Node3D in animals:
		var distance = Vector2(animal.global_position.x, animal.global_position.z).distance_to(Vector2(base.global_position.x, base.global_position.z))
		assert(distance >= 15.0 and distance <= 35.0)
	var manager = main.get_node("Systems/WildlifeManager")
	manager.refill()
	assert(get_nodes_in_group("wildlife").size() == 12)
	print("猎物开局测试通过：无猎人小屋时已有12只猎物，实际位置距据点15–35米，不超数量上限")
	main.queue_free()
	await process_frame
	quit()
