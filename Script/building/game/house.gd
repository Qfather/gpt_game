class_name House
extends BuildingBase

@export var housing_capacity: int = 3


func _ready() -> void:
	super._ready()
	add_to_group("housing_buildings")


func get_housing_capacity() -> int:
	return housing_capacity
