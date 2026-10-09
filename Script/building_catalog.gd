@tool
class_name BuildingCatalog
extends Node

signal blueprints_changed

var buildings: Dictionary[StringName, BuildingData] = {}
var units: Dictionary[StringName, UnitData] = {}
var unlocked: Array[StringName] = []
var offered: Array[BuildingData] = []
var rng := RandomNumberGenerator.new()

static func for_tree(tree: SceneTree) -> BuildingCatalog:
	return tree.get_first_node_in_group("building_catalog") as BuildingCatalog

func _init() -> void:
	rng.randomize()
	reload_data()

func _enter_tree() -> void:
	add_to_group("building_catalog")

func reload_data() -> void:
	buildings.clear()
	units.clear()
	for file: String in DirAccess.get_files_at("res://data/buildings/"):
		if file.ends_with(".tres"):
			var data := load("res://data/buildings/" + file) as BuildingData
			if data != null:
				if buildings.has(data.id):
					push_error("建筑ID重复：%s（%s）" % [data.id, file])
					continue
				buildings[data.id] = data
	for file: String in DirAccess.get_files_at("res://data/units/"):
		if file.ends_with(".tres"):
			var data := load("res://data/units/" + file) as UnitData
			if data != null:
				if units.has(data.id):
					push_error("单位ID重复：%s（%s）" % [data.id, file])
					continue
				units[data.id] = data

func is_unlocked(data: BuildingData) -> bool:
	return data != null and (not data.requires_blueprint or unlocked.has(data.id))

func can_build(data: BuildingData) -> bool:
	return is_unlocked(data) and data.allow_direct_build and (data.road_kind > 0 or data.building_scene != null)

func get_upgrade_children(parent_id: StringName) -> Array[BuildingData]:
	var result: Array[BuildingData] = []
	for data: BuildingData in buildings.values():
		if data.upgrade_from_id == parent_id and not data.allow_direct_build: result.append(data)
	result.sort_custom(BuildingData.menu_less)
	return result

func get_pool(pool_id: StringName) -> Array[BuildingData]:
	var result: Array[BuildingData] = []
	for data: BuildingData in buildings.values():
		if not data.requires_blueprint or is_unlocked(data) or data.blueprint_pool != pool_id or (data.road_kind == 0 and data.building_scene == null): continue
		var parent: BuildingData = buildings.get(data.upgrade_from_id)
		if not data.upgrade_from_id.is_empty() and not is_unlocked(parent): continue
		result.append(data)
	result.sort_custom(BuildingData.menu_less)
	return result

func draw_blueprints(pool_id: StringName = &"standard") -> Array[BuildingData]:
	# 关闭窗口再打开保留同一组选项，不能重复点击刷牌。
	if not offered.is_empty(): return offered.duplicate()
	var pool := get_pool(pool_id)
	while not pool.is_empty() and offered.size() < 3:
		var index := rng.randi_range(0, pool.size() - 1)
		offered.append(pool[index])
		pool.remove_at(index)
	return offered.duplicate()

func choose_blueprint(id: StringName) -> bool:
	for data: BuildingData in offered:
		if data.id == id:
			unlocked.append(id)
			offered.clear()
			blueprints_changed.emit()
			return true
	return false

func validate(data: BuildingData) -> String:
	if data.id.is_empty(): return "建筑ID不能为空"
	if data.tier not in range(4): return "建筑等级必须为T0～T3"
	if data.requires_blueprint and data.blueprint_pool.is_empty(): return "蓝图建筑必须指定随机池ID"
	var supports_training: bool = false
	if data.road_kind == 0:
		if data.building_scene == null: return "请指定功能场景"
		var scene: Node = data.building_scene.instantiate()
		var valid_scene: bool = scene is BuildingBase
		supports_training = scene.has_method("request_training")
		scene.free()
		if not valid_scene: return "功能场景必须继承BuildingBase"
	if not data.upgrade_from_id.is_empty():
		var parent: BuildingData = buildings.get(data.upgrade_from_id)
		if parent == null: return "前置建筑不存在"
		if parent.tier + 1 != data.tier: return "升级必须从前一级建筑开始"
		if not data.allow_direct_build:
			if parent.grid_size != data.grid_size: return "升级前后占地必须一致"
			if data.upgrade_time <= 0 or data.upgrade_cost.is_empty(): return "请设置升级时间和材料"
			var parent_scene: Node = parent.building_scene.instantiate() if parent.building_scene != null else null
			var parent_trains: bool = parent_scene != null and parent_scene.has_method("request_training")
			if parent_scene != null: parent_scene.free()
			if not supports_training or not parent_trains: return "本版原地升级用于公共训练营；其他前置关联请启用直接建造"
		var seen: Array[StringName] = [data.id]
		while parent != null:
			if seen.has(parent.id): return "前置关联形成循环"
			seen.append(parent.id)
			parent = buildings.get(parent.upgrade_from_id)
	if not data.training_recipes.is_empty():
		if data.training_slots < 1: return "训练槽位必须大于零"
		if not supports_training: return "请选择使用公共训练脚本的功能场景"
		var seen_units: Array[StringName] = []
		for recipe: TrainingRecipe in data.training_recipes:
			if recipe == null or not units.has(recipe.unit_id): return "训练单位不存在"
			if units[recipe.unit_id].combat_role == CombatRole.Type.NONE: return "训练配方请选择军事单位"
			if seen_units.has(recipe.unit_id): return "不能重复配置同一训练单位"
			seen_units.append(recipe.unit_id)
			if recipe.time_seconds <= 0: return "训练时间必须大于零"
	return ""
