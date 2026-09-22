extends SceneTree


func _init() -> void:
	var shared_effect: EffectData = EffectData.new()
	shared_effect.effect_id = &"test_damage"
	var first: EffectRuntime = EffectRuntime.new(shared_effect)
	var second: EffectRuntime = EffectRuntime.new(shared_effect)
	_expect(first.effect == shared_effect, "Effect Runtime 保存配置引用")
	_expect(second.effect == shared_effect, "多个单位可以共享 Effect 配置")
	_expect(first != second, "每个单位拥有独立 Effect Runtime")
	_expect(not first.apply(null, null), "阶段 5 不执行实际效果")
	print("Effect Runtime 接口测试通过")
	quit()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		push_error("失败：" + message)
		quit(1)
