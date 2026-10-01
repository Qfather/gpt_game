@tool
class_name CampRewardEntry
extends Resource

@export var resource: ResourceData
@export_range(0.0, 1000.0, 0.1) var weight: float = 1.0
@export_range(1, 10000, 1) var minimum_amount: int = 5
@export_range(1, 10000, 1) var maximum_amount: int = 10
