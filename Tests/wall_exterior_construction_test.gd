extends SceneTree

var failed: bool = false

func _initialize() -> void:
	call_deferred("_run")

func _expect(value: bool, message: String) -> void:
	print("[", "通过" if value else "失败", "] ", message)
	if not value:
		failed = true
		push_error(message)

func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var resident = load("res://Scene/unit/villager.tscn").instantiate()
	world.add_child(resident)
	resident.set_physics_process(false)
	for resource_path: String in ["res://data/buildings/WallData.tres", "res://data/buildings/WoodWallData.tres"]:
		var data: BuildingData = load(resource_path)
		var site := ConstructionSite.new()
		site.setup(data, Vector2i.ZERO, 0, false)
		site.set_activation_deferred_until_unpause(true)
		world.add_child(site)
		_expect(site.exterior_construction_started, "%s 从搬运开始使用外侧施工" % data.id)
		_expect(site.has_model_bounds, "%s 已计算实际模型范围" % data.id)
		var target: Vector3 = site.get_worker_target_position(resident)
		var local_target: Vector3 = site.to_local(target)
		var bounds: AABB = site.model_bounds
		_expect(local_target.x < bounds.position.x or local_target.x > bounds.end.x or local_target.z < bounds.position.z or local_target.z > bounds.end.z, "%s 施工目标在模型外" % data.id)
		resident.task_site = site
		resident.global_position = target
		resident.navigation_agent.target_position = target
		_expect(resident._has_reached_task_site_navigation_target(), "%s 居民站在外侧即可交料或开工" % data.id)
		resident.global_position = target + Vector3(0, 0, 1)
		_expect(not resident._has_reached_task_site_navigation_target(), "%s 尚未到达仍不可施工" % data.id)
		resident.state = resident.State.BUILDING
		site.builders.append(resident)
		site.state = ConstructionSite.State.BUILDING
		site._process(float(data.construction_time) * 0.8)
		_expect(site.construction_progress > float(data.construction_time) * 0.7 and not resident.construction_repositioning, "%s 超过70%%仍在外侧连续施工，无需穿过工地换位" % data.id)
		resident.task_site = null
		site.free()
	var normal_site := ConstructionSite.new()
	var normal_data := BuildingData.new()
	normal_data.id = &"warehouse"
	normal_data.construction_cost = {&"wood": 1.0}
	normal_site.setup(normal_data, Vector2i.ZERO, 0, false)
	_expect(not normal_site.exterior_construction_started, "普通建筑仍从内部施工阶段开始")
	normal_site.free()
	resident.free()
	await _test_placed_walls(world)
	await _test_upgrade_workers(world)
	world.free()
	quit(1 if failed else 0)

func _test_placed_walls(world: Node3D) -> void:
	current_scene = world
	var region := NavigationRegion3D.new()
	var navigation := NavigationMesh.new()
	navigation.vertices = PackedVector3Array([Vector3(-20, 0, -20), Vector3(-20, 0, 20), Vector3(20, 0, 20), Vector3(20, 0, -20)])
	navigation.add_polygon(PackedInt32Array([0, 1, 2, 3]))
	region.navigation_mesh = navigation
	world.add_child(region)
	var systems := Node3D.new()
	systems.name = "Systems"
	world.add_child(systems)
	var grid := BuildGrid.new()
	grid.name = "BuildGrid"
	systems.add_child(grid)
	var ghost := BuildingGhost.new()
	systems.add_child(ghost)
	ghost.set_process(false)
	for frame: int in range(10): await physics_frame
	for resource_path: String in ["res://data/buildings/WallData.tres", "res://data/buildings/WoodWallData.tres"]:
		var data: BuildingData = load(resource_path).duplicate()
		data.construction_cost = {&"wood": 10.0}
		data.max_construction_workers = 2
		# 经过游戏实际放置入口，防止放置逻辑覆盖 setup 的外侧施工设置。
		_expect(ghost._create_construction_site(data, Vector2i.ZERO, 0, false, Transform3D(Basis.IDENTITY, grid.grid_to_world(Vector2i.ZERO)), false, true), "%s 实际放置成功" % data.id)
		var site: ConstructionSite
		for node: Node in get_nodes_in_group("construction_sites"):
			if not node.is_queued_for_deletion(): site = node as ConstructionSite
		site.set_process(false)
		_expect(site.exterior_construction_started, "%s 放置后保持外侧施工" % data.id)
		var workers: Array[CharacterBody3D] = []
		for index: int in range(2):
			var unit = load("res://Scene/unit/villager.tscn").instantiate()
			world.add_child(unit)
			unit.set_physics_process(false)
			# start() 等待导航物理同步；任务在初始化结束后派发。
			for frame: int in range(3): await physics_frame
			unit.global_position = Vector3(-3 + index, 0, -3)
			var delivery := GameTask.new(&"wall_delivery", GameTask.TaskType.DELIVER_CONSTRUCTION_RESOURCE)
			delivery.target = site
			unit.current_task = delivery
			unit.task_site = site
			unit.carried_resource_id = &"wood"
			unit.carried_amount = 5.0
			unit._set_task_site_navigation_target()
			unit.state = unit.State.MOVE_TO_TASK_SITE
			workers.append(unit)
		for frame: int in range(360):
			for unit: CharacterBody3D in workers:
				if unit.state == unit.State.MOVE_TO_TASK_SITE: unit.move_to_task_site()
			await physics_frame
			if site.get_delivered_amount(&"wood") >= 10.0: break
		_expect(site.get_delivered_amount(&"wood") == 10.0, "%s 两名居民实际行走后交付材料" % data.id)
		if site.get_delivered_amount(&"wood") < 10.0:
			for unit: CharacterBody3D in workers:
				print("交料诊断：state=", unit.state, " position=", unit.global_position, " target=", unit.navigation_agent.target_position, " carried=", unit.carried_amount, " finished=", unit.navigation_agent.is_navigation_finished())
		for resource_id: StringName in site.required_resources:
			site.receive_delivery(resource_id, site.get_still_needed(resource_id))
		for unit: CharacterBody3D in workers:
			var build := GameTask.new(&"wall_build", GameTask.TaskType.BUILD)
			build.target = site
			unit.current_task = build
			unit.task_site = site
			unit._set_task_site_navigation_target()
			unit.state = unit.State.MOVE_TO_BUILD_SITE
		for frame: int in range(360):
			for unit: CharacterBody3D in workers:
				if unit.state == unit.State.MOVE_TO_BUILD_SITE: unit.move_to_build_site()
			await physics_frame
			if site.builders.size() == 2: break
		_expect(site.builders.size() == 2, "%s 两名居民均可从外侧开工" % data.id)
		for unit: CharacterBody3D in workers:
			var point: Vector3 = site.to_local(unit.global_position)
			_expect(absf(point.x) > 0.5 or absf(point.z) > 0.5, "%s 居民施工时位于工地格外" % data.id)
			unit.free()
		site.release_build_grid_area()
		site.free()


func _test_upgrade_workers(world: Node3D) -> void:
	for data_name: String in ["WoodWallData", "WoodGateData", "WoodWallTowerData"]:
		var data: BuildingData = load("res://data/buildings/" + data_name + ".tres")
		var wooden: BuildingBase = data.building_scene.instantiate()
		wooden.building_data = data
		world.add_child(wooden)
		wooden.set_build_grid_occupancy(Vector2i.ZERO, data.grid_size, 0)
		_expect(wooden.request_upgrade(), "%s 创建升级工地" % data.id)
		var site: ConstructionSite = wooden.upgrade_site
		site.set_process(false)
		var worker = load("res://Scene/unit/villager.tscn").instantiate()
		world.add_child(worker)
		worker.set_physics_process(false)
		for frame: int in range(5): await physics_frame
		for resource_id: StringName in site.required_resources:
			worker.global_position = Vector3(-4, 0, -4)
			var delivery := GameTask.new(&"upgrade_delivery", GameTask.TaskType.DELIVER_CONSTRUCTION_RESOURCE)
			delivery.target = site
			worker.current_task = delivery
			worker.task_site = site
			worker.carried_resource_id = resource_id
			worker.carried_amount = site.required_resources[resource_id]
			worker._set_task_site_navigation_target()
			worker.state = worker.State.MOVE_TO_TASK_SITE
			for frame: int in range(360):
				if worker.state == worker.State.MOVE_TO_TASK_SITE: worker.move_to_task_site()
				await physics_frame
				if worker.carried_amount == 0: break
			_expect(site.get_delivered_amount(resource_id) == site.required_resources[resource_id], "%s 居民在旧建筑外实际交付%s差价" % [data.id, resource_id])
		var build := GameTask.new(&"upgrade_build", GameTask.TaskType.BUILD)
		build.target = site
		worker.current_task = build
		worker.task_site = site
		worker._set_task_site_navigation_target()
		worker.state = worker.State.MOVE_TO_BUILD_SITE
		for frame: int in range(360):
			if worker.state == worker.State.MOVE_TO_BUILD_SITE: worker.move_to_build_site()
			await physics_frame
			if site.builders.has(worker): break
		_expect(site.builders.has(worker), "%s 居民在旧建筑外实际开工" % data.id)
		worker.free()
		site.free()
		wooden.free()
