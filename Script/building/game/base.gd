extends BuildingBase


# ============================================================
# 信号
# ============================================================

# 新的通用资源变化信号
signal resource_changed(
	resource_id: StringName,
	new_amount: float
)

# ------------------------------------------------------------
# 旧木材信号
#
# 暂时保留。
# 现有 HUD / UI 如果还在监听 wood_changed，
# 不需要马上跟着重构。
# ------------------------------------------------------------

signal wood_changed(new_amount: int)


# ============================================================
# 节点
# ============================================================

@onready var storage: ResourceStorage = get_node_or_null(
	"ResourceStorage"
) as ResourceStorage
# ============================================================
# 参数
# ============================================================

# 无业居民待命范围
@export var idle_radius: float = 5.0


# ============================================================
# 初始化
# ============================================================

func _ready():
	super._ready()

	if storage == null:
		push_error(
			"Base：没有找到 ResourceStorage 子节点"
		)
		return

	storage.resource_changed.connect(
		_on_storage_resource_changed
	)

# ============================================================
# 通用资源接口
# ============================================================

func get_resource(
	resource_key: Variant
) -> float:

	if storage == null:
		storage = get_node_or_null("ResourceStorage") as ResourceStorage

	if storage == null:
		push_warning("Base：ResourceStorage 尚未初始化")
		return 0.0

	return storage.get_amount(resource_key)


func add_resource(
	resource_key: Variant,
	amount: float
) -> float:

	if storage == null:
		return 0.0

	return storage.add(
		resource_key,
		amount
	)


func has_resource(
	resource_key: Variant,
	amount: float
) -> bool:

	if storage == null:
		return false

	return storage.has(
		resource_key,
		amount
	)


func take_resource(
	resource_key: Variant,
	amount: float
) -> float:

	if storage == null:
		return 0.0

	return storage.take(
		resource_key,
		amount
	)


func consume_resource(
	resource_key: Variant,
	amount: float
) -> bool:

	if storage == null:
		return false

	return storage.consume(
		resource_key,
		amount
	)


# ============================================================
# 仓储变化
# ============================================================

func _on_storage_resource_changed(
	resource_id: StringName,
	new_amount: float
):

	# 对外发送新的通用信号
	resource_changed.emit(
		resource_id,
		new_amount
	)

	# --------------------------------------------------------
	# 兼容旧木材 UI
	# --------------------------------------------------------

	if resource_id == &"wood":

		wood_changed.emit(
			int(new_amount)
		)


# ============================================================
# 旧木材接口
# ============================================================
#
# 暂时保留。
#
# Villager 目前仍然可以：
#
# target_base.deposit_wood(10)
#
# 但是内部实际上已经进入新的 ResourceStorage。
#
# ============================================================

func deposit_wood(amount: int):

	var stored_amount: float = add_resource(
		&"wood",
		float(amount)
	)

	print(
		"🏠 据点收到木材：",
		stored_amount,
		" 当前总木材：",
		get_resource(&"wood")
	)
