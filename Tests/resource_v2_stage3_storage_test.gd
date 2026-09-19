extends SceneTree

var _failed: bool = false


class SignalProbe extends RefCounted:
	var ids: Array[StringName] = []
	var amounts: Array[float] = []

	func on_resource_changed(resource_id: StringName, new_amount: float) -> void:
		ids.append(resource_id)
		amounts.append(new_amount)


func _initialize() -> void:
	var storage: ResourceStorage = ResourceStorage.new()
	var probe: SignalProbe = SignalProbe.new()
	storage.resource_changed.connect(probe.on_resource_changed)

	_expect(
		ResourceStorage.resource_id_from_key(ResourceType.Type.WOOD) == &"wood",
		"旧 WOOD 枚举可以转换为 wood ID"
	)
	_expect(
		ResourceStorage.resource_id_from_key(&"stone") == &"stone",
		"StringName stone 可以保持为资源 ID"
	)
	_expect(
		ResourceStorage.resource_id_from_key("food") == &"food",
		"String food 可以转换为资源 ID"
	)

	storage.set_capacity(&"wood", 100.0)
	storage.set_capacity(ResourceType.Type.STONE, 40.0)
	storage.set_capacity(ResourceType.Type.FOOD, 20.0)

	_expect(storage.add(&"wood", 20.0) == 20.0, "新 ID 接口可以添加木材")
	_expect(storage.add(ResourceType.Type.WOOD, 5.0) == 5.0, "旧枚举接口可以添加木材")
	_expect(storage.get_amount(&"wood") == 25.0, "新旧接口读取同一份木材库存")
	_expect(
		storage.get_amount(ResourceType.Type.WOOD) == 25.0,
		"旧枚举读取到同一份木材库存"
	)

	_expect(storage.add(&"stone", 10.0) == 10.0, "石材 ID 可以添加资源")
	_expect(storage.take(ResourceType.Type.STONE, 4.0) == 4.0, "石材旧枚举可以取出资源")
	_expect(storage.get_amount(&"stone") == 6.0, "石材新旧接口数量一致")
	_expect(not storage.consume("food", 1.0), "资源不足时字符串 ID 消耗会失败")
	_expect(storage.get_amount(ResourceType.Type.FOOD) == 0.0, "未添加的食物库存保持为零")

	_expect(storage.resources.has(&"wood"), "内部库存使用 wood ID 键")
	_expect(not storage.resources.has(ResourceType.Type.WOOD), "内部库存不再使用旧枚举键")
	_expect(probe.ids.size() == 4, "资源变化信号按实际库存变化触发")
	_expect(probe.ids[-1] == &"stone", "资源变化信号传递资源 ID")
	storage.free()

	if _failed:
		printerr("资源系统 V2 阶段 3 ResourceStorage 测试失败")
		quit(1)
		return

	print("资源系统 V2 阶段 3 ResourceStorage 测试通过")
	quit()


func _expect(condition: bool, description: String) -> void:
	if condition:
		print("[通过] ", description)
		return

	_failed = true
	printerr("[失败] ", description)
