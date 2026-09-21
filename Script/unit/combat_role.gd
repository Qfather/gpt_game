class_name CombatRole
extends RefCounted


enum Type {
	NONE,
	SWORDSMAN
}


static func get_display_name(role: int) -> String:
	match role:
		Type.NONE:
			return "无"
		Type.SWORDSMAN:
			return "剑士"
		_:
			return "未知"
