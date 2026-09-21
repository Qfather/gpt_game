class_name HealthComponent
extends Node


signal health_changed(current_health: float, max_health: float)
signal damaged(amount: float, source: Node)
signal died(source: Node)

var max_health: float = 1.0
var current_health: float = 1.0
var dead: bool = false


func setup(initial_max_health: float) -> void:
	max_health = maxf(initial_max_health, 1.0)
	current_health = max_health
	dead = false


func take_damage(amount: float, source: Node = null) -> float:
	if dead or amount <= 0.0:
		return 0.0

	var actual_damage: float = minf(amount, current_health)
	current_health = maxf(current_health - actual_damage, 0.0)
	damaged.emit(actual_damage, source)
	health_changed.emit(current_health, max_health)

	if current_health <= 0.0:
		dead = true
		died.emit(source)

	return actual_damage


func is_dead() -> bool:
	return dead
