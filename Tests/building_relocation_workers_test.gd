extends SceneTree

class TestMap extends MapGenerateRuntime:
	func _ready() -> void:
		add_to_group("map_generate_runtime")

var world: Node3D
var grid: BuildGrid
var runtime: MapGenerateRuntime
var region: NavigationRegion3D

func _init() -> void:
	call_deferred("_run")

func _building(id: String, cell: Vector2i) -> BuildingBase:
	var data: BuildingData = load("res://data/buildings/" + id + "Data.tres")
	var building: BuildingBase = data.building_scene.instantiate()
	building.set_building_data(data)
	world.add_child(building)
	building.position = grid.grid_to_world(cell)
	assert(grid.occupy_area(cell, data.grid_size, 0, false, true))
	building.set_build_grid_occupancy(cell, data.grid_size, 0)
	building.set_process(false)
	return building

func _unit() -> Node3D:
	var unit: Node3D = load("res://Scene/unit/villager.tscn").instantiate()
	world.add_child(unit)
	unit.set_physics_process(false)
	return unit

func _bake() -> void:
	var mesh: NavigationMesh = runtime._new_navigation_mesh()
	NavigationServer3D.bake_from_source_geometry_data(mesh, runtime._navigation_geometry())
	region.navigation_mesh = mesh
	for i in range(10): await physics_frame

func _run() -> void:
	world = Node3D.new()
	root.add_child(world)
	current_scene = world
	grid = BuildGrid.new()
	grid.grid_min = Vector2i(-25,-25)
	grid.grid_max = Vector2i(24,24)
	world.add_child(grid)
	region = NavigationRegion3D.new()
	region.name = "NavigationRegion3D"
	world.add_child(region)
	runtime = TestMap.new()
	world.add_child(runtime)
	runtime._navigation_faces = PackedVector3Array([Vector3(-25,0,-25),Vector3(25,0,-25),Vector3(-25,0,25),Vector3(25,0,-25),Vector3(25,0,25),Vector3(-25,0,25)])
	var base: Node3D = load("res://Scene/building/base.tscn").instantiate()
	world.add_child(base)
	base.position = Vector3(-18,0,0)
	base.add_resource(&"wood", 200)
	base.add_resource(&"stone", 200)
	var camp := _building("SwordsmanCamp", Vector2i(-8,-8))
	var tower := _building("Barracks", Vector2i(-8,6))
	var farm := _building("Farm", Vector2i(-8,-18))
	await _bake()
	var trainee := _unit()
	trainee.position = camp.position + Vector3(0,0,3)
	trainee.task_site = camp
	trainee.current_task = GameTask.new()
	camp.training_workers.append(trainee)
	var archer := _unit()
	archer.set_combat_role(CombatRole.Type.ARCHER)
	assert(archer.try_assign_to_barracks(tower))
	tower.enter_garrison(archer)
	var farmer := _unit()
	farmer.position = farm.get_interaction_position(farmer)
	assert(farm.add_worker(farmer))
	farmer.start_farm_work()
	for i in range(3): await physics_frame
	assert(camp.begin_training(trainee))
	trainee.training_elapsed = 3.25
	assert(camp.relocate(grid, Vector2i(3,-8), 1, true, Transform3D(Basis.IDENTITY, Vector3(4,0,-7))))
	assert(trainee.visible and trainee.training_elapsed == 3.25 and trainee.relocated_building == camp)
	assert(tower.relocate(grid, Vector2i(3,6), 0, false, Transform3D(Basis.IDENTITY, Vector3(4,0,7))))
	assert(archer.visible and archer.garrisoned_in == null and archer.garrison_target == tower and archer.global_position.x < 0.0 and not archer.is_stunned())
	assert(farm.relocate(grid, Vector2i(3,-18), 0, false, Transform3D(Basis.IDENTITY, Vector3(4,0,-17))))
	assert(farmer.workplace == farm and farmer.target_field == null and farmer.relocated_building == farm)
	await _bake()
	for i in range(600):
		if trainee.relocated_building != null: trainee._process_building_relocation()
		if archer.garrisoned_in == null: archer.move_to_barracks()
		if farmer.relocated_building != null: farmer._process_building_relocation()
		if trainee.relocated_building == null and archer.garrisoned_in == tower and farmer.relocated_building == null: break
		await physics_frame
	assert(trainee.relocated_building == null and trainee.state == trainee.State.TRAINING and not trainee.visible and trainee.training_elapsed == 3.25)
	assert(camp.training_workers.has(trainee) and camp.transform.basis.is_equal_approx(Basis(Vector3.UP, PI * 0.5).scaled_local(Vector3(-1,1,1))))
	assert(archer.garrisoned_in == tower and tower.garrisoned_units.has(archer))
	assert(farmer.relocated_building == null and farmer.position.x > 0.0 and farmer.state == farmer.State.FIND_FIELD_WORK)
	assert(camp.relocate(grid, Vector2i(13,-8), 0, false, Transform3D(Basis.IDENTITY, Vector3(14,0,-7))))
	trainee.clear_current_task()
	assert(trainee.relocated_building == null and trainee.visible and trainee.state != trainee.State.MOVE_TO_RELOCATED_BUILDING)
	print("建筑搬迁工人测试通过：训练角色步行后继续训练、进度保留；驻军从原址走向新军营；农民到新址恢复田地工作；旋转镜像保留")
	world.queue_free()
	await process_frame
	quit()
