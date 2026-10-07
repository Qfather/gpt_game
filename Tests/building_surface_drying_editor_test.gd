extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	await create_timer(5.0).timeout
	var panel: Control = load("res://addons/resource_editor/building_editor_panel.gd").new()
	root.add_child(panel)
	var index := 0
	for i in range(panel.buildings.size()):
		var data: BuildingData = panel.buildings[i]
		assert(data.surface_drying_enabled)
		assert(data.surface_drying_strength == 0.35 and data.surface_drying_range == 2.0 and data.surface_drying_noise == 0.3)
		if data.id == &"house": index = i
	panel.select_building(index)
	await process_frame
	await panel._translate_labels()
	var found := {}
	_check_properties(panel.inspector, found)
	assert(found.size() == 4, "建筑设置应显示全部四项干燥参数")
	var copy: BuildingData = panel.current.duplicate(true)
	copy.surface_drying_strength = 0.6
	copy.surface_drying_range = 4.5
	copy.surface_drying_noise = 0.45
	assert(ResourceSaver.save(copy, "res://.godot/building_drying_settings.tres") == OK)
	var saved: BuildingData = ResourceLoader.load("res://.godot/building_drying_settings.tres", "", ResourceLoader.CACHE_MODE_IGNORE)
	assert(saved.surface_drying_strength == 0.6 and saved.surface_drying_range == 4.5 and saved.surface_drying_noise == 0.45)
	panel.queue_free()
	await process_frame
	print("建筑干燥设置通过：全部现有建筑默认值、四项中文参数、隔离保存读回")
	quit()

func _check_properties(node: Node, found: Dictionary) -> void:
	if node is EditorProperty:
		var property: String = node.get_edited_property()
		if property.begins_with("surface_drying_"):
			assert(node.label == load("res://addons/resource_editor/building_editor_panel.gd").LABELS[property])
			found[property] = true
	for child in node.get_children(true):
		_check_properties(child, found)
