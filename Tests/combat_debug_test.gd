extends SceneTree


func _init() -> void:
	CombatDebug.set_enabled(false)
	_expect(not CombatDebug.should_show_aggro_ranges(), "关闭战斗调试后不显示仇恨范围")
	CombatDebug.set_enabled(true)
	_expect(CombatDebug.should_show_aggro_ranges(), "开启战斗调试后显示仇恨范围")
	print("Combat Debug 开关测试通过")
	quit()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		push_error("失败：" + message)
		quit(1)
