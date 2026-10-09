extends SceneTree

class TestMap extends MapGenerateRuntime:
	func _ready() -> void: add_to_group("map_generate_runtime")

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world
	var catalog := BuildingCatalog.new()
	world.add_child(catalog)
	var grid := BuildGrid.new()
	grid.name = "BuildGrid"
	var systems := Node3D.new()
	systems.name = "Systems"
	world.add_child(systems)
	systems.add_child(grid)
	var base: Node3D = catalog.buildings[&"base"].building_scene.instantiate()
	base.set_building_data(catalog.buildings[&"base"])
	world.add_child(base)
	base.position = Vector3(-6, 0, 0)
	base.add_resource(&"wood", 50)
	base.add_resource(&"stone", 50)
	var region := NavigationRegion3D.new()
	region.name = "NavigationRegion3D"
	world.add_child(region)
	var runtime := TestMap.new()
	world.add_child(runtime)
	runtime._navigation_faces = PackedVector3Array([Vector3(-15,0,-15),Vector3(15,0,-15),Vector3(-15,0,15),Vector3(15,0,-15),Vector3(15,0,15),Vector3(-15,0,15)])
	var manager := TaskManager.new()
	world.add_child(manager)
	# 两个分支分别真实运料、施工，缩短测试配方时间，不直接调用完工。
	for target_id: StringName in [&"swordsman_camp", &"archer_camp"]:
		var data: BuildingData = catalog.buildings[&"militia_camp"]
		var camp: SwordsmanCamp = data.building_scene.instantiate()
		camp.set_building_data(data)
		world.add_child(camp)
		assert(grid.occupy_area(Vector2i(-1, -1), data.grid_size, 0, false, true))
		camp.set_build_grid_occupancy(Vector2i(-1, -1), data.grid_size, 0)
		assert(not camp.can_upgrade(target_id))
		assert(not camp.request_upgrade(target_id), "无蓝图不能创建升级工地")
		var target: BuildingData = catalog.buildings[target_id].duplicate(true)
		target.upgrade_time = 0.5
		target.upgrade_cost = {&"wood": 2.0, &"stone": 2.0}
		catalog.buildings[target_id] = target
		catalog.offered = [target]
		assert(catalog.choose_blueprint(target_id))
		camp.training_requests = 1
		assert(not camp.can_upgrade(target_id), "排队训练时不能升级")
		camp.training_requests = 0
		assert(camp.request_upgrade(target_id))
		assert(camp.upgrade_site.cancel_construction())
		await process_frame
		assert(not is_instance_valid(camp.upgrade_site) and grid.occupied_cells.size() == 9, "取消未开工升级保留原建筑及占地")
		var old_health: float = camp.get_max_health() * 0.5
		camp.current_health = old_health
		var worker: Node = load("res://Scene/unit/villager.tscn").instantiate()
		world.add_child(worker)
		worker.position = Vector3(0, 0, 5)
		for frame: int in range(5): await physics_frame
		var wood: float = base.get_node("ResourceStorage").get_amount(&"wood")
		var stone: float = base.get_node("ResourceStorage").get_amount(&"stone")
		assert(camp.request_upgrade(target_id))
		assert(not camp.can_be_moved() and not camp.can_be_demolished() and not camp.can_request_training())
		var site := camp.upgrade_site
		assert(site.required_resources == target.upgrade_cost and site.get_construction_duration() == 0.5)
		var mesh: NavigationMesh = runtime._new_navigation_mesh()
		NavigationServer3D.bake_from_source_geometry_data(mesh, runtime._navigation_geometry())
		region.navigation_mesh = mesh
		var saw_delivery := false
		var saw_building := false
		var result: BuildingBase
		for frame: int in range(2400):
			await physics_frame
			if is_instance_valid(site):
				if site.get_delivered_amount(&"wood") > 0: saw_delivery = true
				if site.construction_progress > 0: saw_building = true
			for building: Node in get_nodes_in_group("buildings"):
				if building is ConstructionSite or building.is_queued_for_deletion(): continue
				if building.building_data != null and building.building_data.id == target_id:
					result = building
			if result != null: break
		assert(result != null, "居民必须实际运料与施工完成分支升级")
		assert(saw_delivery and saw_building)
		assert(not is_instance_valid(camp) or camp.is_queued_for_deletion())
		assert(is_equal_approx(result.get_health() / result.get_max_health(), 0.5))
		assert(grid.occupied_cells.size() == 9 and result.build_grid_area_registered)
		assert(base.get_node("ResourceStorage").get_amount(&"wood") == wood - 2)
		assert(base.get_node("ResourceStorage").get_amount(&"stone") == stone - 2)
		worker.queue_free()
		assert(result.release_build_grid_area())
		result.queue_free()
		await process_frame
	world.queue_free()
	await process_frame
	print("民兵营两分支蓝图权限、真实运料施工、费用／占地／生命比例与升级互斥通过")
	quit()
