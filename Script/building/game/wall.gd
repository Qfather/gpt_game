class_name Wall
extends BuildingBase

signal health_changed(current_health: float, max_health: float)

@onready var durability: BuildingDurability = $BuildingDurability


func _ready() -> void:
	super._ready()
	durability.health_changed.connect(_on_health_changed)
	durability.destroyed.connect(_on_destroyed)
	add_to_group("navigation_solid_buildings")
	tree_exiting.connect(_request_navigation_update)
	# 建造系统在 add_child 后设置位置/旋转，下一轮再烘焙最终变换。
	call_deferred("_request_navigation_update")


func _request_navigation_update() -> void:
	get_tree().call_group("map_generate_runtime", "request_navigation_update")


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
