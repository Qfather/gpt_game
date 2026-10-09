extends SceneTree
var failed := false
func _initialize() -> void:
	call_deferred("_run")
func _expect(ok: bool, message: String) -> void:
	print("[通过] " if ok else "[失败] ", message)
	failed = failed or not ok
func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world
	var manager := TaskManager.new()
	world.add_child(manager)
	var worker = load("res://Scene/unit/villager.tscn").instantiate()
	world.add_child(worker)
	worker.set_physics_process(false)
	for frame: int in range(5): await physics_frame
	for cancelled: bool in [true, false]:
		var camp: SwordsmanCamp = load("res://Scene/building/game/swordsman_camp.tscn").instantiate()
		world.add_child(camp)
		worker.global_position = camp.get_entrance_position()
		var task := manager.create_task(GameTask.TaskType.TRAIN_SWORDSMAN, camp, camp, 10)
		_expect(manager.claim_task(task,worker), "居民领取训练任务")
		worker._start_current_task()
		worker.move_to_training()
		_expect(worker.passing_door, "居民已进入进门动画等待")
		_expect(manager.cancel_task(task,false), "进门动画期间取消训练")
		if not cancelled:
			camp.queue_free()
		for frame: int in range(180):
			await physics_frame
			if not worker.passing_door: break
		# 等待异步 move_to_training 的恢复和清理分支。
		await physics_frame
		_expect(worker.current_task == null and worker.task_site == null and worker.state != worker.State.TRAINING, "过期进门流程不会重新开训")
		_expect(worker.visible and worker.collision_layer == 2 and worker.collision_mask == 3 and worker.indoor_building == null, "中断训练后居民恢复室外状态")
		if is_instance_valid(camp):
			_expect(camp.training_workers.is_empty() and not camp.indoor_residents.has(worker), "没有遗留训练槽位或室内人员")
			camp.free()
	world.free()
	quit(1 if failed else 0)
