class_name ImmigrationRules
extends Resource

@export_category("移民条件")
@export var minimum_food_reserve: float = 30.0
@export var food_per_migrant: float = 10.0
@export var required_free_housing: int = 1

@export_category("移民节奏")
@export var arrival_interval: float = 30.0
@export var min_group_size: int = 1
@export var max_group_size: int = 2
