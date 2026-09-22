class_name AbilityRuntime
extends RefCounted


var ability: EnemyAbility
var cooldown_remaining: float = 0.0


func _init(source_ability: EnemyAbility = null) -> void:
	ability = source_ability


func tick(delta: float) -> void:
	cooldown_remaining = maxf(cooldown_remaining - maxf(delta, 0.0), 0.0)


func can_use(owner: Node) -> bool:
	return ability != null and cooldown_remaining <= 0.0 and ability.can_use(owner)


func try_use(owner: Node, target: Node) -> bool:
	if not can_use(owner):
		return false
	if not ability.try_use(owner, target):
		return false
	cooldown_remaining = maxf(ability.cooldown, 0.0)
	return true


func start_cooldown() -> void:
	if ability != null:
		cooldown_remaining = maxf(ability.cooldown, 0.0)

