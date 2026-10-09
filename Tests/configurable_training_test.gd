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
	var base: Node3D = catalog.buildings[&"base"].building_scene.instantiate()
	base.set_building_data(load("res://data/buildings/BaseData.tres"))
	world.add_child(base)
	base.position = Vector3(-5, 0, 0)
	base.add_resource(&"wood", 100)
	base.add_resource(&"stone", 100)
	var region := NavigationRegion3D.new()
	region.name = "NavigationRegion3D"
	world.add_child(region)
	var runtime := TestMap.new()
	world.add_child(runtime)
	runtime._navigation_faces = PackedVector3Array([Vector3(-15,0,-15),Vector3(15,0,-15),Vector3(-15,0,15),Vector3(15,0,-15),Vector3(15,0,15),Vector3(-15,0,15)])
	var manager := TaskManager.new()
	world.add_child(manager)
	for unit_id: StringName in [&"militia", &"swordsman", &"archer"]:
		var data: BuildingData = catalog.buildings[&"militia_camp"].duplicate(true)
		var recipe := TrainingRecipe.new()
		recipe.unit_id = unit_id
		recipe.time_seconds = 0.5
		recipe.cost = {&"wood": 3.0}
		data.training_recipes = [recipe]
		var camp: SwordsmanCamp = data.building_scene.instantiate()
		camp.set_building_data(data)
		world.add_child(camp)
		var mesh: NavigationMesh = runtime._new_navigation_mesh()
		NavigationServer3D.bake_from_source_geometry_data(mesh, runtime._navigation_geometry())
		region.navigation_mesh = mesh
		for frame: int in range(10): await physics_frame
		var worker: Node = load("res://Scene/unit/villager.tscn").instantiate()
		world.add_child(worker)
		worker.position = Vector3(0, 0, 5)
		for frame: int in range(5): await physics_frame
		var amount: float = base.get_node("ResourceStorage").get_amount(&"wood")
		assert(camp.request_training())
		assert(base.get_node("ResourceStorage").get_amount(&"wood") == amount - 3)
		# 修改配置后，已派发任务仍使用原配方快照。
		recipe.time_seconds = 100
		recipe.unit_id = &"resident"
		var entered := false
		for frame: int in range(900):
			await physics_frame
			if worker.state == worker.State.TRAINING:
				entered = true
				assert(worker.indoor_building == camp and not worker.visible)
			if worker.has_combat_role() and not worker.passing_door: break
		assert(entered, "必须实际走到正面并入屋训练")
		assert(worker.unit_data.id == unit_id and worker.has_combat_role())
		assert(worker.visible and worker.collision_layer == 2)
		assert(camp.get_training_worker_count() == 0)
		assert(base.get_node("ResourceStorage").get_amount(&"wood") == amount - 3)
		worker.queue_free()
		camp.queue_free()
		await process_frame
	world.queue_free()
	await process_frame
	print("公共训练实际行走、民兵／剑士／弓箭手与配方快照测试通过")
	quit()
