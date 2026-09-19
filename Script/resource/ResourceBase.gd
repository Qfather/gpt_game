class_name ResourceBase
extends Node3D


# ============================================================
# 参数
# ============================================================

# 资源类型统一使用全局 ResourceType
var resource_type: ResourceType.Type = ResourceType.Type.WOOD

@export var min_amount: int = 5
@export var max_amount: int = 10


# ============================================================
# 运行数据
# ============================================================

var resource_amount: int = 0
var reserved_by: Node = null


# ============================================================
# 初始化
# ============================================================

func _ready():

	resource_amount = randi_range(
		min_amount,
		max_amount
	)

	print(
		"🌍 ResourceBase启动：",
		name,
		" | groups = ",
		get_groups(),
		" | type = ",
		resource_type
	)


# ============================================================
# 预约
# ============================================================

func is_reserved() -> bool:
	return reserved_by != null


func reserve(worker: Node) -> bool:

	if is_reserved():
		return false

	reserved_by = worker
	return true


func release(worker: Node):

	if reserved_by == worker:
		reserved_by = null


# ============================================================
# 采集
# ============================================================

func gather(amount: int) -> int:

	var gathered_amount: int = mini(
		amount,
		resource_amount
	)

	resource_amount -= gathered_amount

	print(
		"⛏️ 采集资源：",
		gathered_amount,
		" 剩余：",
		resource_amount
	)

	if resource_amount <= 0:
		queue_free()

	return gathered_amount
