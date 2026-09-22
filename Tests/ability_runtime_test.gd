extends SceneTree


func _init() -> void:
	var shared_ability: EnemyAbility = EnemyAbility.new()
	shared_ability.ability_id = &"test_ability"
	shared_ability.cooldown = 8.0
	var first: AbilityRuntime = AbilityRuntime.new(shared_ability)
	var second: AbilityRuntime = AbilityRuntime.new(shared_ability)
	first.start_cooldown()
	_expect(is_equal_approx(first.cooldown_remaining, 8.0), "第一个单位拥有独立冷却")
	_expect(is_equal_approx(second.cooldown_remaining, 0.0), "第二个单位不会共享冷却")
	first.tick(3.0)
	_expect(is_equal_approx(first.cooldown_remaining, 5.0), "Runtime 可以独立推进冷却")
	_expect(is_equal_approx(second.cooldown_remaining, 0.0), "第二个 Runtime 仍保持独立")
	print("Ability Runtime 接口测试通过")
	quit()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		push_error("失败：" + message)
		quit(1)
