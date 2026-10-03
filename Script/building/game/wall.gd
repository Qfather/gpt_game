class_name Wall
extends BuildingBase


@onready var durability: BuildingDurability = $BuildingDurability


func _ready() -> void:
	super._ready()
	durability.health_changed.connect(_on_health_changed)
	durability.destroyed.connect(_on_destroyed)


func get_max_health() -> float:
	return durability.max_health


func get_health() -> float:
	return durability.current_health


func take_damage(amount: float, source: Node = null) -> float:
	return durability.take_damage(amount, source)


func _on_health_changed(current: float, maximum: float) -> void:
	health_changed.emit(current, maximum)


func _on_destroyed() -> void:
	release_build_grid_area()
	queue_free()
