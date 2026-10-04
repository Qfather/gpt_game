extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var panel: EnemyPanel = load("res://Scene/ui/enemy_panel.tscn").instantiate()
	root.add_child(panel)
	var enemy_label: Label = panel.get_node_or_null("%EnemyHealthLabel")
	if enemy_label == null or enemy_label == panel.building_health_label:
		push_error("敌人血量标签必须与继承的建筑血量标签分开")
		quit(1)
		return
	assert(panel.get_node("%HealthLabel") == panel.building_health_label)
	assert(enemy_label.unique_name_in_owner and panel.building_health_label.unique_name_in_owner)
	var enemy: EnemyBase = load("res://Scene/unit/enemy_base.tscn").instantiate()
	root.add_child(enemy)
	enemy.set_process(false)
	enemy.set_physics_process(false)
	enemy.current_health = 81.0
	enemy.max_health = 100.0
	panel.current_building = enemy
	panel.refresh()
	assert(panel.health_label == enemy_label and enemy_label.text == "生命：81 / 100")
	assert(enemy_label.visible and not panel.building_health_label.visible)
	var building_panel: BuildingPanelBase = load("res://Scene/ui/resource_building_panel.tscn").instantiate()
	root.add_child(building_panel)
	assert(building_panel.get_node("%HealthLabel") == building_panel.building_health_label)
	building_panel.queue_free()
	panel.queue_free()
	enemy.queue_free()
	await process_frame
	print("血量标签场景验证通过：唯一名称不冲突，敌人血量刷新，建筑面板引用保留")
	quit()
