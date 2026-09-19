extends SceneTree

const DATABASE_PATH: String = "res://data/resources/resource_database.tres"
const EXPECTED_IDS: Array[StringName] = [
	&"wood",
	&"stone",
	&"grain",
	&"meat",
	&"plank",
	&"flour",
	&"bread",
]

var _failed: bool = false


func _initialize() -> void:
	var loaded_resource: Resource = ResourceLoader.load(DATABASE_PATH)
	var database: ResourceDatabase = loaded_resource as ResourceDatabase
	_expect(database != null, "正式 ResourceDatabase 可以读取")
	if database == null:
		_finish()
		return

	_expect(database.rebuild_index(), "数据库不存在空 ID 或重复 ID")
	_expect(database.resources.size() == EXPECTED_IDS.size(), "数据库包含 7 种首批资源")

	for resource_id: StringName in EXPECTED_IDS:
		var resource_data: ResourceData = database.get_resource_data(resource_id)
		_expect(resource_data != null, "可以查询资源：%s" % resource_id)

	_validate_material(database, &"wood", 1, [&"wood", &"raw", &"construction"])
	_validate_material(database, &"stone", 1, [&"stone", &"raw", &"construction"])
	_validate_material(database, &"plank", 2, [&"wood", &"processed", &"construction"])

	_validate_food(database, &"grain", 1, &"grain")
	_validate_food(database, &"meat", 1, &"meat")
	_validate_food(database, &"flour", 2, &"grain")
	_validate_food(database, &"bread", 3, &"grain")

	_finish()


func _validate_material(
	database: ResourceDatabase,
	resource_id: StringName,
	expected_tier: int,
	expected_tags: Array[StringName]
) -> void:
	var resource_data: ResourceData = database.get_resource_data(resource_id)
	if resource_data == null:
		return

	_expect(resource_data.tier == expected_tier, "%s 的 Tier 正确" % resource_id)
	_expect(not resource_data.is_food(), "%s 没有食物属性" % resource_id)
	for tag: StringName in expected_tags:
		_expect(resource_data.has_tag(tag), "%s 包含标签 %s" % [resource_id, tag])


func _validate_food(
	database: ResourceDatabase,
	resource_id: StringName,
	expected_tier: int,
	expected_variety_group: StringName
) -> void:
	var resource_data: ResourceData = database.get_resource_data(resource_id)
	if resource_data == null:
		return

	_expect(
		resource_data.category == ResourceData.ResourceCategory.FOOD,
		"%s 的 Category 为 FOOD" % resource_id
	)
	_expect(resource_data.tier == expected_tier, "%s 的 Tier 正确" % resource_id)
	_expect(resource_data.is_food(), "%s 包含 FoodProperties" % resource_id)
	if resource_data.food_properties != null:
		_expect(
			resource_data.food_properties.variety_group == expected_variety_group,
			"%s 的食物分组正确" % resource_id
		)


func _expect(condition: bool, description: String) -> void:
	if condition:
		print("[通过] ", description)
		return

	_failed = true
	printerr("[失败] ", description)


func _finish() -> void:
	if _failed:
		printerr("资源系统 V2 阶段 2 测试失败")
		quit(1)
		return

	print("资源系统 V2 阶段 2 测试通过")
	quit()
