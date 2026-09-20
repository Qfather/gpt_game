class_name ResourceStorage
extends Node


# ============================================================
# 信号
# ============================================================

signal resource_changed(
	resource_id: StringName,
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
@export var starting_grain: float = 0.0


# ============================================================
# 运行数据
# ============================================================

# 当前数量
var resources: Dictionary = {}

# 最大容量
var capacities: Dictionary = {}


# ============================================================
# 资源键兼容转换
# ============================================================

static func resource_id_from_key(resource_key: Variant) -> StringName:
	if resource_key is StringName:
		return resource_key

	if resource_key is String:
		return StringName(resource_key)

	if resource_key is int:
		match int(resource_key):
			ResourceType.Type.WOOD:
				return &"wood"
			ResourceType.Type.STONE:
				return &"stone"
			ResourceType.Type.FOOD:
				return &"food"

	return &""


static func resource_type_from_id(resource_key: Variant) -> ResourceType.Type:
	var resource_id: StringName = resource_id_from_key(resource_key)
	match resource_id:
		&"wood":
			return ResourceType.Type.WOOD
		&"stone":
			return ResourceType.Type.STONE
		&"food":
			return ResourceType.Type.FOOD

	return -1


# ============================================================
# 初始化
# ============================================================

func _ready() -> void:
	add_to_group("resource_storages")
	# --------------------------------------------------------
	# 设置容量
	# --------------------------------------------------------

	set_capacity(
		&"wood",
		wood_capacity
	)

	set_capacity(
		&"stone",
		stone_capacity
	)

	set_capacity(
		&"food",
		food_capacity
	)

	set_capacity(
		&"grain",
		food_capacity
	)


	# --------------------------------------------------------
	# 设置初始资源
	# --------------------------------------------------------

	if starting_wood > 0.0:
		add(
			&"wood",
			starting_wood
		)

	if starting_stone > 0.0:
		add(
			&"stone",
			starting_stone
		)

	if starting_food > 0.0:
		add(
			&"food",
			starting_food
		)

	if starting_grain > 0.0:
		add(
			&"grain",
			starting_grain
		)


# ============================================================
# 设置容量
# ============================================================

func set_capacity(
	resource_key: Variant,
	capacity: float
) -> void:
	var resource_id: StringName = resource_id_from_key(resource_key)
	if resource_id.is_empty():
		return

	var safe_capacity: float = maxf(
		capacity,
		0.0
	)

	capacities[resource_id] = safe_capacity

	# 如果降低容量以后资源超过新容量
	if get_amount(resource_id) > safe_capacity:

		resources[resource_id] = safe_capacity

		resource_changed.emit(
			resource_id,
			safe_capacity
		)


# ============================================================
# 获取容量
# ============================================================

func get_capacity(
	resource_key: Variant
) -> float:
	var resource_id: StringName = resource_id_from_key(resource_key)
	if resource_id.is_empty():
		return 0.0

	return float(
		capacities.get(
			resource_id,
			0.0
		)
	)


# ============================================================
# 获取当前数量
# ============================================================

func get_amount(
	resource_key: Variant
) -> float:
	var resource_id: StringName = resource_id_from_key(resource_key)
	if resource_id.is_empty():
		return 0.0

	return float(
		resources.get(
			resource_id,
			0.0
		)
	)


# ============================================================
# 获取剩余空间
# ============================================================

func get_free_space(
	resource_key: Variant
) -> float:

	return maxf(
		get_capacity(resource_key)
		- get_amount(resource_key),
		0.0
	)


# ============================================================
# 是否为空
# ============================================================

func is_empty(
	resource_key: Variant
) -> bool:

	return get_amount(resource_key) <= 0.0


# ============================================================
# 是否已满
# ============================================================

func is_full(
	resource_key: Variant
) -> bool:

	var capacity: float = get_capacity(resource_key)

	if capacity <= 0.0:
		return true

	return get_amount(resource_key) >= capacity


# ============================================================
# 是否拥有足够资源
# ============================================================

func has(
	resource_key: Variant,
	amount: float
) -> bool:

	if amount <= 0.0:
		return true

	return get_amount(resource_key) >= amount


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
	resource_key: Variant,
	amount: float
) -> float:
	var resource_id: StringName = resource_id_from_key(resource_key)
	if resource_id.is_empty():
		return 0.0

	if amount <= 0.0:
		return 0.0

	var free_space: float = get_free_space(resource_id)

	var added_amount: float = minf(
		amount,
		free_space
	)

	if added_amount <= 0.0:
		return 0.0

	var new_amount: float = (
		get_amount(resource_id)
		+ added_amount
	)

	resources[resource_id] = new_amount

	resource_changed.emit(
		resource_id,
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
	resource_key: Variant,
	amount: float
) -> float:
	var resource_id: StringName = resource_id_from_key(resource_key)
	if resource_id.is_empty():
		return 0.0

	if amount <= 0.0:
		return 0.0

	var current_amount: float = get_amount(resource_id)

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

	resources[resource_id] = new_amount

	resource_changed.emit(
		resource_id,
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
	resource_key: Variant,
	amount: float
) -> bool:
	var resource_id: StringName = resource_id_from_key(resource_key)
	if resource_id.is_empty():
		return false

	if amount <= 0.0:
		return true

	if not has(resource_id, amount):
		return false

	var new_amount: float = (
		get_amount(resource_id)
		- amount
	)

	resources[resource_id] = new_amount

	resource_changed.emit(
		resource_id,
		new_amount
	)

	return true
