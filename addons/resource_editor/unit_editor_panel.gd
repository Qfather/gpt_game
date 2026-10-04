@tool
extends TabContainer

const UnitDataResource = preload("res://Script/unit/unit_data.gd")

const FOLDERS: Array[String] = ["res://data/units/", "res://data/enemies/raid/", "res://data/enemies/rift/"]
const LABELS: Dictionary = {
	"uses_arrows": "使用箭矢攻击", "arrow_speed": "箭矢速度（米/秒）",
	"id": "稳定ID", "display_name": "名称", "description": "说明", "visual_scene": "外观模型场景",
	"fixed_name": "固定名字（留空按类别随机）",
	"visual_tint": "模型颜色", "max_health": "生命上限", "health_regen": "每秒回血量（生命/秒）",
	"move_speed": "移动速度", "work_speed": "工作速度倍率", "gather_speed": "采集速度倍率",
	"carry_capacity": "资源携带容量", "chop_amount": "每次采集数量", "chop_interval": "采集间隔（秒）",
	"damage": "攻击伤害", "attack_range": "攻击距离", "attack_interval": "攻击间隔（秒）",
	"detection_range": "索敌范围", "hunger_rate": "饥饿增长速度", "fatigue_rate": "疲劳增长速度",
	"rest_recovery_rate": "休息恢复速度", "is_boss": "首领", "faction": "阵营",
	"abilities": "旧版技能列表", "ability_entries": "技能配置", "features": "特性配置",
	"raid_objective": "袭扰目标", "raid_kill_unit_id": "袭扰目标单位ID",
	"raid_destroy_building_id": "袭扰目标建筑ID", "raid_steal_resource_id": "偷取资源ID",
	"raid_steal_amount_per_tick": "单次偷取量", "raid_steal_interval": "偷取间隔（秒）", "raid_steal_quota": "偷取总额度",
}

var items: Array[Resource] = []
var unit_list: ItemList
var inspector: EditorInspector
var preview: Control
var status: Label
var current: Resource
var data_path: String
var name_panel: Control

func _init() -> void:
	custom_minimum_size = Vector2(900, 420)
	var details := HSplitContainer.new()
	details.name = "单位详情"
	add_child(details)
	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 230
	details.add_child(left)
	for action: String in ["刷新单位列表", "保存单位配置"]:
		var button := Button.new()
		button.text = action
		left.add_child(button)
		button.pressed.connect(refresh if action == "刷新单位列表" else save_current)
	preview = preload("res://addons/resource_editor/building_scene_preview.gd").new()
	left.add_child(preview)
	unit_list = ItemList.new()
	unit_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	unit_list.item_selected.connect(select_unit)
	left.add_child(unit_list)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.add_child(right)
	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(status)
	inspector = EditorInspector.new()
	inspector.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(inspector)
	name_panel = TabContainer.new()
	name_panel.name = "名称"
	add_child(name_panel)
	for category: String in ["怪物名称", "人类名称", "BOSS名称"]:
		var page := preload("res://addons/resource_editor/name_editor_panel.gd").new()
		page.name = category
		name_panel.add_child(page)
		page.edit_pool("res://data/names/" + {"怪物名称": "EnemyNames.tres", "人类名称": "HumanNames.tres", "BOSS名称": "BossNames.tres"}[category])
	inspector.property_edited.connect(func(key: String) -> void:
		if key in ["visual_scene", "visual_tint"]: _update_preview()
		call_deferred("_translate_labels")
	)
	visibility_changed.connect(func() -> void:
		if is_visible_in_tree(): call_deferred("_translate_labels")
	)
	details.visibility_changed.connect(func() -> void:
		if details.is_visible_in_tree(): call_deferred("_translate_labels")
	)

func _ready() -> void:
	refresh()

func refresh() -> void:
	inspector.edit(null)
	current = null
	items.clear()
	unit_list.clear()
	for folder: String in FOLDERS:
		var files: PackedStringArray = DirAccess.get_files_at(folder)
		files.sort()
		for file: String in files:
			if not file.ends_with(".tres"): continue
			var data: Resource = load(folder + file)
			if not (data is UnitDataResource or data is EnemyData): continue
			items.append(data)
			var prefix: String = "居民职业" if data is UnitDataResource else ("袭扰" if folder.ends_with("raid/") else "裂缝")
			unit_list.add_item(prefix + " · " + String(data.get("display_name")))
	if not items.is_empty():
		unit_list.select(0)
		select_unit(0)

func select_unit(index: int) -> void:
	data_path = items[index].resource_path
	current = items[index].duplicate(true)
	current.set("visual_scene", items[index].get("visual_scene"))
	inspector.edit(current)
	_update_preview()
	status.text = "切换或刷新会放弃未保存修改；保存只修改当前配置。\n" + data_path
	if current is UnitDataResource:
		status.text += "\n居民职业共用行为场景，外观留空时使用原胶囊模型；普通居民不主动参战。"
	else:
		status.text += "\n敌人沿用关卡引用的原资源；改动将影响所有引用它的关卡和营地。"
	call_deferred("_translate_labels")

func _update_preview() -> void:
	var visual: PackedScene = current.get("visual_scene") as PackedScene
	if visual == null:
		visual = load("res://Scene/unit/villager.tscn" if current is UnitDataResource else "res://Scene/unit/enemy_base.tscn")
	preview.show_scene(visual, current.get("visual_tint"))

func save_current() -> bool:
	if current == null: return false
	for key: String in ["max_health", "move_speed", "attack_interval"]:
		var value: float = float(current.get(key))
		var invalid: bool = value <= 0.0 if current is UnitDataResource or key == "max_health" else value < 0.0
		if invalid:
			status.text = "保存失败：" + String(LABELS[key]) + "超出允许范围"
			return false
	for key: String in ["damage", "attack_range", "detection_range"]:
		if float(current.get(key)) < 0.0:
			status.text = "保存失败：" + String(LABELS[key]) + "不能为负数"
			return false
	if current is UnitDataResource:
		for key: String in ["work_speed", "gather_speed", "carry_capacity", "chop_amount", "chop_interval"]:
			if float(current.get(key)) <= 0.0:
				status.text = "保存失败：" + String(LABELS[key]) + "必须大于零"
				return false
		for key: String in ["health_regen", "hunger_rate", "fatigue_rate", "rest_recovery_rate"]:
			if float(current.get(key)) < 0.0:
				status.text = "保存失败：" + String(LABELS[key]) + "不能为负数"
				return false
	var visual: PackedScene = current.get("visual_scene") as PackedScene
	if visual != null:
		var node: Node = visual.instantiate()
		var valid: bool = node is Node3D
		node.free()
		if not valid:
			status.text = "保存失败：外观模型必须是 3D 场景"
			return false
	if ResourceSaver.save(current, data_path) != OK:
		status.text = "保存失败：" + data_path
		return false
	ResourceLoader.load(data_path, "", ResourceLoader.CACHE_MODE_REPLACE)
	EditorInterface.get_resource_filesystem().update_file(data_path)
	status.text = "已保存：" + data_path
	return true

func _translate_labels() -> void:
	if not is_inside_tree(): return
	await get_tree().create_timer(0.1).timeout
	if not is_inside_tree(): return
	_translate_node(inspector)

func _translate_node(node: Node) -> void:
	if node is EditorProperty and LABELS.has(node.get_edited_property()):
		node.label = LABELS[node.get_edited_property()]
		if node.get_edited_property() == &"id": node.set_read_only(true)
	for child: Node in node.get_children(true): _translate_node(child)
