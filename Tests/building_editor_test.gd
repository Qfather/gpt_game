extends SceneTree
func _init() -> void:
	call_deferred("_schedule")
func _schedule() -> void:
	create_timer(5).timeout.connect(_run)
func _run() -> void:
	print("建筑编辑器：开始验证")
	var panel: Control = load("res://addons/resource_editor/building_editor_panel.gd").new()
	var background := PanelContainer.new()
	root.add_child(background)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.16, 0.16, 0.16)
	background.add_theme_stylebox_override("panel", style)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await process_frame
	if "--preview-only" in OS.get_cmdline_user_args():
		root.size = Vector2i(1440, 900)
		panel.category_tabs.current_tab = BuildingData.Category.ROAD
		for frame: int in range(5): await process_frame
		RenderingServer.force_draw(false)
		assert(root.get_texture().get_image().save_png("res://.godot/building_editor_road_preview.png") == OK)
		panel.category_tabs.current_tab = BuildingData.Category.PRODUCTION
		for frame: int in range(5): await process_frame
		RenderingServer.force_draw(false)
		assert(root.get_texture().get_image().save_png("res://.godot/building_editor_category_preview.png") == OK)
		print("建筑编辑器分类与道路界面截图通过")
		background.queue_free()
		await process_frame
		quit()
		return
	assert(panel.buildings.size() == 15)
	assert(panel.category_tabs.tab_count == 5)
	assert(load("res://data/buildings/ArcherCampData.tres").category == BuildingData.Category.MILITARY)
	assert(load("res://data/buildings/TorchData.tres").category == BuildingData.Category.STRATEGY)
	assert(load("res://data/buildings/HouseData.tres").sort_id == 50)
	for index: int in range(panel.buildings.size()):
		panel.select_building(index)
		print("建筑编辑器：预览 ", panel.current.id)
		if panel.current.road_kind > 0:
			assert(panel.current.category == BuildingData.Category.ROAD and panel.preview.mesh_count == 1)
			assert(panel.current.construction_time == (3.0 if panel.current.road_kind == 1 else 5.0))
			var road_copy: BuildingData = panel.current.duplicate(true)
			assert(ResourceSaver.save(road_copy, "res://.godot/building_editor_road.tres") == OK)
			panel.data_path = "res://.godot/building_editor_road.tres"
			panel.current.construction_time = 7.0
			assert(panel.save_current())
			var saved_road: BuildingData = ResourceLoader.load(panel.data_path, "", ResourceLoader.CACHE_MODE_IGNORE)
			assert(saved_road.construction_time == 7.0)
			continue
		assert(panel.scene_root != null)
		assert(panel.preview.mesh_count > 0)
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			assert(panel.preview.viewport.get_texture().get_image().save_png("res://.godot/building_model_" + String(panel.current.id) + ".png") == OK)
		assert(panel.current.armor == 1.0 and panel.current.function_text.is_empty())
		assert(not panel.current.building_scene.resource_path.is_empty())
		assert(panel.scene_root.is_inside_tree() == false)
		var roundtrip: PackedScene = panel.current.building_scene.duplicate()
		assert(roundtrip.pack(panel.scene_root) == OK)
		var restored_root: Node = roundtrip.instantiate()
		assert(_node_count(restored_root) == _node_count(panel.scene_root))
		for field_key: String in panel.field_controls:
			var parts: PackedStringArray = field_key.split(":")
			assert(restored_root.get_node(NodePath(parts[0])).get(parts[1]) == panel.scene_root.get_node(NodePath(parts[0])).get(parts[1]))
		restored_root.free()
		if panel.current.id == &"house":
			assert(panel.field_controls.has(".:housing_capacity"))
		if panel.current.id == &"farm":
			assert(panel.field_controls.has(".:grain_yield") and panel.field_controls.has("FieldA:grow_time"))
		if panel.current.id == &"base":
			assert(panel.field_controls.has(".:base_housing_capacity") and not panel.field_controls.has("BuildingDurability:max_health"))
	var data: BuildingData = load("res://data/buildings/HouseData.tres")
	var original_cost: Dictionary = data.construction_cost.duplicate()
	print("建筑编辑器：开始隔离保存测试")
	var packed: PackedScene = data.building_scene.duplicate()
	assert(ResourceSaver.save(packed, "res://.godot/building_editor_house.tscn") == OK)
	var copy: BuildingData = data.duplicate(true)
	copy.building_scene = load("res://.godot/building_editor_house.tscn")
	assert(ResourceSaver.save(copy, "res://.godot/building_editor_house.tres") == OK)
	panel.buildings.append(load("res://.godot/building_editor_house.tres"))
	panel.select_building(panel.buildings.size() - 1)
	var model_root := Node3D.new()
	model_root.name = "测试外观"
	var mesh := MeshInstance3D.new()
	mesh.name = "网格"
	mesh.mesh = BoxMesh.new()
	model_root.add_child(mesh)
	mesh.owner = model_root
	var visual := PackedScene.new()
	assert(visual.pack(model_root) == OK)
	assert(ResourceSaver.save(visual, "res://.godot/building_editor_model.tscn") == OK)
	model_root.free()
	panel.model_picker.resource_changed.emit(load("res://.godot/building_editor_model.tscn"))
	assert(panel.preview.mesh_count == 1)
	panel.current.max_health = 450.0
	panel.current.armor = 1.0
	panel.storage_fields.get_child(panel.storage_fields.get_child_count() - 1).pressed.emit()
	var row: HBoxContainer = panel.storage_fields.get_child(1)
	var options: OptionButton = row.get_child(0)
	for index: int in range(options.item_count):
		if options.get_item_metadata(index) == &"meat":
			options.select(index)
			options.item_selected.emit(index)
			break
	row = panel.storage_fields.get_child(1)
	row.get_child(1).value = 10.0
	assert(panel.current.storage_capacities == {&"meat": 10.0})
	panel.current.construction_time = 19.0
	panel.current.category = BuildingData.Category.PROCESSING
	panel.current.sort_id = 123
	panel.inspector.property_edited.emit("category")
	print("建筑编辑器：已修改分类")
	assert(panel.current.category == BuildingData.Category.PROCESSING and panel.category_tabs.current_tab == 4)
	panel.current.construction_cost[&"wood"] = 55.0
	panel.field_controls[".:housing_capacity"].value = 7
	panel.current.construction_cost[&"wood"] = -1.0
	assert(not panel.save_current())
	panel.current.construction_cost[&"wood"] = 55.0
	assert(panel.save_current())
	print("建筑编辑器：已保存分类及排序")
	var saved: BuildingData = ResourceLoader.load("res://.godot/building_editor_house.tres", "", ResourceLoader.CACHE_MODE_IGNORE_DEEP)
	assert(saved.max_health == 450.0 and saved.armor == 1.0 and saved.storage_capacities[&"meat"] == 10.0 and saved.model_scene != null)
	assert(saved.construction_time == 19 and saved.construction_cost[&"wood"] == 55)
	assert(saved.category == BuildingData.Category.PROCESSING and saved.sort_id == 123)
	var house: Node = saved.building_scene.instantiate()
	assert(house.housing_capacity == 7)
	house.free()
	var original_house: Node = data.building_scene.instantiate()
	assert(original_house.housing_capacity == 3)
	original_house.free()
	assert(data.construction_cost == original_cost)
	if DisplayServer.get_name() != "headless":
		root.size = Vector2i(1440, 900)
		panel.get_child(1).get_child(1).current_tab = 2
		for frame: int in range(5): await process_frame
		RenderingServer.force_draw(false)
		root.get_texture().get_image().save_png("res://.godot/building_editor_preview.png")
		for index: int in range(panel.buildings.size()):
			if panel.buildings[index].id == &"base":
				panel.select_building(index)
				break
		panel.get_child(1).get_child(1).current_tab = 0
		for frame: int in range(5): await process_frame
		RenderingServer.force_draw(false)
		_check_labels(panel.inspector)
		root.get_texture().get_image().save_png("res://.godot/building_editor_base_preview.png")
	background.queue_free()
	await process_frame
	print("建筑编辑器测试通过：15种建筑与道路预览、分类排序、施工配置、隔离保存读回")
	quit()

func _node_count(node: Node) -> int:
	var count: int = 1
	for child: Node in node.get_children(): count += _node_count(child)
	return count

func _check_labels(node: Node) -> void:
	if node is EditorProperty:
		if node.get_edited_property() == &"max_health":
			assert(node.label == "建筑血量")
		if node.get_edited_property() == &"armor":
			assert(node.label == "护甲")
	for child: Node in node.get_children(true): _check_labels(child)
