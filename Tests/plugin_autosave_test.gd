extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _read(path: String) -> Resource:
	return ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)

func _find_script(node: Node, path: String) -> Node:
	if node.get_script() != null and node.get_script().resource_path == path: return node
	for child in node.get_children():
		var result := _find_script(child, path)
		if result != null: return result
	return null

func _run() -> void:
	await create_timer(5.0).timeout
	var original_root := EditorInterface.get_edited_scene_root()
	var original_scene := original_root.scene_file_path if original_root != null else ""
	var building: Control = load("res://addons/resource_editor/building_editor_panel.gd").new()
	building.autosave.enabled = false
	root.add_child(building)
	for index in range(building.buildings.size()):
		if building.buildings[index].id == &"base": building.select_building(index)
	var scene_path := "res://.godot/autosave_building_scene.tscn"
	assert(ResourceSaver.save(building.current.building_scene.duplicate(), scene_path) == OK)
	building.current.building_scene = load(scene_path)
	building.data_path = "res://.godot/autosave_building.tres"
	assert(ResourceSaver.save(building.current, building.data_path) == OK)
	building._load_scene()
	await process_frame
	await process_frame
	building.autosave.enabled = true
	building.current.surface_drying_strength = 0.72
	building.inspector.property_edited.emit("surface_drying_strength")
	var field: SpinBox = building.field_controls[".:base_housing_capacity"]
	field.value = 9
	await create_timer(0.7).timeout
	assert(_read(building.data_path).surface_drying_strength == 0.72)
	var packed: PackedScene = _read(scene_path)
	var restored := packed.instantiate()
	assert(restored.base_housing_capacity == 9)
	restored.free()
	building.current.surface_drying_strength = 0.61
	building.inspector.property_edited.emit("surface_drying_strength")
	building.select_building(0)
	assert(_read("res://.godot/autosave_building.tres").surface_drying_strength == 0.61, "切换之前补保存")
	building.autosave.enabled = false
	building.queue_free()
	var unit: Control = load("res://addons/resource_editor/unit_editor_panel.gd").new()
	unit.autosave.enabled = false
	root.add_child(unit)
	unit.data_path = "res://.godot/autosave_unit.tres"
	unit.autosave.enabled = true
	unit.current.max_health = 456
	unit.inspector.property_edited.emit("max_health")
	await create_timer(0.7).timeout
	assert(_read(unit.data_path).max_health == 456)
	unit.queue_free()
	var pool := load("res://data/names/HumanNames.tres").duplicate(true)
	var pool_path := "res://.godot/autosave_names.tres"
	assert(ResourceSaver.save(pool, pool_path) == OK)
	var names: Control = load("res://addons/resource_editor/name_editor_panel.gd").new()
	root.add_child(names)
	names.edit_pool(pool_path)
	names.fields["given_names"].text = "自动保存测试甲\n自动保存测试乙"
	names.fields["given_names"].text_changed.emit()
	await create_timer(0.7).timeout
	assert(_read(pool_path).given_names.has("自动保存测试甲"))
	names.queue_free()
	var resource_plugin = _find_script(root, "res://addons/resource_editor/resource_editor_plugin.gd")
	assert(resource_plugin != null)
	var resource := ResourceData.new()
	resource.id = &"autosave_test"
	resource.display_name = "测试资源"
	var resource_path := "res://.godot/autosave_resource.tres"
	assert(ResourceSaver.save(resource, resource_path) == OK)
	resource_plugin._load_resource(load(resource_path))
	resource_plugin.name_edit.text = "资源自动保存测试"
	resource_plugin.name_edit.text_changed.emit(resource_plugin.name_edit.text)
	await create_timer(0.7).timeout
	assert(_read(resource_path).display_name == "资源自动保存测试")
	var trait_plugin = _find_script(root, "res://addons/trait_editor/trait_editor_plugin.gd")
	assert(trait_plugin != null)
	var trait_data := TraitData.new()
	trait_data.trait_name = "测试特性"
	var trait_path := "res://.godot/autosave_trait.tres"
	assert(ResourceSaver.save(trait_data, trait_path) == OK)
	trait_plugin._load_trait_into_editor(load(trait_path))
	trait_plugin.name_edit.text = "特性自动保存测试"
	trait_plugin.name_edit.text_changed.emit(trait_plugin.name_edit.text)
	await create_timer(0.7).timeout
	assert(_read(trait_path).trait_name == "特性自动保存测试")
	var raid: Control = load("res://addons/resource_editor/raid_editor_panel.gd").new()
	raid.autosave.enabled = false
	root.add_child(raid)
	raid.preset_path = "res://.godot/autosave_level.tres"
	raid.database = raid.database.duplicate(true)
	assert(ResourceSaver.save(raid.database, "res://.godot/autosave_database.tres") == OK)
	raid.database = load("res://.godot/autosave_database.tres")
	raid.level_flow = raid.level_flow.duplicate(true)
	# 隔离引用的营地资源，测试只写 .godot。
	var original_camps: CampSpawnConfig = raid.level_flow.camp_config
	raid.level_flow.camp_config = original_camps.duplicate(true)
	var isolated_pool: Array[CampPoolEntry] = []
	raid.level_flow.camp_config.camp_pool = isolated_pool
	for entry in original_camps.camp_pool:
		var isolated_entry = entry.duplicate(true)
		isolated_entry.camp = entry.camp.duplicate(true)
		isolated_entry.resource_path = ""
		isolated_entry.camp.resource_path = ""
		raid.level_flow.camp_config.camp_pool.append(isolated_entry)
	raid.level_flow.camp_config.resource_path = ""
	raid.level_flow.monster_database = raid.database
	assert(ResourceSaver.save(raid.level_flow, raid.preset_path) == OK)
	raid._load_resources()
	raid.autosave.enabled = true
	raid.environment_panel.seed_spin.value = 987
	var moisture_entry: MapResourceEntry = raid.environment_panel.resource_inspector.get_edited_object()
	moisture_entry.moisture_min = 0.5
	moisture_entry.moisture_max = 0.9
	moisture_entry.moisture_outside_probability = 0.1
	raid.environment_panel.resource_inspector.property_edited.emit("moisture_min")
	await create_timer(0.7).timeout
	assert(_read(raid.preset_path).layout_seed == 987)
	assert(_read(raid.preset_path).map_resources[0].moisture_min == 0.5 and _read(raid.preset_path).map_resources[0].moisture_max == 0.9)
	assert(_read(raid.preset_path).map_resources[0].moisture_outside_probability == 0.1)
	raid.queue_free()
	await process_frame
	# 验证主检查器中独立材质和插件节点参数的实际写入。
	var material_path := "res://.godot/autosave_material.tres"
	assert(ResourceSaver.save(StandardMaterial3D.new(), material_path) == OK)
	var material = load(material_path)
	EditorInterface.edit_resource(material)
	for frame in range(120):
		if EditorInterface.get_inspector().get_edited_object() == material: break
		await process_frame
	assert(EditorInterface.get_inspector().get_edited_object() == material)
	material.albedo_color = Color(0.2, 0.3, 0.4)
	EditorInterface.get_inspector().property_edited.emit("albedo_color")
	await create_timer(0.7).timeout
	assert(_read(material_path).albedo_color.is_equal_approx(material.albedo_color))
	var scene := Node3D.new()
	scene.name = "AutosavePluginScene"
	scene.set_script(load("res://addons/stylized_day_night/stylized_day_night.gd"))
	var scene_file := PackedScene.new()
	assert(scene_file.pack(scene) == OK)
	var plugin_scene_path := "res://.godot/autosave_plugin_scene.tscn"
	assert(ResourceSaver.save(scene_file, plugin_scene_path) == OK)
	scene.free()
	EditorInterface.open_scene_from_path(plugin_scene_path)
	await create_timer(1.0).timeout
	var edited := EditorInterface.get_edited_scene_root()
	assert(edited.scene_file_path == plugin_scene_path)
	EditorInterface.edit_node(edited)
	for frame in range(120):
		if EditorInterface.get_inspector().get_edited_object() == edited: break
		await process_frame
	assert(EditorInterface.get_inspector().get_edited_object() == edited)
	edited.name = "ChangedPluginScene"
	EditorInterface.get_inspector().property_edited.emit("name")
	await create_timer(0.7).timeout
	var saved_scene: PackedScene = _read(plugin_scene_path)
	var saved_node := saved_scene.instantiate()
	assert(saved_node.name == "ChangedPluginScene")
	saved_node.free()
	if not original_scene.is_empty(): EditorInterface.open_scene_from_path(original_scene)
	assert(not resource_plugin.save_button.visible)
	assert(not trait_plugin.save_button.visible)
	print("插件自动保存通过：建筑与专属场景、切换补保存、单位、名称池、资源、特性、关卡、主检查器资源及插件场景；所有测试写入均隔离")
	quit()
