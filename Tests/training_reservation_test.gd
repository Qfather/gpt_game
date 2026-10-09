extends SceneTree

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world
	var catalog := BuildingCatalog.new()
	world.add_child(catalog)
	var manager := TaskManager.new()
	world.add_child(manager)
	var data: BuildingData = catalog.buildings[&"militia_camp"]
	var camp: SwordsmanCamp = data.building_scene.instantiate()
	camp.set_building_data(data)
	world.add_child(camp)
	var workers: Array[Node] = []
	for index: int in range(2):
		var worker: Node = load("res://Scene/unit/villager.tscn").instantiate()
		world.add_child(worker)
		worker.set_physics_process(false)
		workers.append(worker)
	for frame: int in range(5): await physics_frame
	var base: Node3D = catalog.buildings[&"base"].building_scene.instantiate()
	base.set_building_data(catalog.buildings[&"base"])
	world.add_child(base)
	base.add_resource(&"wood", 50)
	var amount: float = base.get_node("ResourceStorage").get_amount(&"wood")
	assert(camp.request_training() and camp.request_training())
	assert(not camp.request_training() and camp.get_training_worker_count() == 2)
	var tasks: Array[GameTask] = []
	for task: GameTask in manager.tasks.values():
		if task.type == GameTask.TaskType.TRAIN_SWORDSMAN: tasks.append(task)
	assert(tasks.size() == 2)
	assert(manager.claim_task(tasks[0], workers[0]))
	assert(manager.claim_task(tasks[1], workers[1]))
	assert(camp.training_workers.size() == 2 and camp.training_requests == 0)
	assert(manager.release_task(tasks[0]))
	assert(camp.get_training_worker_count() == 2 and camp.training_requests == 1)
	assert(base.get_node("ResourceStorage").get_amount(&"wood") == amount - 10, "重派训练保持费用和槽位预约")
	assert(manager.cancel_task(tasks[0], false))
	assert(camp.get_training_worker_count() == 1 and camp.training_requests == 0)
	assert(base.get_node("ResourceStorage").get_amount(&"wood") == amount - 5)
	assert(not manager.cancel_task(tasks[0], false))
	assert(manager.cancel_task(tasks[1], false))
	assert(camp.get_training_worker_count() == 0)
	assert(base.get_node("ResourceStorage").get_amount(&"wood") == amount, "取消只退一次，两个训练完整退费")
	world.queue_free()
	await process_frame
	print("训练两人预约、重派保留费用／槽位、取消不重复退款测试通过")
	quit()
