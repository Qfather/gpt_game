@tool
class_name ImmigrationRules
extends Resource

@export_category("阶段移民池")
## 非空时使用移民组；空池兼容原来的固定条件。
@export var groups: Array[ImmigrationGroup] = []

@export_category("移民条件")
@export var minimum_food_reserve: float = 30.0
@export var food_per_migrant: float = 10.0
@export var required_free_housing: int = 1

@export_category("移民节奏")
@export var arrival_interval: float = 30.0
@export var min_group_size: int = 1
@export var max_group_size: int = 2


func validation_error() -> String:
	var has_first_stage: bool = groups.is_empty()
	for group: ImmigrationGroup in groups:
		if group == null:
			return "请移除空移民组"
		if group.min_group_size < 1 or group.max_group_size < group.min_group_size:
			return group.display_name + "：移民人数范围无效"
		if group.weight <= 0.0 or group.arrival_interval <= 0.0 or group.food_amount < 0.0:
			return group.display_name + "：权重、到达间隔或库存要求无效"
		has_first_stage = has_first_stage or group.unlock_population == 0
	if not has_first_stage:
		return "移民池至少需要一个从0人口开始的组"
	return ""
