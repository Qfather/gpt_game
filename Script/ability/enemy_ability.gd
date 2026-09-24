class_name EnemyAbility
extends Resource

@export var ability_id: StringName = &""
@export var display_name: String = ""
@export_range(0.0, 10000.0, 0.1) var cooldown: float = 0.0


func can_use(_owner: Node) -> bool:
	return false


func try_use(_owner: Node, _target: Node, _modifiers: Dictionary = {}) -> bool:
	return false
