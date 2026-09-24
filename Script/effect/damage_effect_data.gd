class_name DamageEffectData
extends EffectData

@export_range(0.0, 1000.0, 0.1) var damage: float = 0.0

func apply_effect(_source: Node, target: Node, modifiers: Dictionary = {}) -> bool:
	if target != null and target.has_method("take_damage"):
		return float(target.take_damage(damage * float(modifiers.get("damage_multiplier", 1.0)), _source)) > 0.0
	return false
