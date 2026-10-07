@tool
extends HSplitContainer

const BUILDING_FOLDER: String = "res://data/buildings/"
const LABELS: Dictionary = {
	"surface_drying_enabled": "启用地表干燥", "surface_drying_strength": "干燥强度（湿润度减量）",
	"surface_drying_range": "向外影响范围（米）", "surface_drying_noise": "边缘起伏与内部变化",
	"category": "建筑分类", "sort_id": "排序ID（越小越靠前）", "road_kind": "道路类型", "road_speed_multiplier": "道路移速倍率",
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

var buildings: Array[BuildingData] = []
var building_list: ItemList
var inspector: EditorInspector
var scene_fields: VBoxContainer
var status: Label
var current: BuildingData
var data_path: String
var scene_root: Node
var field_controls: Dictionary = {}
var preview: Control
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
	preview = preload("res://addons/resource_editor/building_scene_preview.gd").new()
	left.add_child(preview)
	category_tabs = TabBar.new()
	category_tabs.clip_tabs = false
	for title: String in BuildingData.CATEGORY_NAMES: category_tabs.add_tab(title)
	category_tabs.tab_changed.connect(func(_index: int) -> void: _refresh_building_list())
	left.add_child(category_tabs)
	var model_label := Label.new()
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
	var tabs := TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(tabs)
	inspector = EditorInspector.new()
	inspector.name = "通用建筑属性"
	tabs.add_child(inspector)
	inspector.property_edited.connect(func(property: String) -> void:
		if property == "building_scene":
			_load_scene()
		if property in ["category", "sort_id", "display_name"]:
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
		building_list.add_item("%d  %s" % [data.sort_id, data.display_name])
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
	_load_scene()
	call_deferred("_translate_labels")
	autosave.suspended = false


func _load_scene() -> void:
	if scene_root != null:
		scene_root.free()
		scene_root = null
	for child: Node in scene_fields.get_children():
		scene_fields.remove_child(child)
		child.queue_free()
	field_controls.clear()
	_update_preview()
	_update_storage_fields()
	status.text = "参数修改自动保存。\n建筑配置：" + data_path
	if current.building_scene == null:
		return
	status.text += "\n专属参数保存到场景：" + current.building_scene.resource_path + "（影响所有引用此场景的建筑）"
	# 不加入场景树，避免编辑时执行建筑生产、注册或导航逻辑。
	scene_root = current.building_scene.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	_add_node_fields(scene_root)


func _add_node_fields(node: Node) -> void:
	var section_added: bool = false
	for property: Dictionary in node.get_property_list():
		var key: String = property.name
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
			spin.value_changed.connect(func(value: float) -> void: node.set(key, int(value) if property.type == TYPE_INT else value))
			control = spin
		else:
			var edit := LineEdit.new()
			edit.text = String(node.get(key))
			edit.text_changed.connect(func(value: String) -> void: node.set(key, StringName(value) if property.type == TYPE_STRING_NAME else value))
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
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(0.43, 0.28, 0.13) if current.road_kind == 1 else Color(0.55, 0.59, 0.63)
		surface.material_override = material
		root.add_child(surface)
		surface.owner = root
		var packed := PackedScene.new()
		packed.pack(root)
		preview.show_scene(packed)
		root.free()
		return
	preview.show_scene(current.model_scene if current.model_scene != null else current.building_scene)


func _update_storage_fields() -> void:
	for child: Node in storage_fields.get_children():
		storage_fields.remove_child(child)
		child.queue_free()
	resources = ResourceEditorDataService.scan_resources()
	var tip := Label.new()
	tip.text = "军粮仅存食物；各项容量还受专属参数里的军粮总容量限制。" if current.id in [&"barracks", &"arrow_tower"] else "每项独立容量；未添加的资源不能存储。"
	storage_fields.add_child(tip)
	for resource_id: StringName in current.storage_capacities:
		_add_storage_row(resource_id)
	var add := Button.new()
	add.text = "添加可储存资源"
	add.pressed.connect(func() -> void:
		for data: ResourceData in resources:
			if current.id in [&"barracks", &"arrow_tower"] and data.food_properties == null: continue
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
		if current.id in [&"barracks", &"arrow_tower"] and data.food_properties == null: continue
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
	var available_resources: Array[ResourceData] = ResourceEditorDataService.scan_resources()
	for costs: Dictionary in [current.construction_cost, current.training_cost]:
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
	if current.road_kind == 0:
		scene_path = current.building_scene.resource_path
		var packed: PackedScene = current.building_scene.duplicate() as PackedScene
		if packed.pack(scene_root) != OK or ResourceSaver.save(packed, scene_path) != OK:
			status.text = "建筑场景保存失败：" + scene_path
			return false
		current.building_scene = ResourceLoader.load(scene_path, "", ResourceLoader.CACHE_MODE_REPLACE) as PackedScene
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


func _translate_node(node: Node) -> void:
	if node is EditorProperty and LABELS.has(node.get_edited_property()):
		node.label = LABELS[node.get_edited_property()]
		if node.get_edited_property() == &"id": node.set_read_only(true)
	for child: Node in node.get_children(true):
		_translate_node(child)
