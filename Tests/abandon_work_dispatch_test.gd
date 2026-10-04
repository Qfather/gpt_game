extends SceneTree

var failed: bool = false

func _init() -> void:
	call_deferred("_run")

func _expect(value: bool, text: String) -> void:
	print("[", "通过" if value else "失败", "] ", text)
	if not value:
		failed = true
		push_error(text)

func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world
	var manager := TaskManager.new()
	world.add_child(manager)
	var region := NavigationRegion3D.new()
	var mesh := NavigationMesh.new()
	mesh.vertices = PackedVector3Array([Vector3(-30,0,-30),Vector3(-30,0,30),Vector3(30,0,30),Vector3(30,0,-30)])
	mesh.add_polygon(PackedInt32Array([0,1,2,3]))
	region.navigation_mesh = mesh
	world.add_child(region)
	var base: Node3D = load("res://Scene/building/base.tscn").instantiate()
	world.add_child(base)
	var lumber: ResourceBuildingBase = load("res://Scene/building/game/lumber_camp.tscn").instantiate()
	lumber.set_building_data(load("res://data/buildings/LumberCampData.tres"))
	world.add_child(lumber)
	lumber.position = Vector3(15,0,0)
	var house: BuildingBase = load("res://Scene/building/game/house.tscn").instantiate()
	house.set_building_data(load("res://data/buildings/HouseData.tres"))
	world.add_child(house)
	house.position = Vector3(-15,0,0)
	var worker: Node3D = load("res://Scene/unit/villager.tscn").instantiate()
	world.add_child(worker)
	worker.set_physics_process(false)
	for i in range(10): await physics_frame
	for carrying: bool in [false, true]:
		lumber.add_worker(worker)
		worker.position = Vector3(15,0,4)
		worker._set_unreachable_warning(true)
		worker.carried_resource_id = &"wood" if carrying else &""
		worker.carried_amount = 2.0 if carrying else 0.0
		worker.abandon_current_work()
		_expect(worker.job == worker.Job.NONE and worker.workplace == null and not lumber.workers.has(worker) and not worker.unreachable_warning, "放弃伐木后释放职业、工人名单与警告")
		var task := GameTask.new(StringName("after_abandon_%s" % carrying), GameTask.TaskType.REPAIR_BUILDING)
		task.target = house
		manager.register_task(task)
		_expect(not worker.can_take_task(task), "返回据点前不能重新接任务")
		worker.position = Vector3(3,0,0)
		if carrying:
			var old_wood: float = base.get_resource(&"wood")
			worker.deposit_to_base()
			_expect(worker.carried_amount == 0 and base.get_resource(&"wood") == old_wood + 2, "放弃工作时携带木材先存入据点")
		# 待命目标落在据点碰撞内，但居民已在据点待命范围中。
		worker.navigation_agent.target_position = base.position
		worker.state = worker.State.RETURN_TO_IDLE
		worker.move_to_idle_area()
		_expect(not worker.abandoning_work and worker.can_take_task(task), "回到据点范围后恢复接任务，不等待进入建筑内的待命点")
		manager._dispatch_available_tasks()
		_expect(task.assigned_worker == worker and worker.current_task == task, "实际任务分配器将新维修任务分给放弃工作的居民")
		manager.cancel_task(task, false)
		worker.abandoned_work_target_id = 0
	world.queue_free()
	await process_frame
	quit(1 if failed else 0)
