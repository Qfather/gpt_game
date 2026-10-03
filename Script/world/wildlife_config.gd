@tool
class_name WildlifeConfig
extends Resource

const PreyDataResource = preload("res://Script/world/prey_data.gd")

@export var enabled: bool = true
@export_range(0, 100, 1) var maximum_animals: int = 12
@export_range(1, 600, 1) var refresh_interval: float = 20.0
@export_range(0, 100, 0.1) var minimum_base_distance: float = 15.0
@export_range(1, 200, 0.1) var maximum_base_distance: float = 35.0
@export var prey_pool: Array[PreyDataResource] = []
