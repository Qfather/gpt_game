extends SceneTree

const TEST_PATH: String = "user://resource_editor_stage2_5_test.tres"
const EXPECTED_RESOURCE_COUNT: int = 7

var _failed: bool = false


func _initialize() -> void:
	var resources: Array[ResourceData] = ResourceEditorDataService.scan_resources()
	_expect(resources.size() == EXPECTED_RESOURCE_COUNT, "Resource Editor 可以扫描 7 种正式资源")
	_expect(
		ResourceEditorDataService.resource_id_exists(&"wood", resources),
		"可以检测已经存在的资源 ID"
	)
	_expect(
		ResourceEditorDataService.normalize_id(" Test Resource ") == "test_resource",
		"资源 ID 可以规范化"
	)
	_expect(ResourceEditorDataService.is_valid_id("test_resource_2"), "合法 ID 可以通过")
	_expect(not ResourceEditorDataService.is_valid_id(""), "空 ID 会被拒绝")
	_expect(not ResourceEditorDataService.is_valid_id("测试资源"), "中文 ID 会被拒绝")
	_expect(not ResourceEditorDataService.is_valid_id("Test-Resource"), "非法字符会被拒绝")

	var wood: ResourceData = _find_resource(resources, &"wood")
	var references: PackedStringArray = ResourceEditorDataService.find_database_references(wood)
	_expect(
		references.has(ResourceEditorDataService.DATABASE_PATH),
		"数据库引用中的资源会被删除保护识别"
	)

	_test_save_and_reload()
	_cleanup_test_file()
	_finish()


func _test_save_and_reload() -> void:
	var test_resource: ResourceData = ResourceData.new()
	test_resource.id = &"editor_test_resource"
	test_resource.display_name = "编辑器测试资源"
	test_resource.category = ResourceData.ResourceCategory.GOODS
	test_resource.tier = 2
	test_resource.tags = [&"test", &"processed"]
	test_resource.stack_size = 25

	var save_error: Error = ResourceSaver.save(test_resource, TEST_PATH)
	_expect(save_error == OK, "测试资源可以保存")
	if save_error != OK:
		return

	var loaded_resource: Resource = ResourceLoader.load(
		TEST_PATH,
		"",
		ResourceLoader.CACHE_MODE_REPLACE
	)
	var loaded_data: ResourceData = loaded_resource as ResourceData
	_expect(loaded_data != null, "保存后可以重新读取")
	if loaded_data == null:
		return

	var original_id: StringName = loaded_data.id
	loaded_data.display_name = "修改后的显示名称"
	save_error = ResourceSaver.save(loaded_data, TEST_PATH)
	_expect(save_error == OK, "修改后可以再次保存")

	loaded_resource = ResourceLoader.load(
		TEST_PATH,
		"",
		ResourceLoader.CACHE_MODE_REPLACE
	)
	loaded_data = loaded_resource as ResourceData
	_expect(loaded_data != null, "修改后可以重新读取")
	if loaded_data != null:
		_expect(loaded_data.id == original_id, "修改显示名称不会改变稳定 ID")
		_expect(loaded_data.display_name == "修改后的显示名称", "显示名称修改正确保存")


func _find_resource(
	resources: Array[ResourceData],
	resource_id: StringName
) -> ResourceData:
	for resource_data: ResourceData in resources:
		if resource_data.id == resource_id:
			return resource_data
	return null


func _expect(condition: bool, description: String) -> void:
	if condition:
		print("[通过] ", description)
		return

	_failed = true
	printerr("[失败] ", description)


func _cleanup_test_file() -> void:
	if not FileAccess.file_exists(TEST_PATH):
		return

	var remove_error: Error = DirAccess.remove_absolute(
		ProjectSettings.globalize_path(TEST_PATH)
	)
	if remove_error != OK:
		push_warning("无法清理 Resource Editor 临时测试文件：%s" % remove_error)


func _finish() -> void:
	if _failed:
		printerr("资源系统 V2 阶段 2.5 测试失败")
		quit(1)
		return

	print("资源系统 V2 阶段 2.5 测试通过")
	quit()
