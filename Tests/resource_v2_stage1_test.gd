extends SceneTree

const TEST_DATABASE_PATH: String = "user://resource_v2_stage1_test.tres"
const PROJECT_DATABASE_PATH: String = "res://data/resources/resource_database.tres"

var _failed: bool = false


func _initialize() -> void:
	_run_tests()
	_cleanup_test_file()

	if _failed:
		printerr("资源系统 V2 阶段 1 测试失败")
		quit(1)
		return

	print("资源系统 V2 阶段 1 测试通过")
	quit()


func _run_tests() -> void:
	var project_resource: Resource = ResourceLoader.load(PROJECT_DATABASE_PATH)
	var project_database: ResourceDatabase = project_resource as ResourceDatabase
	_expect(project_database != null, "正式 ResourceDatabase 配置可以读取")

	var food_properties: FoodProperties = FoodProperties.new()
	food_properties.nutrition = 12.0
	food_properties.food_quality = 1.0
	food_properties.variety_group = &"grain"

	var grain: ResourceData = ResourceData.new()
	grain.id = &"stage1_test_grain"
	grain.display_name = "阶段测试粮食"
	grain.category = ResourceData.ResourceCategory.FOOD
	grain.tier = 1
	grain.tags = [&"food", &"grain", &"raw"]
	grain.stack_size = 50
	grain.food_properties = food_properties

	_expect(grain.id == &"stage1_test_grain", "ResourceData ID 可读取")
	_expect(grain.category == ResourceData.ResourceCategory.FOOD, "Category 可读取")
	_expect(grain.tier == 1, "Tier 可读取")
	_expect(grain.has_tag(&"grain"), "Tags 可查询")
	_expect(grain.is_food(), "FoodProperties 存在时识别为食物")

	var material: ResourceData = ResourceData.new()
	material.id = &"stage1_test_material"
	_expect(not material.is_food(), "FoodProperties 为空时不是食物")

	var database: ResourceDatabase = ResourceDatabase.new()
	_expect(database.register_resource(grain), "有效资源可以注册")
	_expect(database.has_resource(grain.id), "数据库可以检查资源 ID")
	_expect(database.get_resource_data(grain.id) == grain, "数据库可以按 ID 查询资源")
	_expect(database.get_resource_data(&"stage1_missing") == null, "不存在的 ID 安全返回 null")
	_expect(database.get_resource_data(&"") == null, "空 ID 安全返回 null")

	var duplicate: ResourceData = ResourceData.new()
	duplicate.id = grain.id
	_expect(not database.register_resource(duplicate), "重复 ID 会被拒绝")

	var invalid_database: ResourceDatabase = ResourceDatabase.new()
	var invalid_resource: ResourceData = ResourceData.new()
	invalid_database.resources = [invalid_resource]
	_expect(not invalid_database.rebuild_index(), "空资源 ID 会使校验失败")

	var save_error: Error = ResourceSaver.save(database, TEST_DATABASE_PATH)
	_expect(save_error == OK, "数据库可以保存到 user:// 临时文件")
	if save_error != OK:
		return

	var loaded_resource: Resource = ResourceLoader.load(TEST_DATABASE_PATH)
	var loaded_database: ResourceDatabase = loaded_resource as ResourceDatabase
	_expect(loaded_database != null, "临时数据库可以重新读取")
	if loaded_database == null:
		return

	var loaded_grain: ResourceData = loaded_database.get_resource_data(grain.id)
	_expect(loaded_grain != null, "序列化后仍可按 ID 查询")
	if loaded_grain == null:
		return

	_expect(loaded_grain.display_name == grain.display_name, "显示名称序列化正确")
	_expect(loaded_grain.has_tag(&"raw"), "Tags 序列化正确")
	_expect(loaded_grain.food_properties != null, "FoodProperties 序列化正确")
	if loaded_grain.food_properties != null:
		_expect(
			loaded_grain.food_properties.variety_group == &"grain",
			"FoodProperties 内容序列化正确"
		)


func _expect(condition: bool, description: String) -> void:
	if condition:
		print("[通过] ", description)
		return

	_failed = true
	printerr("[失败] ", description)


func _cleanup_test_file() -> void:
	if not FileAccess.file_exists(TEST_DATABASE_PATH):
		return

	var absolute_path: String = ProjectSettings.globalize_path(TEST_DATABASE_PATH)
	var remove_error: Error = DirAccess.remove_absolute(absolute_path)
	if remove_error != OK:
		push_warning("无法清理阶段 1 临时测试文件，错误代码：%s" % remove_error)
