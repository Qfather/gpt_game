extends SceneTree


func _init() -> void:
	var ability: AbilityData = preload("res://data/abilities/GroundSlam.tres")
	var entry := AbilityEntry.new()
	entry.ability = ability
	entry.damage_multiplier = 2.0
	var runtime := AbilityRuntime.new(ability, entry)
	var owner := MockOwner.new()
	var target := MockTarget.new()
	_expect(runtime.try_use(owner, target), "覆盖后的技能可以执行")
	_expect(is_equal_approx(target.received_damage, 16.0), "角色覆盖层修改技能伤害")
	print("Ability 覆盖层测试通过")
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
