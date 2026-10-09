class_name CombatRole
extends RefCounted


enum Type {
	NONE,
	SWORDSMAN,
	ARCHER,
	MILITIA
}

enum Duty {
	AVOID_DANGER,
	SELF_DEFENSE,
	ENGAGE
}

static func get_duty_display_name(duty: int) -> String:
	match duty:
		Duty.SELF_DEFENSE: return "自卫"
		Duty.ENGAGE: return "主动迎战"
		_: return "避险"


static func get_display_name(role: int) -> String:
	match role:
		Type.NONE:
			return "无"
		Type.SWORDSMAN:
			return "剑士"
		Type.ARCHER:
			return "弓箭手"
		Type.MILITIA:
			return "民兵"
		_:
			return "未知"
