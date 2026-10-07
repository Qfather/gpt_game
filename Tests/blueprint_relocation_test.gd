extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world
	var region := NavigationRegion3D.new()
	var mesh := NavigationMesh.new()
	mesh.vertices = PackedVector3Array([Vector3(-20, 0, -20), Vector3(-20, 0, 20), Vector3(20, 0, 20), Vector3(20, 0, -20)])
	mesh.add_polygon(PackedInt32Array([0, 1, 2, 3]))
	region.navigation_mesh = mesh
	world.add_child(region)
	for frame in range(5): await physics_frame
	var grid := BuildGrid.new()
	grid.name = "BuildGrid"
	world.add_child(grid)
	var data: BuildingData = load("res://data/buildings/HouseData.tres")
	var site := ConstructionSite.new()
	site.setup(data, Vector2i.ZERO, 0, false)
	site.set_activation_deferred_until_unpause(true)
	world.add_child(site)
	site.set_process(false)
	grid.occupy_area(Vector2i.ZERO, data.grid_size)
	var carrier: Node3D = load("res://Scene/unit/villager.tscn").instantiate()
	world.add_child(carrier)
	carrier.set_physics_process(false)
	await process_frame
	carrier.task_site = site
	carrier.state = carrier.State.MOVE_TO_TASK_SITE
	carrier._set_task_site_navigation_target()
	var old_target: Vector3 = carrier.navigation_agent.target_position
	assert(site.can_be_moved())
	assert(site.relocate(grid, Vector2i(5, 5), 1, true, Transform3D(Basis.IDENTITY, Vector3(6, 0, 6))))
	assert(site.grid_position == Vector2i(5, 5) and site.rotation_step == 1 and site.mirrored)
	assert(not grid.occupied_cells.has(Vector2i.ZERO) and grid.occupied_cells.has(Vector2i(5, 5)))
	assert(carrier.navigation_agent.target_position.distance_to(old_target) > 4.0, "搬运工导航目标随蓝图更新")
	print("蓝图搬迁更新位置、旋转、镜像与网格通过")
	site.state = ConstructionSite.State.READY_TO_BUILD
	var worker := Node.new()
	world.add_child(worker)
	assert(site.add_builder(worker))
	assert(not site.can_be_moved())
	site.remove_builder(worker)
	assert(site.state == ConstructionSite.State.READY_TO_BUILD and not site.can_be_moved(), "开工后即使工人离开且进度尚为零也不能搬迁")
	assert(not site.relocate(grid, Vector2i.ZERO, 0, false, Transform3D.IDENTITY))
	var completed: BuildingBase = data.building_scene.instantiate()
	completed.set_building_data(data)
	world.add_child(completed)
	assert(completed.can_be_moved(), "建成后的住宅恢复现有搬迁功能")
	print("开工后搬迁锁定通过")
	var torch: BuildingData = load("res://data/buildings/TorchData.tres")
	var torch_site := ConstructionSite.new()
	torch_site.setup(torch, Vector2i(-5, -5), 0, false)
	torch_site.set_activation_deferred_until_unpause(true)
	world.add_child(torch_site)
	assert(torch_site.get_node_or_null("EntranceArrow") == null)
	var ghost := BuildingGhost.new()
	ghost.building_data = torch
	world.add_child(ghost)
	assert(not ghost.entrance_arrow.visible and not torch.allow_rotation)
	print("火把预览与工地不显示朝向箭头通过")
	world.queue_free()
	await process_frame
	quit()
