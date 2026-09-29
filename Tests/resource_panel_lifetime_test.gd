extends SceneTree

var failed: bool = false


func _initialize() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		push_error("失败：" + message)


func _run() -> void:
	var panel: ResourceNodePanel = load("res://UI/resource_panel/resource_node_panel.tscn").instantiate() as ResourceNodePanel
	root.add_child(panel)
	await process_frame
	await process_frame
	for path: String in ["res://Scene/resource/tree.tscn", "res://Scene/resource/stone.tscn"]:
		var resource: ResourceBase = load(path).instantiate() as ResourceBase
		root.add_child(resource)
		panel.open_building(resource)
		_expect(panel.visible, "资源面板未打开")
		resource.gather(resource.resource_amount)
		await process_frame
		await process_frame
		panel.refresh()
		_expect(not panel.visible and panel.current_building == null, "资源采尽释放后面板未关闭或引用未清空")
	panel.queue_free()
	await process_frame
	print("资源面板对象释放测试", "失败" if failed else "通过")
	quit(1 if failed else 0)
