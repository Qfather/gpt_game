@tool
extends HSplitContainer

var wildlife_inspector: EditorInspector

var preset: LevelFlowData
var map_inspector: EditorInspector
var resource_inspector: EditorInspector
var resource_list: ItemList
var seed_spin: SpinBox
var rift_distance_spin: SpinBox
var fog_toggle: CheckBox
var settlement_fields: Array[Dictionary] = []
var immigration_list: ItemList
var immigration_inspector: EditorInspector
const LABELS: Dictionary = {
	"maximum_animals": "猎物总数量上限", "refresh_interval": "补充间隔（秒）", "minimum_base_distance": "距据点最小距离（米）",
	"maximum_base_distance": "距据点最大距离（米）", "prey_pool": "猎物随机池", "health": "生命值", "meat_yield": "出肉数量", "flee_speed": "逃跑速度",
	"map_size": "地图格数", "cell_size_m": "单格尺寸（米）", "seed_value": "地形种子",
	"island_ratio_percent": "岛屿占比（%）", "protrusion_percent": "轮廓突出程度（%）",
	"remove_region_below": "移除小区域阈值", "lobe_count": "岛屿分叶数",
	"center_clear_size": "中心平地大小", "center_clear_circle": "圆形中心平地",
	"link_expansion_rounds": "连接扩展轮数", "lake_count": "湖泊数量",
	"lake_size_percent": "湖泊大小（%）", "lake_protrusion_percent": "湖泊突出程度（%）",
	"allowed_height_layers": "允许高台层数", "highland_ratio_percent": "高地占比（%）",
	"height_level_weights": "各海拔层权重", "high_stairs": "高阶梯", "model_library": "地图模型库",
	"enabled": "启用生成", "display_name": "名称", "scene": "资源场景", "distribution": "分布模式",
	"count": "总数量", "nearby_ratio": "据点附近比例", "minimum_spacing": "最小边缘留空",
	"neighbor_distance_max": "簇内最大边缘留空", "cluster_size": "每簇数量上限",
	"cluster_radius": "簇半径／树林影响半径", "cluster_separation": "簇中心间距（树林远处）",
	"scattered_weight": "树林零散权重", "near_distance_min": "近处最小距离",
	"near_distance_max": "近处最大距离", "far_distance_min": "远处最小距离",
	"base_weight": "基础权重", "altitude_weight": "每层海拔权重增量",
	"cliff_foot_bonus": "崖脚权重加成", "cliff_top_bonus": "崖顶权重加成",
	"unlock_population": "阶段起始人口（当前人口）", "weight": "抽取权重",
	"food_tag": "食物标签（空表示任意食物）", "food_amount": "所需食物库存",
	"required_buildings": "必须已建成的建筑", "min_group_size": "每批最少人数",
	"max_group_size": "每批最多人数", "arrival_interval": "到达间隔（秒）",
	"resident_traits": "居民必带标签", "trait_data": "标签配置", "level": "标签等级",
	"preferred_food_tags": "喜欢的食物标签", "preferred_nutrition_multiplier": "喜欢食物的饱腹倍率",
	"preferred_hunger_multiplier": "进食后饥饿速度倍率", "preferred_effect_duration": "效果持续时间（秒）",
}


func _init() -> void:
	custom_minimum_size.y = 420
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	var map_column := VBoxContainer.new()
	map_column.custom_minimum_size.x = 350
	add_child(map_column)
	var title := Label.new()
	title.text = "地图生成配置（保存到当前关卡预设）"
	map_column.add_child(title)
	fog_toggle = CheckBox.new()
	fog_toggle.text = "启用战争迷雾"
	fog_toggle.toggled.connect(func(value: bool) -> void:
		if preset != null:
			preset.fog_of_war_enabled = value
	)
	map_column.add_child(fog_toggle)
	var seed_label := Label.new()
	seed_label.text = "据点/资源布局种子（-1 每局随机）"
	map_column.add_child(seed_label)
	seed_spin = SpinBox.new()
	seed_spin.min_value = -1
	seed_spin.max_value = 2147483647
	seed_spin.value_changed.connect(func(value: float) -> void:
		if preset != null:
			preset.layout_seed = int(value)
	)
	map_column.add_child(seed_spin)
	var rift_label := Label.new()
	rift_label.text = "裂缝距据点最小距离（米）"
	map_column.add_child(rift_label)
	rift_distance_spin = SpinBox.new()
	rift_distance_spin.max_value = 200
	rift_distance_spin.value_changed.connect(func(value: float) -> void:
		if preset != null:
			preset.rift_min_base_distance = value
	)
	map_column.add_child(rift_distance_spin)
	map_inspector = EditorInspector.new()
	map_inspector.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map_column.add_child(map_inspector)
	var resource_column := VBoxContainer.new()
	resource_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var resource_tabs := TabContainer.new()
	resource_tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(resource_tabs)
	resource_column.name = "地图资源"
	resource_tabs.add_child(resource_column)
	var wildlife_column := VBoxContainer.new()
	wildlife_column.name = "猎物与刷新"
	resource_tabs.add_child(wildlife_column)
	var wildlife_help := Label.new()
	wildlife_help.text = "猎物池归当前关卡管理；展开资源可设置模型、生命、出肉量、逃跑速度和权重。"
	wildlife_help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	wildlife_column.add_child(wildlife_help)
	wildlife_inspector = EditorInspector.new()
	wildlife_inspector.size_flags_vertical = Control.SIZE_EXPAND_FILL
	wildlife_column.add_child(wildlife_inspector)
	wildlife_inspector.property_edited.connect(func(_property: String) -> void: call_deferred("_translate_labels"))
	var settlement_scroll := ScrollContainer.new()
	settlement_scroll.name = "初始资源与人口"
	resource_tabs.add_child(settlement_scroll)
	var settlement_column := VBoxContainer.new()
	settlement_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	settlement_scroll.add_child(settlement_column)
	for section: Dictionary in [
		{"title": "初始资源", "rules": false, "fields": {"initial_wood": "木材", "initial_stone": "石头", "initial_grain": "粮食"}},
		{"title": "初始居民", "rules": false, "fields": {"initial_villagers": "居民人数"}},
		{"title": "人口与移民规则", "rules": true, "fields": {"minimum_food_reserve": "最低粮食储备", "food_per_migrant": "每名移民所需粮食", "required_free_housing": "所需空余住房", "arrival_interval": "移民到达间隔（秒）", "min_group_size": "每批最少人数", "max_group_size": "每批最多人数"}},
	]:
		var section_title := Label.new()
		section_title.text = section.title
		settlement_column.add_child(section_title)
		for key: String in section.fields:
			var row := HBoxContainer.new()
			settlement_column.add_child(row)
			var label := Label.new()
			label.text = section.fields[key]
			label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(label)
			var spin := SpinBox.new()
			spin.max_value = 1000000
			spin.step = 1.0 if key in ["initial_villagers", "required_free_housing", "min_group_size", "max_group_size"] else 0.1
			spin.custom_minimum_size.x = 130
			row.add_child(spin)
			var uses_rules: bool = section.rules
			spin.value_changed.connect(func(value: float) -> void:
				if preset != null:
					var config: Resource = preset.settlement_config.immigration_rules if uses_rules else preset.settlement_config
					config.set(key, int(value) if spin.step == 1.0 else value)
			)
			settlement_fields.append({"key": key, "rules": uses_rules, "spin": spin})
	var immigration_column := VBoxContainer.new()
	immigration_column.name = "移民需求池"
	resource_tabs.add_child(immigration_column)
	var immigration_help := Label.new()
	immigration_help.text = "按当前人口使用对应阶段，人口跨阶段时自动更新，同阶段按权重抽取。刷新冷却60秒游戏时间。\n食物标签检查库存，不额外扣除；来者携带本组标签。建议每阶段保留容易满足的组。\n空池使用初始资源与人口页的固定规则。"
	immigration_help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	immigration_column.add_child(immigration_help)
	var immigration_toolbar := HBoxContainer.new()
	immigration_column.add_child(immigration_toolbar)
	for action: String in ["添加移民组", "移除选中组"]:
		var button := Button.new()
		button.text = action
		immigration_toolbar.add_child(button)
		button.pressed.connect(func() -> void:
			var groups: Array[ImmigrationGroup] = preset.settlement_config.immigration_rules.groups
			if action == "添加移民组":
				groups.append(ImmigrationGroup.new())
				_refresh_immigration_list(groups.size() - 1)
			else:
				var selected: PackedInt32Array = immigration_list.get_selected_items()
				if not selected.is_empty():
					immigration_inspector.edit(null)
					groups.remove_at(selected[0])
					_refresh_immigration_list()
		)
	immigration_list = ItemList.new()
	immigration_list.custom_minimum_size.y = 120
	immigration_column.add_child(immigration_list)
	immigration_inspector = EditorInspector.new()
	immigration_inspector.size_flags_vertical = Control.SIZE_EXPAND_FILL
	immigration_column.add_child(immigration_inspector)
	immigration_list.item_selected.connect(func(index: int) -> void:
		immigration_inspector.edit(preset.settlement_config.immigration_rules.groups[index])
		call_deferred("_translate_labels")
	)
	immigration_inspector.property_edited.connect(func(_property: String) -> void:
		var selected: PackedInt32Array = immigration_list.get_selected_items()
		_refresh_immigration_list(selected[0] if not selected.is_empty() else 0)
		call_deferred("_translate_labels")
	)
	var toolbar := HBoxContainer.new()
	resource_column.add_child(toolbar)
	var add_button := Button.new()
	add_button.text = "添加地图资源"
	add_button.pressed.connect(_add_resource)
	toolbar.add_child(add_button)
	var remove_button := Button.new()
	remove_button.text = "移除选中项（仅本关）"
	remove_button.pressed.connect(_remove_resource)
	toolbar.add_child(remove_button)
	resource_list = ItemList.new()
	resource_list.custom_minimum_size.y = 90
	resource_list.item_selected.connect(_select_resource)
	resource_column.add_child(resource_list)
	var help := Label.new()
	help.custom_minimum_size.x = 500
	help.text = "间距表示碰撞轮廓边缘之间的留空（米），不是中心距离；不同资源取较大留空。\n树林模式：近处三片、远处最多四片林区，半径为软性影响范围。\n紧密簇模式：数量上限与半径限制单簇规模；空间不足不强行重叠。\n地形权重＝基础＋海拔层×增量＋崖脚/崖顶加成，零权重不生成。"
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	resource_column.add_child(help)
	resource_inspector = EditorInspector.new()
	resource_inspector.size_flags_vertical = Control.SIZE_EXPAND_FILL
	resource_column.add_child(resource_inspector)
	visibility_changed.connect(func() -> void:
		if is_visible_in_tree():
			call_deferred("_translate_labels")
	)
	map_inspector.property_edited.connect(func(_property: String) -> void: call_deferred("_translate_labels"))
	resource_inspector.property_edited.connect(func(_property: String) -> void:
		call_deferred("_translate_labels")
		var selected: PackedInt32Array = resource_list.get_selected_items()
		if not selected.is_empty():
			resource_list.set_item_text(selected[0], preset.map_resources[selected[0]].display_name)
	)


func edit_preset(value: LevelFlowData) -> void:
	resource_inspector.edit(null)
	preset = value
	wildlife_inspector.edit(preset.wildlife_config)
	immigration_inspector.edit(null)
	_refresh_immigration_list()
	for field: Dictionary in settlement_fields:
		var config: Resource = preset.settlement_config.immigration_rules if field.rules else preset.settlement_config
		field.spin.set_value_no_signal(config.get(field.key))
	for entry: MapResourceEntry in preset.map_resources:
		if entry != null:
			entry.migrate_spacing()
	if preset.map_config == null:
		preset.map_config = WFCLevelConfig.new()
	seed_spin.set_value_no_signal(preset.layout_seed)
	fog_toggle.set_pressed_no_signal(preset.fog_of_war_enabled)
	rift_distance_spin.set_value_no_signal(preset.rift_min_base_distance)
	map_inspector.edit(preset.map_config)
	call_deferred("_translate_labels")
	_refresh_list()
	if not preset.map_resources.is_empty():
		resource_list.select(0)
		_select_resource(0)


func _refresh_list() -> void:
	resource_list.clear()
	for entry: MapResourceEntry in preset.map_resources:
		resource_list.add_item(entry.display_name if entry != null else "空配置（请移除）")


func _select_resource(index: int) -> void:
	resource_inspector.edit(preset.map_resources[index])
	call_deferred("_translate_labels")


func _refresh_immigration_list(index: int = 0) -> void:
	immigration_list.clear()
	var groups: Array[ImmigrationGroup] = preset.settlement_config.immigration_rules.groups
	for group: ImmigrationGroup in groups:
		immigration_list.add_item("%d人起：%s" % [group.unlock_population, group.display_name] if group != null else "空组（请移除）")
	if not groups.is_empty():
		index = mini(index, groups.size() - 1)
		immigration_list.select(index)
		immigration_inspector.edit(groups[index])


func _translate_labels() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	for inspector: EditorInspector in [map_inspector, resource_inspector, immigration_inspector, wildlife_inspector]:
		_translate_node(inspector)


func _translate_node(node: Node) -> void:
	if node is EditorProperty:
		var property: EditorProperty = node as EditorProperty
		var key: StringName = property.get_edited_property()
		if LABELS.has(key):
			property.label = LABELS[key]
	for child: Node in node.get_children(true):
		_translate_node(child)


func _add_resource() -> void:
	var entry := MapResourceEntry.new()
	entry.spacing_version = 1
	entry.minimum_spacing = 0.1
	entry.neighbor_distance_max = 0.5
	preset.map_resources.append(entry)
	_refresh_list()
	resource_list.select(preset.map_resources.size() - 1)
	_select_resource(preset.map_resources.size() - 1)


func _remove_resource() -> void:
	var selected: PackedInt32Array = resource_list.get_selected_items()
	if selected.is_empty():
		return
	resource_inspector.edit(null)
	preset.map_resources.remove_at(selected[0])
	_refresh_list()
	if not preset.map_resources.is_empty():
		var index: int = mini(selected[0], preset.map_resources.size() - 1)
		resource_list.select(index)
		_select_resource(index)
