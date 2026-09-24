class_name Gate
extends BuildingBase

signal health_changed(current_health: float, max_health: float)

@onready var durability: BuildingDurability = $BuildingDurability

func _ready() -> void:
	super._ready()
	durability.health_changed.connect(func(current: float, maximum: float) -> void: health_changed.emit(current, maximum))
	durability.destroyed.connect(_on_destroyed)

func get_max_health() -> float:
	return durability.max_health

func get_health() -> float:
	return durability.current_health

func take_damage(amount: float, source: Node = null) -> float:
	return durability.take_damage(amount, source)

func _on_destroyed() -> void:
	hide()
