extends SceneTree

var failed: bool = false


func _initialize() -> void:
	call_deferred("_run")


func _expect(value: bool, message: String) -> void:
	if not value:
		failed = true
		push_error("失败：" + message)


func _active_tasks(manager: TaskManager, site: ConstructionSite) -> int:
	var count: int = 0
	for value: Variant in manager.tasks.values():
		var task: GameTask = value as GameTask
		if task != null and task.target == site and task.state in [GameTask.State.AVAILABLE, GameTask.State.CLAIMED, GameTask.State.IN_PROGRESS]:
			count += 1
	return count


func _run() -> void:
	var scene: Node = load("res://Scene/main.tscn").instantiate()
	scene.level_preset = scene.level_preset.duplicate(true)
	scene.level_preset.map_resources.clear()
	scene.get_node("Systems/MapGenerateRuntime").settlement_seed = 42
	root.add_child(scene)
	current_scene = scene
	for frame: int in range(10):
		await process_frame
	for villager: Node in get_nodes_in_group("villagers"):
		villager.set_physics_process(false)
	var manager: TaskManager = get_first_node_in_group("task_manager") as TaskManager
	var data: BuildingData = load("res://data/buildings/LumberCampData.tres") as BuildingData
	var site: ConstructionSite = load("res://Scene/building/construction_site.tscn").instantiate() as ConstructionSite
	site.setup(data, Vector2i(2, 2), 0, false)
	scene.add_child(site)
	site.set_process(false)
	for frame: int in range(4):
		await process_frame
	_expect(_active_tasks(manager, site) > 0, "测试工地没有生成运输任务")
	var worker: Node = null
	for value: Variant in manager.tasks.values():
		var task: GameTask = value as GameTask
		if task != null and task.target == site and is_instance_valid(task.assigned_worker):
			worker = task.assigned_worker
			break
	_expect(worker != null, "测试工地没有分配居民")
	if worker != null:
		worker.abandon_current_work()
		_expect(site.construction_worker_limit == 0, "放弃后工地仍保留自动派工名额")
		_expect(_active_tasks(manager, site) == 0, "放弃后工地任务没有取消")
		manager.request_dispatch()
		for frame: int in range(4):
			await process_frame
		_expect(_active_tasks(manager, site) == 0 and site.get_worker_count() == 0, "调度后又给卡住的工地派人")
		site.request_additional_worker()
		for frame: int in range(4):
			await process_frame
		_expect(site.construction_worker_limit == 1 and _active_tasks(manager, site) > 0, "手动增加居民无法恢复工地派工")
	scene.queue_free()
	await process_frame
	print("工地放弃后停止派工测试", "失败" if failed else "通过")
	quit(1 if failed else 0)
