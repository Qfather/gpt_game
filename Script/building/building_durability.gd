class_name BuildingDurability
extends Node


signal health_changed(current_health: float, max_health: float)
signal damage_state_changed(state: DamageState)
signal destroyed

enum DamageState {
	HEALTHY,
	DAMAGED,
	HEAVY_DAMAGED,
	DESTROYED,
}

@export_range(1.0, 1000000.0, 1.0) var max_health: float = 1000.0
@export_range(0.0, 1.0, 0.01) var damaged_threshold: float = 0.7
@export_range(0.0, 1.0, 0.01) var heavy_damaged_threshold: float = 0.3

var current_health: float = 0.0
var damage_state: DamageState = DamageState.HEALTHY
var _destroyed_emitted: bool = false


func _ready() -> void:
	setup(max_health)


func setup(initial_max_health: float) -> void:
	max_health = maxf(initial_max_health, 1.0)
	current_health = max_health
	_destroyed_emitted = false
	_set_damage_state(DamageState.HEALTHY)
	health_changed.emit(current_health, max_health)


func take_damage(amount: float, _source: Node = null) -> float:
	if is_destroyed():
		return 0.0
	var actual_damage: float = minf(maxf(amount, 0.0), current_health)
	if actual_damage <= 0.0:
		return 0.0
	current_health = maxf(current_health - actual_damage, 0.0)
	health_changed.emit(current_health, max_health)
	_update_damage_state()
	if is_destroyed() and not _destroyed_emitted:
		_destroyed_emitted = true
		destroyed.emit()
	return actual_damage


func repair(amount: float) -> float:
	if is_destroyed():
		return 0.0
	var actual_repair: float = minf(maxf(amount, 0.0), max_health - current_health)
	if actual_repair <= 0.0:
		return 0.0
	current_health += actual_repair
	health_changed.emit(current_health, max_health)
	_update_damage_state()
	return actual_repair


func get_health_ratio() -> float:
	return clampf(current_health / max_health, 0.0, 1.0)


func is_damaged() -> bool:
	return damage_state != DamageState.HEALTHY


func is_destroyed() -> bool:
	return damage_state == DamageState.DESTROYED


func _update_damage_state() -> void:
	var next_state: DamageState = DamageState.HEALTHY
	var ratio: float = get_health_ratio()
	if current_health <= 0.0:
		next_state = DamageState.DESTROYED
	elif ratio <= heavy_damaged_threshold:
		next_state = DamageState.HEAVY_DAMAGED
	elif ratio <= damaged_threshold:
		next_state = DamageState.DAMAGED
	_set_damage_state(next_state)


func _set_damage_state(next_state: DamageState) -> void:
	if damage_state == next_state:
		return
	damage_state = next_state
	damage_state_changed.emit(damage_state)
