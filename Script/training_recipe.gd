@tool
class_name TrainingRecipe
extends Resource

@export var unit_id: StringName = &"swordsman"
@export var cost: Dictionary[StringName, float] = {}
@export_range(0.1, 3600, 0.1) var time_seconds: float = 10.0
@export var enabled: bool = true
