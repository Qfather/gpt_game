class_name BuildingData
extends Resource

@export_category("建筑标识")
@export var id: StringName
@export var display_name: String = ""

@export_category("建筑场景")
@export var building_scene: PackedScene

@export_category("建造参数")
@export var grid_size: Vector2i = Vector2i(1, 1)
@export var construction_cost: Dictionary = {}
@export var construction_time: float = 0.0
@export var max_construction_workers: int = 1

@export_category("放置选项")
@export var allow_rotation: bool = true
@export var allow_mirror: bool = true