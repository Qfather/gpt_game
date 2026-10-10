extends SceneTree

var failed: bool = false


func _init() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		push_error(message)


func _run() -> void:
	var panel: VillagerPanel = load("res://UI/unit_panel/villager_panel.tscn").instantiate()
	root.add_child(panel)
	await process_frame
	await process_frame
	var worker = load("res://Scene/unit/villager.tscn").instantiate()
	root.add_child(worker)
	worker.set_physics_process(false)
	var workplace := Node3D.new()
	workplace.name = "测试工作建筑"
	root.add_child(workplace)
	worker.workplace = workplace
	panel.open_unit(worker)
	_expect(panel.workplace_label.text == "工作地点：测试工作建筑", "有效工作建筑名称显示错误")
	workplace.free()
	panel.workplace_label.text = "未刷新"
	panel.open_unit(worker)
	_expect(panel.workplace_label.text == "工作地点：无", "工作建筑释放后，打开居民详情未完成刷新")
	worker.workplace = null
	for property: String in ["garrisoned_in", "garrison_target"]:
		var building := Node3D.new()
		root.add_child(building)
		worker.set(property, building)
		building.free()
		worker.state = worker.State.MOVE_TO_BARRACKS if property == "garrison_target" else worker.State.IDLE
		panel.workplace_label.text = "未刷新"
		panel.refresh()
		_expect(panel.workplace_label.text == "工作地点：无", "驻军建筑释放后，居民详情未完成刷新：" + property)
		worker.set(property, null)
	worker.free()
	panel.refresh()
	_expect(not panel.visible and panel.current_unit == null, "居民释放后，详情面板未关闭")
	panel.queue_free()
	await process_frame
	print("居民详情对象生命周期回归：", "失败" if failed else "通过")
	quit(1 if failed else 0)
