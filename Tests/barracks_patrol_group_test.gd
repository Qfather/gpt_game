extends SceneTree

var _failed: bool = false


class MockSwordsman:
	extends Node

	var garrisoned_in: Node = null
	var ready_for_patrol: bool = true
	var patrol_departures: int = 0

	func is_garrisoned() -> bool:
		return is_instance_valid(garrisoned_in)

	func is_ready_for_patrol() -> bool:
		return ready_for_patrol and is_garrisoned()

	func leave_garrison_for_patrol(
		barracks: Node,
		_assemble_position: Vector3
	) -> bool:
		if garrisoned_in != barracks:
			return false
		garrisoned_in = null
		patrol_departures += 1
		return true


func _initialize() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	var barracks: Barracks = Barracks.new()
	get_root().add_child(barracks)
	barracks.food_inventory[&"grain"] = 30.0

	var units: Array[MockSwordsman] = []
	for index: int in range(6):
		var unit: MockSwordsman = MockSwordsman.new()
		unit.name = "Swordsman%d" % index
		unit.garrisoned_in = barracks
		units.append(unit)
		barracks.garrisoned_units.append(unit)

	var incoming_unit: MockSwordsman = MockSwordsman.new()
	barracks.garrison_reservations.append(incoming_unit)
	barracks._try_start_auto_patrol()
	_expect(barracks.pending_patrol_units.is_empty(), "尚有驻军在入营途中时不会提前编组")
	barracks.garrison_reservations.clear()

	units[2].ready_for_patrol = false
	barracks._try_start_auto_patrol()
	_expect(barracks._get_current_patrol_group_count() == 3, "满编 6 人固定编成 3 人巡逻队")
	_expect(barracks.active_patrol_units.size() == 2, "状态正常的两名成员先到营外集合")
	_expect(barracks.pending_patrol_units.size() == 1, "吃饭中的第三名成员保留巡逻席位")

	units[2].ready_for_patrol = true
	barracks._dispatch_pending_patrol_units()
	_expect(barracks.active_patrol_units.size() == 3, "第三名成员恢复后加入原巡逻队")
	_expect(barracks.pending_patrol_units.is_empty(), "整组恢复后不再存在待出营成员")
	_expect(barracks._get_current_patrol_group_count() == 3, "等待过程不会把巡逻队缩编为 2 人")

	for unit: MockSwordsman in units:
		unit.free()
	incoming_unit.free()
	barracks.free()

	if _failed:
		printerr("军营固定巡逻编组测试失败")
		quit(1)
		return

	print("军营固定巡逻编组测试通过")
	quit()


func _expect(condition: bool, description: String) -> void:
	if condition:
		print("[通过] ", description)
		return

	_failed = true
	printerr("[失败] ", description)
