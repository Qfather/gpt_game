class_name ResourceData
extends Resource

enum ResourceCategory {
	RAW_MATERIAL,
	BUILDING_MATERIAL,
	FOOD,
	METAL,
	TOOL,
	GOODS,
	LUXURY,
	FUEL,
}

@export_category("资源标识")
## 稳定资源 ID。创建后不应随显示名称变化。
@export var id: StringName = &""
@export var display_name: String = ""

@export_category("资源分类")
@export var category: ResourceCategory = ResourceCategory.RAW_MATERIAL
@export_range(1, 100, 1) var tier: int = 1
@export var tags: Array[StringName] = []

@export_category("资源显示与堆叠")
@export var icon: Texture2D
@export_range(1, 1000000, 1) var stack_size: int = 100

@export_category("食物属性")
@export var food_properties: FoodProperties


func has_tag(tag: StringName) -> bool:
	return tag in tags


func is_food() -> bool:
	return food_properties != null
