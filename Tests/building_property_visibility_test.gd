extends SceneTree

var failed: bool = false

func _initialize() -> void:
	call_deferred("_run")

func _expect(condition: bool, message: String) -> void:
	print("[", "通过" if condition else "失败", "] ", message)
	if not condition:
		failed = true
		push_error(message)

func _visible(data: BuildingData, key: String) -> bool:
	for property: Dictionary in data.get_property_list():
		if property.name == key: return bool(property.usage & PROPERTY_USAGE_EDITOR)
	return false

func _properties(node: Node, result: Dictionary) -> void:
	if node is EditorProperty: result[node.get_edited_property()] = node
	for child: Node in node.get_children(true): _properties(child, result)

func _run() -> void:
	await create_timer(3).timeout
	var panel: Control = load("res://addons/resource_editor/building_editor_panel.gd").new()
	panel.autosave.enabled = false
	var background := PanelContainer.new()
	root.add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.16, 0.16, 0.16)
	background.add_theme_stylebox_override("panel", style)
	background.add_child(panel)
	for index: int in range(panel.buildings.size()):
		panel.select_building(index)
		var data: BuildingData = panel.current
		if data.road_kind > 0:
			for key: String in ["road_kind", "category", "building_scene", "max_health", "armor", "grid_size", "surface_drying_enabled", "training_cost", "max_construction_workers", "allow_rotation", "allow_mirror", "garrison_capacity"]:
				_expect(not _visible(data, key), "道路隐藏" + key)
			_expect(panel.tabs.is_tab_hidden(1) and panel.tabs.is_tab_hidden(2) and not panel.model_picker.visible and not panel.model_label.visible and panel.field_controls.is_empty(), "道路隐藏专属、仓储与模型控件")
			_expect(_visible(data, "construction_cost") and _visible(data, "construction_time") and _visible(data, "road_material") and _visible(data, "road_texture_cross"), "道路保留施工与材质参数")
		else:
			_expect(not _visible(data, "road_speed_mode") and not _visible(data, "road_material"), "普通建筑隐藏道路参数：" + String(data.id))
			_expect(not panel.tabs.is_tab_hidden(1) and not panel.tabs.is_tab_hidden(2) and panel.model_picker.visible == (not data.is_wall()), "切回建筑恢复适用模型和参数页：" + String(data.id))
			_expect(_visible(data, "garrison_capacity") == (data.id in [&"barracks", &"arrow_tower"] or data.is_wall_tower()), "驻军容量按功能显示：" + String(data.id))
			_expect(_visible(data, "training_cost") == (data.id in [&"swordsman_camp", &"archer_camp"]), "训练成本按功能显示：" + String(data.id))
			data.surface_drying_enabled = false
			_expect(not _visible(data, "surface_drying_range") and _visible(data, "surface_drying_enabled"), "关闭干燥隐藏下方参数：" + String(data.id))
			data.surface_drying_enabled = true
			_expect(_visible(data, "surface_drying_range"), "启用干燥恢复下方参数：" + String(data.id))
		if data.id == &"base":
			for key: String in ["sort_id", "construction_cost", "construction_time", "max_construction_workers"]: _expect(not _visible(data, key), "据点隐藏" + key)
			_expect(_visible(data, "grid_size") and panel.field_controls.has(".:base_housing_capacity"), "据点保留占地与人口")
		if data.id == &"arrow_tower":
			_expect(not panel.field_controls.has(".:patrol_point_reach_radius") and panel.field_controls.has(".:resupply_trigger"), "箭塔隐藏巡逻距离并保留补粮阈值")
			for property: Dictionary in data.get_property_list():
				if property.name == "garrison_capacity": _expect(property.hint_string == "0,2,1", "箭塔容量控件上限2")
	panel.category_tabs.current_tab = BuildingData.Category.ROAD
	for index: int in range(panel.buildings.size()):
		if panel.buildings[index].road_kind == 1: panel.select_building(index); break
	# 模式切换通过 setter 重建 Inspector，不依赖储存按钮。
	for mode: int in [0, 1, 0]:
		panel.current.road_speed_mode = mode
		panel.inspector.property_edited.emit("road_speed_mode")
		await create_timer(0.4).timeout
		var properties: Dictionary = {}
		_properties(panel.inspector, properties)
		var key: String = "road_speed_add" if mode == 0 else "road_speed_percent"
		var hidden: String = "road_speed_percent" if mode == 0 else "road_speed_add"
		_expect(properties.has(key) and not properties.has(hidden), "切换加速模式立即更新可见字段%d" % mode)
		_expect(properties.has(key) and properties[key].label == ("移速增加" if mode == 0 else "移速增加比例"), "切换加速模式立即更新中文标签%d" % mode)
		if DisplayServer.get_name() != "headless":
			root.size = Vector2i(1440, 1000)
			RenderingServer.force_draw(false)
			root.get_texture().get_image().save_png("res://.godot/building_road_mode_%d.png" % mode)
	panel.data_path = "res://.godot/road_editor_configuration.tres"
	_expect(ResourceSaver.save(panel.current, panel.data_path) == OK, "创建隔离道路配置")
	panel.autosave.enabled = true
	panel.current.road_speed_add = 2
	panel.inspector.property_edited.emit("road_speed_add")
	await create_timer(0.7).timeout
	var saved: BuildingData = ResourceLoader.load(panel.data_path, "", ResourceLoader.CACHE_MODE_IGNORE)
	_expect(saved.road_speed_mode == 0 and saved.road_speed_add == 2, "道路加速配置自动保存读回")
	panel.autosave.enabled = false
	panel.current.road_speed_add = -1
	_expect(not panel.save_current(), "拒绝负道路加速值")
	panel.autosave.cancel()
	background.queue_free()
	await create_timer(0.5).timeout
	print("建筑属性可见性测试", "失败" if failed else "通过")
	quit(1 if failed else 0)
