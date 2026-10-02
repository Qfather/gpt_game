@tool
class_name ImmigrationGroup
extends Resource

@export var display_name: String = "新移民组"
@export_range(0, 1000, 1) var unlock_population: int = 0
@export_range(0.1, 1000, 0.1) var weight: float = 1.0
## 空标签表示任意食物；库存只检查，不额外扣除。
@export var food_tag: StringName = &""
@export_range(0, 1000000, 1) var food_amount: float = 40.0
@export var required_buildings: Array[BuildingData] = []
@export_range(1, 100, 1) var min_group_size: int = 1
@export_range(1, 100, 1) var max_group_size: int = 2
@export_range(1, 3600, 1) var arrival_interval: float = 30.0
@export var resident_traits: Array[UnitTrait] = []
