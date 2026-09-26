extends SceneTree

var failed: bool = false

class HealthTarget:
	extends Node3D
	var max_health: float = 100.0
	var current_health: float = 50.0


func _initialize() -> void:
	call_deferred("_run")


func _expect(value: bool, message: String) -> void:
	if not value:
		failed = true
		push_error("失败：" + message)


func _site(scene: Node) -> ConstructionSite:
	var site: ConstructionSite = load("res://Scene/building/construction_site.tscn").instantiate() as ConstructionSite
	site.setup(load("res://data/buildings/WallData.tres"), Vector2i(8, 8), 0, false)
	scene.add_child(site)
	site.set_process(false)
	site.delivered_resources = site.required_resources.duplicate()
	site.state = ConstructionSite.State.READY_TO_BUILD
	return site


func _run() -> void:
	var scene: Node = load("res://Scene/main.tscn").instantiate()
	scene.level_preset = scene.level_preset.duplicate(true)
	scene.level_preset.map_resources.clear()
	root.add_child(scene)
	current_scene = scene
	await process_frame
	await process_frame
	var workers: Array[Node] = get_nodes_in_group("villagers")
	for worker: Node in workers:
		worker.set_physics_process(false)
	var manager: TaskManager = get_first_node_in_group("task_manager") as TaskManager
	var first: ConstructionSite = _site(scene)
	var second: ConstructionSite = _site(scene)
	manager._run_dispatch()
	_expect(first.get_worker_count() == mini(3, workers.size()), "默认同级没有优先分配先放工地")
	for worker: Node in workers:
		if worker.current_task != null and worker.current_task.target == first:
			first.add_builder(worker)
	second.set_construction_priority(1)
	manager._run_dispatch()
	_expect(first.get_worker_count() == 0 and first.builders.is_empty(), "原施工居民没有释放")
	_expect(second.get_worker_count() == mini(3, workers.size()), "高优先级没有接收施工居民")
	_expect(first.construction_worker_limit == 3, "调度错误减少原工地人数上限")
	second.set_construction_priority(0)
	first.set_construction_priority(2)
	manager._run_dispatch()
	_expect(first.get_worker_count() == mini(3, workers.size()), "再次调高优先级未转场")
	var panel: ResourceBuildingPanel = scene.find_children("*", "ResourceBuildingPanel", true, false)[0] as ResourceBuildingPanel
	panel.current_building = first
	panel.refresh()
	_expect(panel.priority_row.visible and panel.priority_value.text == "2", "优先级面板数值错误")
	(panel.priority_row.get_child(2).get_child(0) as Button).pressed.emit()
	_expect(first.construction_priority == 3 and panel.priority_value.text == "3", "向上按钮未生效")
	first.set_construction_priority(-1)
	_expect(first.construction_priority == 0, "优先级不应低于零")
	# 模拟已取货的居民：调度打断时必须保留携带物，先送回据点。
	var carrier: Node = workers[0]
	carrier.carried_resource_id = &"wood"
	carrier.carried_amount = 5.0
	second.set_construction_priority(4)
	manager._run_dispatch()
	_expect(is_equal_approx(carrier.carried_amount, 5.0), "转场丢失了居民携带材料")
	_expect(carrier.current_task == null, "退料居民被立即分配新任务")
	_expect(second.get_worker_count() <= second.construction_worker_limit, "优先级突破施工人数上限")
	manager.cancel_tasks_for_target(first)
	manager.cancel_tasks_for_target(second)
	carrier.carried_amount = 0.0
	carrier.return_to_idle()
	second.state = ConstructionSite.State.WAITING_RESOURCES
	second.delivered_resources[&"wood"] = second.required_resources[&"wood"] - 5.0
	manager._run_dispatch()
	_expect(second.get_worker_count() == mini(3, workers.size()), "高优先级只缺一趟材料时其他居民被低优先级抢走")
	var camera: Camera3D = root.get_camera_3d()
	var target := HealthTarget.new()
	root.add_child(target)
	target.global_position = camera.global_transform * Vector3(0, 0, -10)
	var bar := HealthBar3D.new()
	target.add_child(bar)
	await process_frame
	paused = true
	camera.position.x += 2.0
	await process_frame
	await process_frame
	var expected: Vector2 = camera.unproject_position(bar.global_position) - bar.screen_bar.size * 0.5
	_expect(bar.screen_bar.visible and bar.screen_bar.position.distance_to(expected) < 0.1, "暂停移动镜头后血条未跟随")
	paused = false
	target.queue_free()
	scene.queue_free()
	await process_frame
	print("施工优先级与暂停血条测试", "失败" if failed else "通过")
	quit(1 if failed else 0)
