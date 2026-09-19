class_name ResourceBuildingBase
extends BuildingBase


# ============================================================
# 资源建筑配置
# ============================================================

## 当前建筑生产的资源类型
@export var production_resource_type: ResourceType.Type = ResourceType.Type.WOOD

## 最大工人数
@export var max_workers: int = 3

## 工人搜索资源的工作范围
@export var work_radius: float = 10.0

## 工人空闲活动范围
@export var idle_radius: float = 2.5


# ============================================================
# 当前工人
# ============================================================

var workers: Array[Node] = []


# ============================================================
# ResourceStorage
# ============================================================

@onready var storage: ResourceStorage = get_node_or_null("ResourceStorage")


# ============================================================
# 初始化
# ============================================================

func _ready() -> void:

	super._ready()

	if storage == null:
		push_warning(
			"ResourceBuildingBase：%s 没有找到 ResourceStorage" % name
		)


# ============================================================
# 子类职业配置
# ============================================================

## 子类需要重写这个函数。
##
## LumberCamp → LUMBERJACK
## Quarry     → MINER
func get_worker_job() -> int:

	return -1


# ============================================================
# 当前工人数
# ============================================================

func get_worker_count() -> int:

	return workers.size()


func get_max_worker_count() -> int:

	return max_workers


# ============================================================
# 是否还有空岗位
# ============================================================

func has_free_slot() -> bool:

	return workers.size() < max_workers


# ============================================================
# 添加工人
# ============================================================

func add_worker(worker: Node) -> bool:

	if worker == null:
		return false


	if not has_free_slot():

		print("❌ ", name, " 岗位已满")

		return false


	if worker in workers:

		print(
			"❌ ",
			worker.name,
			" 已经在 ",
			name,
			" 工作"
		)

		return false


	if not worker.has_method("assign_job"):

		print("❌ 这个节点不能成为工人")

		return false


	workers.append(worker)

	assign_worker_job(worker)


	print(
		"👷 ",
		name,
		" 增加工人：",
		worker.name,
		" ",
		workers.size(),
		"/",
		max_workers
	)


	return true


# ============================================================
# 移除工人
# ============================================================

func remove_worker(worker: Node) -> bool:

	if worker not in workers:
		return false


	workers.erase(worker)


	if worker.has_method("quit_job"):
		worker.quit_job()


	return true


# ============================================================
# 工作范围
# ============================================================

func is_position_in_work_range(
	target_position: Vector3
) -> bool:

	var distance: float = global_position.distance_to(
		target_position
	)

	return distance <= work_radius


# ============================================================
# 通用资源库存
# ============================================================

func deposit_resource(
	resource_type: ResourceType.Type,
	amount: float
) -> float:

	if storage == null:
		return 0.0


	return storage.add(
		resource_type,
		amount
	)


func take_resource(
	resource_type: ResourceType.Type,
	amount: float
) -> float:

	if storage == null:
		return 0.0


	return storage.take(
		resource_type,
		amount
	)


func has_resource(
	resource_type: ResourceType.Type
) -> bool:

	if storage == null:
		return false


	return not storage.is_empty(
		resource_type
	)


func get_resource_amount(
	resource_type: ResourceType.Type
) -> float:

	if storage == null:
		return 0.0


	return storage.get_amount(
		resource_type
	)


func get_resource_capacity(
	resource_type: ResourceType.Type
) -> float:

	if storage == null:
		return 0.0


	return storage.get_capacity(
		resource_type
	)


# ============================================================
# 当前生产资源库存
# ============================================================

func get_free_storage() -> float:

	if storage == null:
		return 0.0


	return storage.get_free_space(
		production_resource_type
	)


func is_storage_full() -> bool:

	if storage == null:
		return true


	return storage.is_full(
		production_resource_type
	)


# ============================================================
# UI 通用接口
# ============================================================

func get_storage_amount() -> float:

	return get_resource_amount(
		production_resource_type
	)


func get_storage_capacity() -> float:

	return get_resource_capacity(
		production_resource_type
	)
# ============================================================
# 子类负责分配具体职业
# ============================================================

func assign_worker_job(_worker: Node) -> void:

	push_error(
		"ResourceBuildingBase：%s 没有实现 assign_worker_job()" % name
	)
