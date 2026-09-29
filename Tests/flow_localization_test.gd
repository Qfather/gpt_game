extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var factory := FlowNodesFactory.new()
	for template_name in ["add_attribute", "math_op", "create_points", "point_offsets"]:
		factory.registerNodeType(template_name, template_name + ".gd")
	assert(factory.node_types.size() == 4)
	for template_name: String in factory.node_types:
		var meta: Dictionary = factory.node_types[template_name]
		assert(meta.title == FlowLocale.NODE_TITLES[template_name], template_name)
		assert(meta.category in FlowLocale.CATEGORIES.values(), template_name)
	var popup: SearchAddNodePopup = load("res://addons/flow_nodes_editor/search_add_node_popup.tscn").instantiate()
	root.add_child(popup)
	popup.setup(factory.node_types, [], [], FlowData.DataType.Invalid, FlowData.DataType.Invalid)
	for category_name in ["属性", "数学", "空间"]:
		assert(popup.category_buttons.has(category_name), category_name)
		popup._show_category(category_name)
		for button: Button in popup.search_results.get_children():
			assert(button.text in FlowLocale.NODE_TITLES.values(), button.text)
	for frame in 120:
		if FlowPlugin.get_instance() != null:
			break
		await process_frame
	var plugin := FlowPlugin.get_instance()
	assert(plugin != null)
	var node: FlowNodeBase = factory.createNewNode("add_attribute", "test")
	var inspector := EditorInspector.new()
	root.add_child(inspector)
	inspector.edit(node)
	await process_frame
	assert(_find_property_label(inspector, "random_seed") == "随机种子")
	assert(_find_property_label(inspector, "debug_enabled") == "启用调试")
	assert(_find_property_label(inspector, "attr_name") == "属性名称")
	inspector.edit(factory.createNewNode("point_offsets", "array_test"))
	await process_frame
	assert(_find_property_label(inspector, "offsets") == "偏移量")
	print("流程节点汉化测试通过：属性／数学／空间子列表及节点检查器")
	popup.queue_free()
	inspector.queue_free()
	await process_frame
	quit()


func _find_property_label(parent: Node, property_name: StringName) -> String:
	if parent is EditorProperty and (parent as EditorProperty).get_edited_property() == property_name:
		return (parent as EditorProperty).label
	for child in parent.get_children():
		var label := _find_property_label(child, property_name)
		if not label.is_empty():
			return label
	return ""
