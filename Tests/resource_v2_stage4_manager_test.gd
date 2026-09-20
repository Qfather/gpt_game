extends SceneTree

var _failed: bool = false


class TestVillager extends Node:
	var carried_resource_type: ResourceType.Type = ResourceType.Type.WOOD
	var carried_amount: float = 0.0

	func get_carried_resource_type() -> ResourceType.Type:
		return carried_resource_type

	func get_carried_amount() -> float:
		return carried_amount


func _initialize() -> void:
	var root: Node = get_root()
	var manager: ResourceManager = ResourceManager.new()
	var storage: ResourceStorage = ResourceStorage.new()
	var villager: TestVillager = TestVillager.new()

	root.add_child(manager)
	root.add_child(storage)
	root.add_child(villager)
	villager.add_to_group("villagers")

	storage.add(&"wood", 20.0)
	villager.carried_resource_type = ResourceType.Type.WOOD
	villager.carried_amount = 5.0

	_expect(manager.get_storage_total(&"wood") == 20.0, "Resource ID 可以查询储存总量")
	_expect(
		manager.get_storage_total(ResourceType.Type.WOOD) == 20.0,
		"旧枚举仍可以查询储存总量"
	)
	_expect(manager.get_carried_total(&"wood") == 5.0, "Resource ID 可以查询居民携带总量")
	_expect(
		manager.get_carried_total(ResourceType.Type.WOOD) == 5.0,
		"旧枚举仍可以查询居民携带总量"
	)
	_expect(manager.get_total(&"wood") == 25.0, "Resource ID 查询全局总量正确")
	_expect(
		manager.get_total(ResourceType.Type.WOOD) == 25.0,
		"旧枚举查询全局总量与新 ID 一致"
	)

	storage.take(&"wood", 8.0)
	villager.carried_amount = 2.0
	_expect(manager.get_total(&"wood") == 14.0, "储存和携带变化会反映到全局总量")
	_expect(manager.get_total(&"grain") == 0.0, "未使用资源 ID 的总量为零")

	root.remove_child(manager)
	root.remove_child(storage)
	root.remove_child(villager)
	manager.free()
	storage.free()
	villager.free()

	if _failed:
		printerr("资源系统 V2 阶段 4 ResourceManager 测试失败")
		quit(1)
		return

	print("资源系统 V2 阶段 4 ResourceManager 测试通过")
	quit()


func _expect(condition: bool, description: String) -> void:
	if condition:
		print("[通过] ", description)
		return

	_failed = true
	printerr("[失败] ", description)
