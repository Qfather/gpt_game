extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var main: Node3D = load("res://Scene/main.tscn").instantiate()
	main.level_preset = main.level_preset.duplicate(true)
	main.level_preset.events.clear()
	main.level_preset.camp_config.enabled = false
	root.add_child(main)
	current_scene = main
	for index in range(30): await physics_frame
	var ghost: BuildingGhost = main.get_node("Systems/BuildingGhost")
	var grid: BuildGrid = ghost.build_grid
	var fog: Node = get_first_node_in_group("fog_of_war")
	var data: BuildingData = load("res://data/buildings/HouseData.tres")
	var position_found := false
	var candidate := Vector2i.ZERO
	for x in range(grid.grid_min.x, grid.grid_max.x):
		for y in range(grid.grid_min.y, grid.grid_max.y):
			var cell := Vector2i(x,y)
			if not fog.is_visible_at(grid.grid_to_world(cell)) and grid.is_area_free(cell, data.grid_size, 0, false, true):
				candidate = cell
				position_found = true
				break
		if position_found: break
	assert(position_found)
	assert(not grid.is_area_free(candidate, data.grid_size))
	var transform := Transform3D(Basis.IDENTITY, grid.grid_to_world(candidate))
	assert(ghost._create_construction_site(data, candidate, 0, false, transform, false, true))
	assert(get_nodes_in_group("construction_sites").size() == 1)
	assert(not grid.is_area_free(candidate, data.grid_size, 0, false, true))
	var site: ConstructionSite = get_first_node_in_group("construction_sites")
	assert(get_first_node_in_group("task_manager").create_repair_task(site) == null)
	main.queue_free()
	await process_frame
	print("迷雾建造测试通过：真实地图未照亮区域可放住宅、占地约束保留、工地不创建维修任务")
	quit()
