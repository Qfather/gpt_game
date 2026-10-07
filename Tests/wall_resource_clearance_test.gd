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
	current_scene = world
	var systems := Node3D.new()
	systems.name = "Systems"
	world.add_child(systems)
	var grid := BuildGrid.new()
	grid.name = "BuildGrid"
	systems.add_child(grid)
	var roads = preload("res://Script/world/road_manager.gd").new()
	roads.grid = grid
	world.add_child(roads)
	var ghost := BuildingGhost.new()
	systems.add_child(ghost)
	ghost.set_process(false)
	var resources: Array[ResourceBase] = []
	for index: int in range(3):
		var resource: ResourceBase = load("res://Scene/resource/tree.tscn" if index != 1 else "res://Scene/resource/stone.tscn").instantiate()
		world.add_child(resource)
		resource.position = Vector3(0.5, 0, index * 0.7 - 0.2)
		resource.reserved_by = ghost
		resources.append(resource)
	await process_frame
	for path: String in ["res://data/buildings/WallData.tres", "res://data/buildings/WoodWallData.tres"]:
		var data: BuildingData = load(path)
		ghost.building_data = data
		var original_time: float = data.construction_time
		_expect(not ghost._create_construction_site(data, Vector2i.ZERO, 0, false, Transform3D(Basis.IDENTITY, grid.grid_to_world(Vector2i.ZERO)), false, true), "直接覆盖资源的墙蓝图被拒绝")
		var route: Array[Vector2i] = ghost.plan_wall_stroke(Vector2i(-5, 0), Vector2i(5, 0))
		_expect(not route.is_empty() and not route.has(Vector2i.ZERO) and ghost.place_wall_stroke(route), "实际资源簇被自动绕过：" + data.display_name)
		for resource: ResourceBase in resources:
			_expect(not resource.is_queued_for_deletion() and resource.resource_amount > 0 and resource.reserved_by == ghost, "建墙保留资源数量与采集预约")
		for site: ConstructionSite in get_nodes_in_group("construction_sites"):
			if site.is_queued_for_deletion(): continue
			_expect(site.building_data.construction_time == original_time, "绕障墙段不再增加清障施工时间")
			site.cancel_construction()
		await process_frame
		for resource: ResourceBase in resources: _expect(is_instance_valid(resource) and resource.resource_amount > 0, "取消墙工地不会删除资源")
	world.queue_free()
	await process_frame
	print("城墙资源绕障测试", "失败" if failed else "通过")
	quit(1 if failed else 0)
