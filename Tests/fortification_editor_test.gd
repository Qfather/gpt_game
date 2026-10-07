extends SceneTree

var failed: bool = false

func _initialize() -> void:
	call_deferred("_run")

func _expect(value: bool, message: String) -> void:
	print("[", "通过" if value else "失败", "] ", message)
	if not value:
		failed = true
		push_error(message)

func _properties(node: Node, result: Dictionary) -> void:
	if node is EditorProperty: result[node.get_edited_property()] = node
	for child: Node in node.get_children(true): _properties(child, result)

func _run() -> void:
	await create_timer(3).timeout
	var panel: Control = load("res://addons/resource_editor/building_editor_panel.gd").new()
	panel.autosave.enabled = false
	root.add_child(panel)
	for index: int in range(panel.buildings.size()):
		panel.select_building(index)
		if panel.current.is_wall():
			await create_timer(0.3).timeout
			var properties: Dictionary = {}
			_properties(panel.inspector, properties)
			for key: String in ["wall_scene_isolated", "wall_scene_end", "wall_scene_straight", "wall_scene_corner", "wall_scene_t", "wall_scene_cross"]:
				_expect(properties.has(key) and properties[key].label == panel.LABELS[key], "城墙六种场景引用可见并中文显示：" + key)
			_expect(not panel.model_picker.visible and panel.preview.mesh_count > 0, "城墙使用形态场景预览并隐藏单一外观模型")
		elif panel.current.is_wall_tower():
			_expect(panel.field_controls.has(".:resupply_trigger") and not panel.field_controls.has(".:patrol_point_reach_radius"), "塔楼保留军粮并隐藏巡逻参数")
			for property: Dictionary in panel.current.get_property_list():
				if property.name == "garrison_capacity": _expect(property.hint_string == "0,1,1", "塔楼驻军字段限制为一人")
	var original: BuildingData = load("res://data/buildings/WallData.tres")
	var copy: BuildingData = original.duplicate(true)
	var data_path: String = "res://.godot/fortification_editor_wall.tres"
	ResourceSaver.save(copy, data_path)
	panel.buildings.append(load(data_path))
	panel.select_building(panel.buildings.size() - 1)
	var model := Node3D.new()
	model.name = "CustomWallModel"
	var mesh := MeshInstance3D.new()
	mesh.name = "Mesh"
	mesh.mesh = BoxMesh.new()
	model.add_child(mesh)
	mesh.owner = model
	var packed := PackedScene.new()
	packed.pack(model)
	ResourceSaver.save(packed, "res://.godot/fortification_custom_model.tscn")
	model.free()
	var replacement: PackedScene = load("res://.godot/fortification_custom_model.tscn")
	panel.current.wall_scene_isolated = replacement
	panel.inspector.property_edited.emit("wall_scene_isolated")
	_expect(panel.preview.mesh_count == 1, "替换墙段场景后预览立即刷新")
	panel.autosave.enabled = true
	panel.inspector.property_edited.emit("wall_scene_isolated")
	await create_timer(0.7).timeout
	var saved: BuildingData = ResourceLoader.load(data_path, "", ResourceLoader.CACHE_MODE_IGNORE)
	_expect(saved.wall_scene_isolated.resource_path == replacement.resource_path and saved.wall_scene_cross != null, "形态场景引用自动保存读回")
	_expect(original.wall_scene_isolated.resource_path.begins_with("res://Scene/"), "隔离替换未修改正式预设")
	panel.autosave.enabled = false
	panel.current.grid_size = Vector2i(2, 1)
	_expect(not panel.save_current(), "拒绝破坏逐格连接的城墙占地")
	panel.current.grid_size = Vector2i.ONE
	panel.current.wall_scene_cross = null
	_expect(not panel.save_current(), "拒绝缺少形态场景的墙配置")
	panel.autosave.cancel()
	panel.queue_free()
	await process_frame
	print("城墙编辑器场景引用测试", "失败" if failed else "通过")
	quit(1 if failed else 0)
