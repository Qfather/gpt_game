extends SceneTree

var _failed: bool = false


class RefundBase extends Node:
	var refunded: Dictionary[StringName, float] = {}

	func add_resource(resource_id: StringName, amount: float) -> float:
		refunded[resource_id] = float(refunded.get(resource_id, 0.0)) + amount
		return amount


func _initialize() -> void:
	var root: Node = Node.new()
	get_root().add_child(root)

	var base: RefundBase = RefundBase.new()
	base.add_to_group("bases")
	root.add_child(base)

	var building: BuildingBase = BuildingBase.new()
	root.add_child(building)
	await process_frame

	var data: BuildingData = BuildingData.new()
	data.construction_cost = {
		&"wood": 20.0,
		&"stone": 10.0,
	}
	building.set_building_data(data)

	_expect(building.can_be_demolished(), "正式建筑可以拆除")
	_expect(building.demolish(), "拆除请求可以执行")
	_expect(
		float(base.refunded.get(&"wood", 0.0)) == 0.0,
		"拆除完成前不会瞬间返还木材"
	)
	_expect(
		float(base.refunded.get(&"stone", 0.0)) == 0.0,
		"拆除完成前不会瞬间返还石材"
	)
	_expect(building.is_demolition_in_progress(), "拆除请求进入进行中状态")

	var base_building: BuildingBase = BuildingBase.new()
	base_building.add_to_group("bases")
	root.add_child(base_building)
	base_building.set_building_data(data)
	_expect(not base_building.can_be_demolished(), "Base 不允许拆除")

	root.free()
	if _failed:
		printerr("建筑拆除测试失败")
		quit(1)
		return

	print("建筑拆除测试通过")
	quit()


func _expect(condition: bool, description: String) -> void:
	if condition:
		print("[通过] ", description)
		return

	_failed = true
	printerr("[失败] ", description)
