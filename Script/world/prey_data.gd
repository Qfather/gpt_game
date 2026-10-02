@tool
class_name PreyData
extends Resource

@export var id: StringName
@export var display_name: String
@export var scene: PackedScene
@export_range(1, 100, 1) var health: int = 1
@export_range(1, 100, 1) var meat_yield: int = 1
@export_range(0.1, 20, 0.1) var flee_speed: float = 2.0
@export_range(0.1, 100, 0.1) var weight: float = 1.0
