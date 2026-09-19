class_name ResourceStorage
extends Node


# ============================================================
# 信号
# ============================================================

signal resource_changed(
	resource_type: ResourceType.Type,
	new_amount: float
)


# ============================================================
# Inspector - 容量
# ============================================================

@export_category("资源容量")

@export var wood_capacity: float = 1000.0
@export var stone_capacity: float = 1000.0
@export var food_capacity: float = 1000.0


# ============================================================
# Inspector - 初始资源
# ============================================================

@export_category("初始资源")

@export var starting_wood: float = 0.0
@export var starting_stone: float = 0.0
@export var starting_food: float = 0.0


# ============================================================
# 运行数据
# ============================================================

# 当前数量
var resources: Dictionary = {}

# 最大容量
var capacities: Dictionary = {}


# ============================================================
# 初始化
# ============================================================

func _ready():

	# --------------------------------------------------------
	# 设置容量
	# --------------------------------------------------------

	set_capacity(
		ResourceType.Type.WOOD,
		wood_capacity
	)

	set_capacity(
		ResourceType.Type.STONE,
		stone_capacity
	)

	set_capacity(
		ResourceType.Type.FOOD,
		food_capacity
	)


	# --------------------------------------------------------
	# 设置初始资源
	# --------------------------------------------------------

	if starting_wood > 0.0:
		add(
			ResourceType.Type.WOOD,
			starting_wood
		)

	if starting_stone > 0.0:
		add(
			ResourceType.Type.STONE,
			starting_stone
		)

	if starting_food > 0.0:
		add(
			ResourceType.Type.FOOD,
			starting_food
		)


# ============================================================
# 设置容量
# ============================================================

func set_capacity(
	resource_type: ResourceType.Type,
	capacity: float
):

	var safe_capacity: float = maxf(
		capacity,
		0.0
	)

	capacities[resource_type] = safe_capacity

	# 如果降低容量以后资源超过新容量
	if get_amount(resource_type) > safe_capacity:

		resources[resource_type] = safe_capacity

		resource_changed.emit(
			resource_type,
			safe_capacity
		)


# ============================================================
# 获取容量
# ============================================================

func get_capacity(
	resource_type: ResourceType.Type
) -> float:

	return float(
		capacities.get(
			resource_type,
			0.0
		)
	)


# ============================================================
# 获取当前数量
# ============================================================

func get_amount(
	resource_type: ResourceType.Type
) -> float:

	return float(
		resources.get(
			resource_type,
			0.0
		)
	)


# ============================================================
# 获取剩余空间
# ============================================================

func get_free_space(
	resource_type: ResourceType.Type
) -> float:

	return maxf(
		get_capacity(resource_type)
		- get_amount(resource_type),
		0.0
	)


# ============================================================
# 是否为空
# ============================================================

func is_empty(
	resource_type: ResourceType.Type
) -> bool:

	return get_amount(resource_type) <= 0.0


# ============================================================
# 是否已满
# ============================================================

func is_full(
	resource_type: ResourceType.Type
) -> bool:

	var capacity: float = get_capacity(resource_type)

	if capacity <= 0.0:
		return true

	return get_amount(resource_type) >= capacity


# ============================================================
# 是否拥有足够资源
# ============================================================

func has(
	resource_type: ResourceType.Type,
	amount: float
) -> bool:

	if amount <= 0.0:
		return true

	return get_amount(resource_type) >= amount


# ============================================================
# 添加资源
# ============================================================
#
# 返回实际成功存入的数量。
#
# 例如：
# 当前 90 / 100
# add(WOOD, 30)
# 实际存入 10
# 返回 10
#
# ============================================================

func add(
	resource_type: ResourceType.Type,
	amount: float
) -> float:

	if amount <= 0.0:
		return 0.0

	var free_space: float = get_free_space(resource_type)

	var added_amount: float = minf(
		amount,
		free_space
	)

	if added_amount <= 0.0:
		return 0.0

	var new_amount: float = (
		get_amount(resource_type)
		+ added_amount
	)

	resources[resource_type] = new_amount

	resource_changed.emit(
		resource_type,
		new_amount
	)

	return added_amount


# ============================================================
# 取出资源
# ============================================================
#
# take() 可以部分取出。
#
# 当前只有 20
# take(WOOD, 50)
# 返回 20
#
# ============================================================

func take(
	resource_type: ResourceType.Type,
	amount: float
) -> float:

	if amount <= 0.0:
		return 0.0

	var current_amount: float = get_amount(resource_type)

	var taken_amount: float = minf(
		amount,
		current_amount
	)

	if taken_amount <= 0.0:
		return 0.0

	var new_amount: float = (
		current_amount
		- taken_amount
	)

	resources[resource_type] = new_amount

	resource_changed.emit(
		resource_type,
		new_amount
	)

	return taken_amount


# ============================================================
# 消耗资源
# ============================================================
#
# consume() 必须完全够才会扣。
#
# 建筑需要 100 木材
# 当前只有 80
# consume(WOOD, 100)
# → false
# → 80 木材保持不变
#
# ============================================================

func consume(
	resource_type: ResourceType.Type,
	amount: float
) -> bool:

	if amount <= 0.0:
		return true

	if not has(resource_type, amount):
		return false

	var new_amount: float = (
		get_amount(resource_type)
		- amount
	)

	resources[resource_type] = new_amount

	resource_changed.emit(
		resource_type,
		new_amount
	)

	return true
