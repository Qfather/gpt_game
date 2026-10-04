extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var data: BuildingData = load("res://data/buildings/LumberCampData.tres")
	if data.grid_size != Vector2i(2,2):
		push_error("伐木场模型为2×2，但占地配置仍为%s" % data.grid_size)
		quit(1)
		return
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world
	var systems := Node3D.new()
	systems.name = "Systems"
	world.add_child(systems)
	var grid := BuildGrid.new()
	grid.name = "BuildGrid"
	systems.add_child(grid)
	for rotation_step: int in range(4):
		var origin := Vector2i(rotation_step * 3,0)
		assert(grid.occupy_area(origin, data.grid_size, rotation_step))
		var site: ConstructionSite = load("res://Scene/building/construction_site.tscn").instantiate()
		site.setup(data, origin, rotation_step, false)
		site.set_activation_deferred_until_unpause(true)
		world.add_child(site)
		var marker: BoxMesh = site.site_mesh.mesh
		var click: BoxShape3D = site.get_node("ClickArea").get_child(0).shape
		assert(marker.size == Vector3(2,0.25,2) and click.size.x == 2 and click.size.z == 2)
		assert(grid.occupied_cells.size() == 4)
		assert(site.build_grid_size == Vector2i(2,2) and grid.get_rotated_size(data.grid_size, rotation_step) == Vector2i(2,2))
		site._complete_construction()
		await process_frame
		var completed: BuildingBase
		for node: Node in get_nodes_in_group("resource_buildings"):
			if node is BuildingBase and node.building_data == data:
				completed = node
		assert(is_instance_valid(completed) and completed.build_grid_size == Vector2i(2,2))
		assert(grid.occupied_cells.size() == 4)
		completed.release_build_grid_area()
		completed.queue_free()
		await process_frame
		assert(grid.occupied_cells.is_empty())
	print("伐木场占位验证通过：四种旋转、工地标记与点击区域、占四格、竣工占位与释放一致")
	world.queue_free()
	await process_frame
	quit()
