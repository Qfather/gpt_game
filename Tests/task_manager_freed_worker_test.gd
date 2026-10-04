extends SceneTree

class TestSite extends Node:
	func get_max_construction_workers() -> int:
		return 2

class TestWorker extends Node:
	var current_task: GameTask
	func can_take_task(_task: GameTask) -> bool:
		return current_task == null
	func set_current_task(task: GameTask) -> void:
		current_task = task

var failed: bool = false

func _init() -> void:
	call_deferred("_run")

func _expect(value: bool, message: String) -> void:
	print("[", "通过" if value else "失败", "] ", message)
	if not value:
		failed = true

func _run() -> void:
	var manager := TaskManager.new()
	var site := TestSite.new()
	var old_worker := TestWorker.new()
	var replacement := TestWorker.new()
	root.add_child(manager)
	root.add_child(site)
	root.add_child(old_worker)
	root.add_child(replacement)
	var preferred: Array[Node] = [old_worker]
	manager.create_construction_build_tasks(site, preferred)
	var task: GameTask = manager.tasks.values()[0]
	_expect(not manager.claim_task(task, replacement), "预约居民仍存活时，其他居民不能抢建造任务")
	old_worker.queue_free()
	await process_frame
	var available: Array[Node] = [replacement]
	manager.create_construction_build_tasks(site, available)
	_expect(manager.tasks.size() == 2, "预约居民被删除后，重新统计建造任务不会增加重复任务")
	_expect(typeof(task.data.get("preferred_worker")) == TYPE_NIL, "重新统计时清除已释放的预约居民")
	_expect(manager.claim_task(task, replacement), "新居民可以接替已释放居民的建造任务")
	var second_old_worker := TestWorker.new()
	var second_replacement := TestWorker.new()
	root.add_child(second_old_worker)
	root.add_child(second_replacement)
	var second_task := manager.create_task(GameTask.TaskType.BUILD, site, site)
	second_task.data["preferred_worker"] = second_old_worker
	second_old_worker.queue_free()
	await process_frame
	_expect(manager.claim_task(second_task, second_replacement), "未重新统计时，领取任务也能处理已释放的预约居民")
	_expect(typeof(second_task.data.get("preferred_worker")) == TYPE_NIL, "领取任务时清除失效预约")
	manager.queue_free()
	site.queue_free()
	replacement.queue_free()
	second_replacement.queue_free()
	await process_frame
	quit(1 if failed else 0)
