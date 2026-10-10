extends SceneTree

# EditorPlugin 只能在编辑器模式实例化：--headless --editor --script 本文件。
var failed: bool = false

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		push_error(message)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	await process_frame
	while EditorInterface.get_resource_filesystem().is_scanning():
		await process_frame
	var plugin = load("res://addons/resource_editor/resource_editor_plugin.gd").new()
	if plugin == null:
		push_error("请以--editor模式运行资源筛选回归")
		quit(1)
		return
	var parent := VBoxContainer.new()
	root.add_child(parent)
	plugin._create_filters(parent)
	plugin.resource_list = ItemList.new()
	plugin.resource_count_label = Label.new()
	parent.add_child(plugin.resource_list)
	parent.add_child(plugin.resource_count_label)
	plugin.resource_items = ResourceEditorDataService.scan_resources()
	plugin._apply_filters()
	_expect(plugin.resource_list.item_count == 8, "默认全部分类必须显示8种资源")
	_expect(plugin.resource_count_label.text == "显示 8 / 全部 8", "显示数量应为8/8")
	for entry: Array in [[1, 2], [2, 1], [3, 5], [0, 8]]:
		plugin.category_filter.select(entry[0])
		plugin.category_filter.item_selected.emit(entry[0])
		_expect(plugin.resource_list.item_count == entry[1], "分类筛选数量错误：选项%d" % entry[0])
	plugin.tag_filter.text = "meat"
	plugin.tag_filter.text_changed.emit("meat")
	_expect(plugin.resource_list.item_count == 1, "全部分类仍应支持标签筛选")
	plugin.tag_filter.text = ""
	plugin.tag_filter.text_changed.emit("")
	_expect(plugin.resource_list.item_count == 8, "清除标签后应恢复全部8种")
	plugin.free()
	parent.queue_free()
	await process_frame
	print("RESOURCE_CATEGORY_FILTER_TEST=", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)
