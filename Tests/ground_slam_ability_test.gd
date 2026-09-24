extends SceneTree


func _init() -> void:
	var ability: AbilityData = preload("res://data/abilities/GroundSlam.tres")
	var runtime: AbilityRuntime = AbilityRuntime.new(ability)
	var owner: MockOwner = MockOwner.new()
	var target: MockTarget = MockTarget.new()
	_expect(runtime.try_use(owner, target), "Ground Slam 可以执行")
	_expect(is_equal_approx(target.received_damage, 8.0), "Ground Slam 造成配置伤害")
	runtime.start_cooldown()
	_expect(not runtime.can_use(owner), "Ground Slam 进入冷却")
	print("Ground Slam Ability V0 测试通过")
	quit()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		push_error("失败：" + message)
		quit(1)


class MockTarget extends Node3D:
	var received_damage: float = 0.0

	func get_faction() -> int:
		return 0

	func take_damage(amount: float, _source: Node) -> float:
		received_damage += amount
		return amount


class MockOwner extends Node3D:
	func get_faction() -> int:
		return 1
