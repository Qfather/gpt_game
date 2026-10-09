extends SceneTree

var failed: bool = false

class TestMap extends MapGenerateRuntime:
	func _ready() -> void: add_to_group("map_generate_runtime")

func _initialize() -> void:
	call_deferred("_run")
	call_deferred("_watchdog")

func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world
	var catalog := BuildingCatalog.new()
	world.add_child(catalog)
	var base: BuildingBase = catalog.buildings[&"base"].building_scene.instantiate()
	base.set_building_data(load("res://data/buildings/BaseData.tres"))
	world.add_child(base)
	base.position = Vector3(-5, 0, 0)
	base.add_resource(&"wood", 100)
	var region := NavigationRegion3D.new()
	region.name = "NavigationRegion3D"
	world.add_child(region)
	var runtime := TestMap.new()
	world.add_child(runtime)
	runtime._navigation_faces = PackedVector3Array([Vector3(-15,0,-15),Vector3(15,0,-15),Vector3(-15,0,15),Vector3(15,0,-15),Vector3(15,0,15),Vector3(-15,0,15)])
	var manager := TaskManager.new()
	world.add_child(manager)
	var data: BuildingData = catalog.buildings[&"militia_camp"].duplicate(true)
	var recipe := TrainingRecipe.new()
	recipe.unit_id = &"swordsman"
	recipe.time_seconds = 0.5
	recipe.cost = {&"wood": 3.0}
	data.training_recipes = [recipe]
	var training: SwordsmanCamp = data.building_scene.instantiate()
	training.set_building_data(data)
	world.add_child(training)
	var mesh: NavigationMesh = runtime._new_navigation_mesh()
	NavigationServer3D.bake_from_source_geometry_data(mesh, runtime._navigation_geometry())
	region.navigation_mesh = mesh
	for frame: int in range(10): await physics_frame
	var worker: Node = load("res://Scene/unit/villager.tscn").instantiate()
	world.add_child(worker)
	worker.position = Vector3(0, 0, 5)
	for frame: int in range(5): await physics_frame
	var treasure: TreasureCamp = load("res://Scene/world/treasure_camp.tscn").instantiate()
	world.add_child(treasure)
	treasure.position = Vector3(8, 0, 8)
	# 本测试只验证分配与出门的交界，不推进无守卫营地的清剿。
	treasure.set_process(false)
	_expect(training.request_training(), "真实训练任务可开始")
	var entered: bool = false
	var observed_exit: bool = false
	for frame: int in range(900):
		await physics_frame
		if worker.state == worker.State.TRAINING: entered = true
		if worker.has_combat_role() and worker.passing_door and not observed_exit:
			observed_exit = true
			_expect(not worker.can_accept_treasure_hunt(), "正在出门的士兵不能出现在营地可分配名单")
			_expect(not treasure.add_participant(worker), "营地接口拒绝出门期间分配")
			print("出门期快照：passing=", worker.passing_door, " collision_mask=", worker.collision_mask, " 保存掩码=", worker.treasure_resume.get("collision_mask", -1))
		if worker.has_combat_role() and not worker.passing_door: break
	_expect(entered and observed_exit, "居民实际走到入口、入屋训练并开始出门")
	_expect(not worker.passing_door and worker.collision_mask == 3, "实际出门完成后恢复实体阻挡")
	treasure.remove_participant(worker)
	_expect(worker.collision_mask == 3, "出门后撤回不能恢复为关闭碰撞")
	print("撤回快照：collision_layer=", worker.collision_layer, " collision_mask=", worker.collision_mask)
	_expect(worker.initial_idle_position_pending and not worker.can_accept_treasure_hunt(), "出门后尚未实际到达待命点时拒绝分配")
	for frame: int in range(900):
		if worker.is_idle(): break
		await physics_frame
	_expect(worker.is_idle() and treasure.add_participant(worker), "实际完成站位后仍可正常分配营地")
	# 验证旧过渡状态遗留的0不会再次恢复到室外。
	worker.treasure_resume["collision_mask"] = 0
	treasure.remove_participant(worker)
	_expect(worker.collision_mask == 3, "旧出门快照的零掩码恢复为正常室外碰撞")
	world.queue_free()
	await process_frame
	await process_frame
	print("营地出门过渡分配测试", "失败" if failed else "通过")
	quit(1 if failed else 0)

func _expect(condition: bool, message: String) -> void:
	print("[", "通过" if condition else "失败", "] ", message)
	if not condition:
		failed = true
		push_error(message)

func _watchdog() -> void:
	await create_timer(45.0, true, false, true).timeout
	push_error("营地出门过渡分配测试超时")
	quit(1)
