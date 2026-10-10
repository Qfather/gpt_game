extends SceneTree

func _init() -> void: call_deferred("_run")

func _run() -> void:
	Engine.time_scale = 6.0
	var main: Node3D = load("res://Scene/main.tscn").instantiate()
	main.level_preset = main.level_preset.duplicate(true)
	main.level_preset.layout_seed = 655797904
	main.get_node("Systems/MapGenerateRuntime").settlement_seed = 655797904
	main.level_preset.events.clear()
	main.level_preset.camp_config.enabled = false
	main.level_preset.wildlife_config.enabled = false
	root.add_child(main)
	current_scene = main
	for index: int in range(40): await physics_frame
	var runtime: MapGenerateRuntime = get_first_node_in_group("map_generate_runtime")
	while runtime._navigation_baking or runtime._navigation_update_queued: await physics_frame
	var grid: BuildGrid = get_first_node_in_group("build_grid")
	var data: BuildingData = load("res://data/buildings/FisherHutData.tres")
	var cell := Vector2i(36,-18)
	var ghost: BuildingGhost = main.get_node("Systems/BuildingGhost")
	var catalog := BuildingCatalog.for_tree(self)
	catalog.offered.append(data)
	assert(catalog.choose_blueprint(data.id))
	assert(not grid.is_building_area_free(data,cell,0))
	assert(grid.is_building_area_free(data,cell,3))
	assert(ghost.get_waterfront_rotation(data,cell,0) == 3)
	assert(ghost.can_place_at(data,cell,3))
	assert(not grid.is_building_area_free(data,Vector2i(37,-18),3))
	var transform := Transform3D(Basis(Vector3.UP,3*PI*0.5),Vector3(37,3,-17))
	assert(ghost._create_construction_site(data,cell,3,false,transform,false,false))
	print("[通过] 用户种子655797904、坐标(36,-18)：未揭示水面可放置，自动选朝左岸边，离岸拒绝，创建工地")
	for index: int in range(5400):
		await physics_frame
		await process_frame
		for building: Node in get_nodes_in_group("resource_buildings"):
			if building.building_data != null and building.building_data.id == data.id:
				print("[通过] 用户坐标实际取料、岸上施工与竣工")
				quit(0)
				return
	push_error("用户坐标施工超时")
	quit(1)
