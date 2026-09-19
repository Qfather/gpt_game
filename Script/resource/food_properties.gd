class_name FoodProperties
extends Resource

## 食物提供的基础营养值。
@export var nutrition: float = 0.0

## 食物品质，由后续食物系统决定具体用途。
@export var food_quality: float = 0.0

## 用于区分谷物、肉类等食物多样性分组。
@export var variety_group: StringName = &""
