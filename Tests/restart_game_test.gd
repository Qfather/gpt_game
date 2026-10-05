extends SceneTree

var failed: bool = false

func _init() -> void:
	call_deferred("_run")

func _expect(value: bool, message: String) -> void:
	print("[通过] " if value else "[失败] ", message)
	failed = failed or not value

func _run() -> void:
	var scene: PackedScene = load("res://Scene/main.tscn")
	var first_scene: Node = scene.instantiate()
	root.add_child(first_scene)
	current_scene = first_scene
	for attempt: int in range(3):
		for frame: int in range(30): await physics_frame
		var building: BuildingBase = load("res://Scene/building/game/house.tscn").instantiate()
		building.building_data = load("res://data/buildings/HouseData.tres")
		current_scene.get_node("buildings").add_child(building)
		building.take_damage(20.0)
		var manager: TaskManager = get_first_node_in_group("task_manager")
		var resident: Node = get_first_node_in_group("villagers")
		var repair: GameTask = manager.create_repair_task(building)
		manager.claim_task(repair, resident)
		resident.carried_resource_id = &"wood"
		resident.carried_amount = 2.0
		var old_scene: Node = current_scene
		var hud: GameHUD = current_scene.get_node("UI/HUD")
		hud.show_defeat_screen()
		paused = true
		var restart: Button
		for button: Node in hud.defeat_overlay.find_children("*", "Button", true, false):
			if button.text == "重新开始": restart = button
		_expect(restart != null, "找到重新开始按钮")
		restart.pressed.emit()
		for frame: int in range(30): await physics_frame
		_expect(current_scene != null and current_scene != old_scene and not paused, "第 %d 次重开成功加载新场景并解除暂停" % (attempt + 1))
		_expect(get_nodes_in_group("population_manager").size() == 1 and get_nodes_in_group("resource_manager").size() == 1, "重开后管理器没有重复残留")
	quit(1 if failed else 0)
