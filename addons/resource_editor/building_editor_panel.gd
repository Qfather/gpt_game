@tool
extends HSplitContainer

const BUILDING_FOLDER: String = "res://data/buildings/"
const LABELS: Dictionary = {
	"placement_surface": "放置地表",
	"boat_capacity": "船舱容量", "catch_min": "每次打捞最少数量", "catch_max": "每次打捞最多数量",
	"fishing_time": "每次打捞时间（游戏秒）", "processing_time": "回屋处理时间（游戏秒）", "boat_speed": "船速（米/秒）",
	"unit_id": "训练单位ID", "cost": "训练材料（资源ID）", "time_seconds": "训练时间（秒）", "enabled": "启用训练项",
	"tier": "建筑等级T0～T3", "requires_blueprint": "需要蓝图", "blueprint_pool": "蓝图随机池ID", "allow_direct_build": "允许直接建造", "upgrade_from_id": "前置建筑ID", "upgrade_cost": "升级材料", "upgrade_time": "升级时间（秒）", "training_recipes": "训练配方列表",
	"surface_drying_enabled": "启用地表干燥", "surface_drying_strength": "干燥强度（湿润度减量）",
	"surface_drying_range": "向外影响范围（米）", "surface_drying_noise": "边缘起伏与内部变化",
	"category": "建筑分类", "sort_id": "排序ID（越小越靠前）", "road_speed_mode": "加速类型", "road_speed_add": "移速增加", "road_speed_percent": "移速增加比例",
	"wall_scene_isolated": "独立墙段场景", "wall_scene_end": "尽头墙段场景（朝北）",
	"wall_scene_straight": "直墙场景（南北）", "wall_scene_corner": "拐角场景（北东）",
	"wall_scene_t": "三通场景（北东西）", "wall_scene_cross": "四通场景",
	"road_material": "共享材质", "road_texture_isolated": "独立贴图", "road_texture_end": "尽头贴图（朝北）",
	"road_texture_straight": "直线贴图（南北）", "road_texture_corner": "拐角贴图（北东）",
	"road_texture_t": "三通贴图（北东西）", "road_texture_cross": "四通贴图",
	"training_role": "训练兵种（1剑士／2弓箭手）", "processing_min": "处理最短时间（秒）", "processing_max": "处理最长时间（秒）",
	"attack_range_multiplier": "驻塔射程倍率", "base_sight_radius": "基础视野（米）", "occupied_sight_multiplier": "驻塔视野倍率",
	"id": "稳定ID", "display_name": "名称", "description": "说明", "function_text": "功能说明",
	"building_scene": "功能场景（脚本与碰撞）", "armor": "护甲", "grid_size": "占地格数", "construction_cost": "建造成本（资源ID）",
	"training_cost": "训练成本（资源ID）", "construction_time": "建造时间（秒）",
	"max_construction_workers": "最多施工人数", "allow_rotation": "允许旋转", "allow_mirror": "允许镜像",
	"garrison_capacity": "驻军容量", "housing_capacity": "住宅人口容量", "base_housing_capacity": "据点人口容量",
	"training_slots": "训练岗位", "training_time": "训练时间（秒）", "max_workers": "最多工人数",
	"production_resource_id": "生产资源ID", "work_radius": "工作范围（米）", "idle_radius": "待命范围（米）",
	"max_health": "建筑血量", "damaged_threshold": "损坏比例阈值", "heavy_damaged_threshold": "重损比例阈值",
	"wood_capacity": "木材库存容量", "stone_capacity": "石头库存容量", "food_capacity": "食物／军粮容量",
	"plow_time": "翻土时间（秒）", "sow_time": "播种时间（秒）", "grow_time": "生长时间（秒）",
	"harvest_time": "收获时间（秒）", "grain_yield": "每块田产粮", "field_id": "农田编号",
	"resupply_trigger": "军粮补给阈值", "patrol_point_reach_radius": "巡逻点抵达距离",
	"garrison_entry_reach_radius": "进营抵达距离", "lifetime": "火把寿命（秒）",
	"demolition_refund_ratio": "拆除返还比例",
}

var evolution_fields: VBoxContainer
var recipe_list: VBoxContainer
var buildings: Array[BuildingData] = []
var building_list: ItemList
var inspector: EditorInspector
var scene_fields: VBoxContainer
var status: Label
var current: BuildingData
var data_path: String
var scene_root: Node
var scene_dirty: bool = false
var field_controls: Dictionary = {}
var preview: Control
var model_label: Label
var tabs: TabContainer
var model_picker: EditorResourcePicker
var storage_fields: VBoxContainer
var resources: Array[ResourceData] = []
var category_tabs: TabBar
var autosave = preload("res://addons/editor_autosave.gd").new()


func _init() -> void:
	custom_minimum_size = Vector2(900, 420)
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 230
	add_child(left)
	for action: String in ["刷新建筑列表"]:
		var button := Button.new()
		button.text = action
		left.add_child(button)
		button.pressed.connect(refresh)
	var create_button := Button.new()
	create_button.text = "复制当前模板，新建建筑"
	create_button.pressed.connect(_show_create_building)
	left.add_child(create_button)
	var delete_button := Button.new()
	delete_button.text = "删除当前建筑定义"
	delete_button.pressed.connect(_show_delete_building)
	left.add_child(delete_button)
	preview = preload("res://addons/resource_editor/building_scene_preview.gd").new()
	left.add_child(preview)
	category_tabs = TabBar.new()
	category_tabs.clip_tabs = false
	for title: String in BuildingData.CATEGORY_NAMES: category_tabs.add_tab(title)
	category_tabs.tab_changed.connect(func(_index: int) -> void: _refresh_building_list())
	left.add_child(category_tabs)
	model_label = Label.new()
	model_label.text = "外观模型（留空使用功能场景外观）"
	model_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left.add_child(model_label)
	model_picker = EditorResourcePicker.new()
	model_picker.base_type = "PackedScene"
	model_picker.resource_changed.connect(func(value: Resource) -> void:
		if current == null: return
		current.model_scene = value as PackedScene
		_update_preview()
	)
	left.add_child(model_picker)
	building_list = ItemList.new()
	building_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	building_list.item_selected.connect(func(index: int) -> void: select_building(building_list.get_item_metadata(index)))
	left.add_child(building_list)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(right)
	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(status)
	tabs = TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(tabs)
	inspector = EditorInspector.new()
	inspector.name = "通用建筑属性"
	tabs.add_child(inspector)
	inspector.property_edited.connect(func(property: String) -> void:
		if property.begins_with("road_") or property.begins_with("wall_scene_"): _update_preview()
		if property == "building_scene":
			_load_scene()
		if property == "tier": _update_evolution_fields()
		if property in ["category", "sort_id", "display_name", "tier"]:
			category_tabs.set_block_signals(true)
			category_tabs.current_tab = current.category
			category_tabs.set_block_signals(false)
			_refresh_building_list(false)
		call_deferred("_translate_labels")
	)
	var scroll := ScrollContainer.new()
	scroll.name = "建筑专属参数"
	tabs.add_child(scroll)
	scene_fields = VBoxContainer.new()
	scene_fields.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(scene_fields)
	var storage_scroll := ScrollContainer.new()
	storage_scroll.name = "资源仓储"
	tabs.add_child(storage_scroll)
	storage_fields = VBoxContainer.new()
	storage_fields.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	storage_scroll.add_child(storage_fields)
	var evolution_scroll := ScrollContainer.new()
	evolution_scroll.name = "等级与前置关联"
	tabs.add_child(evolution_scroll)
	evolution_fields = VBoxContainer.new()
	evolution_fields.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	evolution_scroll.add_child(evolution_fields)
	var training_box := VBoxContainer.new()
	training_box.name = "公共训练配方"
	tabs.add_child(training_box)
	var hint := Label.new()
	hint.text = "使用公共训练功能场景；单位从数据库选择，材料键为资源ID。"
	training_box.add_child(hint)
	var add_recipe := Button.new()
	add_recipe.text = "添加训练项"
	add_recipe.pressed.connect(func() -> void:
		if current == null: return
		current.training_recipes.append(TrainingRecipe.new())
		_update_training_fields()
		autosave.request()
	)
	training_box.add_child(add_recipe)
	var recipe_scroll := ScrollContainer.new()
	recipe_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	training_box.add_child(recipe_scroll)
	recipe_list = VBoxContainer.new()
	recipe_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	recipe_scroll.add_child(recipe_list)
	visibility_changed.connect(func() -> void:
		if is_visible_in_tree(): call_deferred("_translate_labels")
	)
	autosave.configure(self, save_current, right)
	autosave.watch(model_picker)


func _ready() -> void:
	refresh()


func _exit_tree() -> void:
	autosave.flush()
	if scene_root != null:
		scene_root.free()
		scene_root = null


func refresh() -> void:
	if not autosave.pause(): return
	inspector.edit(null)
	current = null
	buildings.clear()
	building_list.clear()
	var files: PackedStringArray = DirAccess.get_files_at(BUILDING_FOLDER)
	files.sort()
	for file: String in files:
		if file.ends_with(".tres"):
			var data: BuildingData = load(BUILDING_FOLDER + file) as BuildingData
			if data != null:
				buildings.append(data)
	_refresh_building_list()
	autosave.suspended = false


func _refresh_building_list(select_first: bool = true) -> void:
	if select_first and not autosave.flush(): return
	if building_list == null: return
	building_list.clear()
	var indices: Array[int] = []
	for index: int in range(buildings.size()):
		var data: BuildingData = current if current != null and buildings[index].resource_path == data_path else buildings[index]
		if data.category == category_tabs.current_tab: indices.append(index)
	indices.sort_custom(func(a: int, b: int) -> bool:
		var first: BuildingData = current if current != null and buildings[a].resource_path == data_path else buildings[a]
		var second: BuildingData = current if current != null and buildings[b].resource_path == data_path else buildings[b]
		return BuildingData.menu_less(first, second)
	)
	for index: int in indices:
		var data: BuildingData = current if current != null and buildings[index].resource_path == data_path else buildings[index]
		building_list.add_item("[T%d] %s" % [data.tier, data.display_name])
		building_list.set_item_metadata(building_list.item_count - 1, index)
		if current != null and buildings[index].resource_path == data_path:
			building_list.select(building_list.item_count - 1)
	if select_first and not indices.is_empty():
		building_list.select(0)
		select_building(indices[0])
	elif select_first:
		current = null
		inspector.edit(null)
		preview.show_scene(null)
		model_picker.edited_resource = null
		if scene_root != null:
			scene_root.free()
			scene_root = null
		for fields: VBoxContainer in [scene_fields, storage_fields]:
			for child: Node in fields.get_children():
				fields.remove_child(child)
				child.queue_free()
		field_controls.clear()
		status.text = "该分类暂无建筑"


func select_building(index: int) -> void:
	if not autosave.pause(): return
	data_path = buildings[index].resource_path
	current = buildings[index].duplicate(true) as BuildingData
	current.building_scene = buildings[index].building_scene
	current.model_scene = buildings[index].model_scene
	model_picker.edited_resource = current.model_scene
	inspector.edit(current)
	_update_evolution_fields()
	_update_training_fields()
	_load_scene()
	call_deferred("_translate_labels")
	autosave.suspended = false


func _load_scene() -> void:
	scene_dirty = false
	if scene_root != null:
		scene_root.free()
		scene_root = null
	for child: Node in scene_fields.get_children():
		scene_fields.remove_child(child)
		child.queue_free()
	field_controls.clear()
	var is_road: bool = current.road_kind > 0
	model_label.visible = not is_road and not current.is_wall()
	model_picker.visible = model_label.visible
	if is_road: tabs.current_tab = 0
	tabs.set_tab_hidden(1, is_road)
	tabs.set_tab_hidden(2, is_road)
	_update_preview()
	_update_storage_fields()
	status.text = "参数修改自动保存。\n建筑配置：" + data_path
	if is_road or current.building_scene == null:
		return
	status.text += "\n专属参数保存到场景：" + current.building_scene.resource_path + "（影响所有引用此场景的建筑）"
	# 不加入场景树，避免编辑时执行建筑生产、注册或导航逻辑。
	scene_root = current.building_scene.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	_add_node_fields(scene_root)


func _add_node_fields(node: Node) -> void:
	var section_added: bool = false
	for property: Dictionary in node.get_property_list():
		var key: String = property.name
		if (current.id == &"arrow_tower" or current.is_wall_tower()) and key == "patrol_point_reach_radius": continue
		if key in ["training_role", "training_slots", "training_time"] and not current.training_recipes.is_empty(): continue
		if key in ["training_role", "training_slots", "training_time"] and not scene_root.has_method("request_training"): continue
		if key in ["resupply_trigger", "food_capacity"] and current.id not in [&"barracks", &"arrow_tower"] and not current.is_wall_tower() and node.name != &"ResourceStorage": continue
		if key == "max_health" or (node.name == &"ResourceStorage" and key in ["wood_capacity", "stone_capacity", "food_capacity"]):
			continue
		if not LABELS.has(key) or not (int(property.usage) & PROPERTY_USAGE_EDITOR):
			continue
		if property.type not in [TYPE_INT, TYPE_FLOAT, TYPE_STRING, TYPE_STRING_NAME]:
			continue
		if not section_added:
			var title := Label.new()
			title.text = String(scene_root.get_path_to(node)) + " · " + String(node.name)
			scene_fields.add_child(title)
			section_added = true
		var row := HBoxContainer.new()
		scene_fields.add_child(row)
		var label := Label.new()
		label.text = LABELS[key]
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		var control: Control
		if property.type in [TYPE_INT, TYPE_FLOAT]:
			var spin := SpinBox.new()
			spin.max_value = 1000000
			spin.step = 1 if property.type == TYPE_INT else 0.01
			if property.hint == PROPERTY_HINT_RANGE:
				var limits: PackedStringArray = String(property.hint_string).split(",")
				spin.min_value = float(limits[0])
				spin.max_value = float(limits[1])
				if limits.size() > 2: spin.step = float(limits[2])
			spin.value = float(node.get(key))
			spin.value_changed.connect(func(value: float) -> void:
				var next_value: Variant = int(value) if property.type == TYPE_INT else value
				if node.get(key) != next_value:
					node.set(key, next_value)
					scene_dirty = true
			)
			control = spin
		else:
			var edit := LineEdit.new()
			edit.text = String(node.get(key))
			edit.text_changed.connect(func(value: String) -> void:
				var next_value: Variant = StringName(value) if property.type == TYPE_STRING_NAME else value
				if node.get(key) != next_value:
					node.set(key, next_value)
					scene_dirty = true
			)
			control = edit
		control.custom_minimum_size.x = 170
		row.add_child(control)
		field_controls[String(scene_root.get_path_to(node)) + ":" + key] = control
	for child: Node in node.get_children():
		_add_node_fields(child)


func _update_preview() -> void:
	if current.road_kind > 0:
		var root := Node3D.new()
		root.name = "RoadPreview"
		var surface := MeshInstance3D.new()
		var mesh := PlaneMesh.new()
		mesh.size = Vector2.ONE
		surface.mesh = mesh
		var material: StandardMaterial3D = current.road_shape_material(0)
		surface.material_override = material
		root.add_child(surface)
		surface.owner = root
		var packed := PackedScene.new()
		packed.pack(root)
		preview.show_scene(packed)
		root.free()
		return
	preview.show_scene(current.wall_scene_isolated if current.is_wall() else (current.model_scene if current.model_scene != null else current.building_scene))


func _update_storage_fields() -> void:
	for child: Node in storage_fields.get_children():
		storage_fields.remove_child(child)
		child.queue_free()
	if current.road_kind > 0: return
	resources = ResourceEditorDataService.scan_resources()
	var tip := Label.new()
	tip.text = "军粮仅存食物；各项容量还受专属参数里的军粮总容量限制。" if (current.id in [&"barracks", &"arrow_tower"] or current.is_wall_tower()) else "每项独立容量；未添加的资源不能存储。"
	storage_fields.add_child(tip)
	for resource_id: StringName in current.storage_capacities:
		_add_storage_row(resource_id)
	var add := Button.new()
	add.text = "添加可储存资源"
	add.pressed.connect(func() -> void:
		for data: ResourceData in resources:
			if (current.id in [&"barracks", &"arrow_tower"] or current.is_wall_tower()) and data.food_properties == null: continue
			if not current.storage_capacities.has(data.id):
				current.storage_capacities[data.id] = 1.0
				_update_storage_fields()
				return
	)
	storage_fields.add_child(add)


func _add_storage_row(resource_id: StringName) -> void:
	var row := HBoxContainer.new()
	storage_fields.add_child(row)
	var options := OptionButton.new()
	options.custom_minimum_size.x = 200
	row.add_child(options)
	for data: ResourceData in resources:
		if (current.id in [&"barracks", &"arrow_tower"] or current.is_wall_tower()) and data.food_properties == null: continue
		options.add_item(data.display_name + "（" + String(data.id) + "）")
		var index: int = options.item_count - 1
		options.set_item_metadata(index, data.id)
		options.set_item_disabled(index, data.id != resource_id and current.storage_capacities.has(data.id))
		if data.id == resource_id: options.select(index)
	options.item_selected.connect(func(index: int) -> void:
		var next_id: StringName = options.get_item_metadata(index)
		current.storage_capacities[next_id] = current.storage_capacities[resource_id]
		current.storage_capacities.erase(resource_id)
		_update_storage_fields()
	)
	var capacity := SpinBox.new()
	capacity.min_value = 0
	capacity.max_value = 1000000
	capacity.value = current.storage_capacities[resource_id]
	capacity.suffix = "容量"
	capacity.custom_minimum_size.x = 180
	capacity.value_changed.connect(func(value: float) -> void: current.storage_capacities[resource_id] = value)
	row.add_child(capacity)
	var remove := Button.new()
	remove.text = "删除"
	remove.pressed.connect(func() -> void:
		current.storage_capacities.erase(resource_id)
		_update_storage_fields()
	)
	row.add_child(remove)


func save_current() -> bool:
	if current == null or (current.road_kind == 0 and (current.building_scene == null or current.building_scene.resource_path.is_empty())):
		status.text = "保存失败：请选择已有建筑场景"
		return false
	if current.grid_size.x < 1 or current.grid_size.y < 1 or current.construction_time < 0 or current.max_construction_workers < 1:
		status.text = "保存失败：占地、建造时间或施工人数无效"
		return false
	if current.road_kind > 0 and (current.road_speed_mode not in [0, 1] or current.road_speed_add < 0 or current.road_speed_percent < 0):
		status.text = "保存失败：道路加速类型或增加量无效"
		return false
	if current.id == &"arrow_tower" and current.garrison_capacity not in range(3):
		status.text = "保存失败：箭塔驻军容量只能为 0～2"
		return false
	if current.is_wall_tower() and current.garrison_capacity not in range(2):
		status.text = "保存失败：塔楼驻军容量只能为 0～1"
		return false
	if (current.is_wall() or current.is_wall_tower()) and current.grid_size != Vector2i.ONE:
		status.text = "保存失败：城墙与塔楼占地必须为 1×1"
		return false
	if current.is_gate() and current.grid_size != Vector2i(4, 1):
		status.text = "保存失败：城门占地必须为 4×1"
		return false
	if current.is_wall():
		for scene: PackedScene in current.wall_scenes():
			if scene == null:
				status.text = "保存失败：请指定全部六种城墙形态场景"
				return false
			var model: Node = scene.instantiate()
			var valid_model: bool = model is Node3D
			model.free()
			if not valid_model:
				status.text = "保存失败：城墙形态必须是 3D 场景"
				return false
	var catalog := BuildingCatalog.new()
	for data: BuildingData in buildings:
		if data_path.begins_with(BUILDING_FOLDER) and data.id == current.id and data.resource_path != data_path:
			catalog.free()
			status.text = "保存失败：建筑ID重复"
			return false
	var original := load(data_path) as BuildingData
	if original != null and original.id != current.id:
		catalog.free()
		status.text = "保存失败：已有建筑稳定ID不可改名，请复制新建"
		return false
	catalog.buildings[current.id] = current
	var validation := catalog.validate(current)
	catalog.free()
	call_deferred("_translate_labels")
	if not validation.is_empty():
		status.text = "保存失败：" + validation
		return false
	var available_resources: Array[ResourceData] = ResourceEditorDataService.scan_resources()
	var cost_sets: Array[Dictionary] = [current.construction_cost, current.training_cost, current.upgrade_cost]
	for recipe: TrainingRecipe in current.training_recipes:
		cost_sets.append(recipe.cost)
	for costs: Dictionary in cost_sets:
		for resource_id: StringName in costs:
			if not ResourceEditorDataService.resource_id_exists(resource_id, available_resources):
				status.text = "保存失败：未知资源ID「%s」。请填写资源ID，例如 wood（木材）、stone（石头），不要填写显示名称。" % resource_id
				return false
		for amount: float in costs.values():
			if amount < 0:
				status.text = "保存失败：资源成本不能为负数"
				return false
	if current.max_health < 1 or current.armor < 0:
		status.text = "保存失败：血量必须大于零，护甲不能为负数"
		return false
	if current.model_scene != null:
		var model: Node = current.model_scene.instantiate()
		var valid_model: bool = model is Node3D
		model.free()
		if not valid_model:
			status.text = "保存失败：外观模型必须是 3D 场景"
			return false
	for amount: float in current.storage_capacities.values():
		if amount < 0:
			status.text = "保存失败：仓储容量不能为负数"
			return false
	var scene_path: String = ""
	if current.road_kind == 0 and scene_dirty:
		scene_path = current.building_scene.resource_path
		var packed: PackedScene = current.building_scene.duplicate() as PackedScene
		if packed.pack(scene_root) != OK or ResourceSaver.save(packed, scene_path) != OK:
			status.text = "建筑场景保存失败：" + scene_path
			return false
		current.building_scene = ResourceLoader.load(scene_path, "", ResourceLoader.CACHE_MODE_REPLACE) as PackedScene
		scene_dirty = false
	if ResourceSaver.save(current, data_path) != OK:
		status.text = "建筑配置保存失败：" + data_path
		return false
	ResourceLoader.load(data_path, "", ResourceLoader.CACHE_MODE_REPLACE)
	if not scene_path.is_empty(): EditorInterface.get_resource_filesystem().update_file(scene_path)
	EditorInterface.get_resource_filesystem().update_file(data_path)
	status.text = "已保存：" + data_path + "\n专属参数：" + scene_path
	_refresh_building_list(false)
	return true


func _translate_labels() -> void:
	if not is_inside_tree(): return
	# Inspector 会延迟重建属性控件，等它完成后再设置中文标签。
	await get_tree().create_timer(0.1).timeout
	if not is_inside_tree(): return
	_translate_node(inspector)
	_translate_node(recipe_list)


func _translate_node(node: Node) -> void:
	if node is EditorProperty and LABELS.has(node.get_edited_property()):
		node.label = LABELS[node.get_edited_property()]
		if node.get_edited_property() == &"construction_time" and current != null and current.road_kind > 0: node.label = "每格施工时间（秒）"
		if node.get_edited_property() == &"id": node.set_read_only(true)
	for child: Node in node.get_children(true):
		_translate_node(child)


func _update_evolution_fields() -> void:
	for child: Node in evolution_fields.get_children(): child.free()
	var hint := Label.new()
	hint.text = "前置蓝图满足后进入随机池；持有蓝图即可使用。升级前后须同占地。\n新建筑使用当前建筑作为模板，外观可另选，公共训练在配方页配置。"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	evolution_fields.add_child(hint)
	var parent_picker := OptionButton.new()
	parent_picker.add_item("无前置（直接建造）")
	parent_picker.set_item_metadata(0, &"")
	for data: BuildingData in buildings:
		if data.id == current.id or data.tier + 1 != current.tier: continue
		parent_picker.add_item("T%d %s" % [data.tier, data.display_name])
		parent_picker.set_item_metadata(parent_picker.item_count - 1, data.id)
		if data.id == current.upgrade_from_id: parent_picker.select(parent_picker.item_count - 1)
	parent_picker.item_selected.connect(func(index: int) -> void:
		current.upgrade_from_id = parent_picker.get_item_metadata(index)
		if index > 0: current.allow_direct_build = false
		autosave.request()
		inspector.edit(current)
	)
	evolution_fields.add_child(parent_picker)
	var tree := Tree.new()
	tree.custom_minimum_size = Vector2(350, 220)
	tree.hide_root = true
	evolution_fields.add_child(tree)
	var root_item := tree.create_item()
	for data: BuildingData in buildings:
		if data.upgrade_from_id.is_empty(): _add_evolution_item(tree, root_item, data, [])


func _add_evolution_item(tree: Tree, parent: TreeItem, data: BuildingData, visited: Array[StringName]) -> void:
	if visited.has(data.id): return
	var item := tree.create_item(parent)
	item.set_text(0, "T%d %s · %s" % [data.tier, data.display_name, str(data.blueprint_pool) if data.requires_blueprint else "默认解锁"])
	var next: Array[StringName] = visited.duplicate()
	next.append(data.id)
	for child: BuildingData in buildings:
		if child.upgrade_from_id == data.id: _add_evolution_item(tree, item, child, next)


func _show_create_building() -> void:
	if current == null or not autosave.flush(): return
	var dialog := ConfirmationDialog.new()
	dialog.title = "复制模板新建建筑"
	var fields := VBoxContainer.new()
	dialog.add_child(fields)
	var id_field := LineEdit.new()
	id_field.placeholder_text = "唯一英文ID，如 heavy_camp"
	fields.add_child(id_field)
	var name_field := LineEdit.new()
	name_field.placeholder_text = "建筑显示名称"
	fields.add_child(name_field)
	add_child(dialog)
	dialog.confirmed.connect(func() -> void:
		var new_id := id_field.text.strip_edges()
		if new_id.is_empty() or not new_id.is_valid_ascii_identifier() or name_field.text.strip_edges().is_empty():
			status.text = "新建失败：请填写英文ID和名称"
			return
		for data: BuildingData in buildings:
			if str(data.id) == new_id:
				status.text = "新建失败：ID已存在"
				return
		var path := BUILDING_FOLDER + new_id + ".tres"
		if FileAccess.file_exists(path):
			status.text = "新建失败：目标文件已存在"
			return
		var data := current.duplicate(true) as BuildingData
		data.building_scene = current.building_scene
		data.model_scene = current.model_scene
		data.id = StringName(new_id)
		data.display_name = name_field.text.strip_edges()
		if ResourceSaver.save(data, path) != OK:
			status.text = "新建失败：无法保存资源"
			return
		EditorInterface.get_resource_filesystem().update_file(path)
		refresh()
		for index: int in range(buildings.size()):
			if buildings[index].id == data.id:
				category_tabs.current_tab = data.category
				select_building(index)
				_refresh_building_list(false)
				break
	)
	dialog.popup_centered(Vector2i(420, 160))
	dialog.visibility_changed.connect(func() -> void:
		if not dialog.visible: dialog.queue_free()
	)


func _show_delete_building() -> void:
	if current == null or not autosave.flush(): return
	# 内置内容由场景／特殊规则引用，插件仅允许删除新建定义。
	if not data_path.ends_with("/" + str(current.id) + ".tres"):
		status.text = "内置建筑受保护，不能在此删除"
		return
	for data: BuildingData in buildings:
		if data.id == current.id and data.resource_path != data_path:
			status.text = "不能删除：存在重复ID，请先修正配置"
			return
		if data.upgrade_from_id == current.id:
			status.text = "不能删除：被前置关联引用：" + data.display_name
			return
	var dialog := ConfirmationDialog.new()
	dialog.dialog_text = "删除建筑定义「%s」？功能场景和模型保留。" % current.display_name
	add_child(dialog)
	var path := data_path
	dialog.confirmed.connect(func() -> void:
		if DirAccess.remove_absolute(path) == OK:
			EditorInterface.get_resource_filesystem().scan()
			refresh()
	)
	dialog.popup_centered()
	dialog.visibility_changed.connect(func() -> void:
		if not dialog.visible: dialog.queue_free()
	)


func _update_training_fields() -> void:
	for child: Node in recipe_list.get_children(): child.free()
	if current == null: return
	var slot_row := HBoxContainer.new()
	recipe_list.add_child(slot_row)
	var label := Label.new()
	label.text = "并发训练槽位"
	slot_row.add_child(label)
	var slots := SpinBox.new()
	slots.min_value = 1
	slots.max_value = 100
	slots.value = current.training_slots
	slots.value_changed.connect(func(value: float) -> void:
		current.training_slots = int(value)
		autosave.request()
	)
	slot_row.add_child(slots)
	var catalog := BuildingCatalog.new()
	var unit_ids: Array[StringName] = []
	unit_ids.assign(catalog.units.keys())
	unit_ids.sort()
	for index: int in range(current.training_recipes.size()):
		var recipe: TrainingRecipe = current.training_recipes[index]
		if recipe == null:
			recipe = TrainingRecipe.new()
			current.training_recipes[index] = recipe
		var row := HBoxContainer.new()
		recipe_list.add_child(row)
		var units_picker := OptionButton.new()
		for unit_id: StringName in unit_ids:
			if catalog.units[unit_id].combat_role == CombatRole.Type.NONE: continue
			units_picker.add_item(catalog.units[unit_id].display_name + " (" + str(unit_id) + ")")
			units_picker.set_item_metadata(units_picker.item_count - 1, unit_id)
			if unit_id == recipe.unit_id: units_picker.select(units_picker.item_count - 1)
		units_picker.item_selected.connect(func(choice: int) -> void:
			recipe.unit_id = units_picker.get_item_metadata(choice)
			autosave.request()
		)
		row.add_child(units_picker)
		var remove := Button.new()
		remove.text = "删除训练项"
		remove.pressed.connect(func() -> void:
			current.training_recipes.remove_at(index)
			_update_training_fields()
			autosave.request()
		)
		row.add_child(remove)
		var recipe_editor := EditorInspector.new()
		recipe_editor.custom_minimum_size.y = 150
		recipe_list.add_child(recipe_editor)
		recipe_editor.edit(recipe)
		recipe_editor.property_edited.connect(func(_key: String) -> void: autosave.request())
	catalog.free()
	call_deferred("_translate_labels")
