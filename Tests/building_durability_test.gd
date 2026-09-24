extends SceneTree


func _init() -> void:
	var durability: BuildingDurability = BuildingDurability.new()
	durability.setup(1000.0)
	_expect(durability.damage_state == BuildingDurability.DamageState.HEALTHY, "初始状态为 HEALTHY")
	durability.take_damage(400.0)
	_expect(is_equal_approx(durability.current_health, 600.0), "受到伤害后生命值正确")
	_expect(durability.damage_state == BuildingDurability.DamageState.DAMAGED, "60% 生命为 DAMAGED")
	durability.take_damage(400.0)
	_expect(durability.damage_state == BuildingDurability.DamageState.HEAVY_DAMAGED, "20% 生命为 HEAVY_DAMAGED")
	durability.repair(200.0)
	_expect(durability.damage_state == BuildingDurability.DamageState.DAMAGED, "修复后状态恢复")
	durability.repair(600.0)
	_expect(durability.current_health == 1000.0, "修复不会超过最大生命")
	durability.take_damage(1000.0)
	_expect(durability.is_destroyed(), "生命归零为 DESTROYED")
	print("Building Durability V0 测试通过")
	quit()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		push_error("失败：" + message)
		quit(1)
