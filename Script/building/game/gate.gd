class_name Gate
extends BuildingBase

const CONNECTIONS: Script = preload("res://Script/building/wall_connections.gd")


@onready var durability: BuildingDurability = $BuildingDurability

func _ready() -> void:
	super._ready()
	tree_exited.connect(func() -> void: CONNECTIONS.refresh(Engine.get_main_loop() as SceneTree))
	durability.health_changed.connect(func(current: float, maximum: float) -> void: health_changed.emit(current, maximum))
	durability.destroyed.connect(_on_destroyed)

func get_max_health() -> float:
	return durability.max_health

func get_health() -> float:
	return durability.current_health

func take_damage(amount: float, source: Node = null) -> float:
	return durability.take_damage(amount, source)

func _on_destroyed() -> void:
	release_build_grid_area()
	hide()
	queue_free()


func set_build_grid_occupancy(cell: Vector2i, size: Vector2i, turns: int) -> void:
	super.set_build_grid_occupancy(cell, size, turns)
	if is_inside_tree(): CONNECTIONS.refresh(get_tree())
