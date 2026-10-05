class_name ResourceBuildingBase
extends BuildingBase
var destroyed: bool = false
var resource_warning: Label3D
var resource_warning_timer: float = 0.0


# ============================================================
# 资源建筑配置
# ============================================================

## 当前建筑生产的资源 ID
@export var production_resource_id: StringName = &"wood"

## 旧资源类型接口，供尚未迁移的建造系统兼容使用。
var production_resource_type: ResourceType.Type:
	get:
		return ResourceStorage.resource_type_from_id(production_resource_id)
	set(value):
		production_resource_id = ResourceStorage.resource_id_from_key(value)

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
	add_to_group("resource_buildings")
	_create_resource_warning()
	current_health = maxf(max_health, 1.0)
	health_changed.emit(current_health, max_health)

	if storage == null:
		push_warning(
			"ResourceBuildingBase：%s 没有找到 ResourceStorage" % name
		)


func _create_resource_warning() -> void:
	resource_warning = Label3D.new()
	resource_warning.name = "ResourceWarning"
	resource_warning.text = "!"
	resource_warning.modulate = Color(1.0, 0.85, 0.1)
	resource_warning.outline_modulate = Color(0.2, 0.15, 0.02)
	resource_warning.outline_size = 12
	resource_warning.font_size = 128
	resource_warning.pixel_size = 0.008
	resource_warning.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	resource_warning.no_depth_test = true
	var top: float = 2.0
	for mesh: MeshInstance3D in find_children("*", "MeshInstance3D", true, false):
		var bounds: AABB = (global_transform.affine_inverse() * mesh.global_transform) * mesh.get_aabb()
		top = maxf(top, bounds.end.y)
	resource_warning.position.y = top + 0.6
	resource_warning.visible = false
	resource_warning.set_meta("fog_visible", false)
	add_child(resource_warning)


func _process(delta: float) -> void:
	super._process(delta)
	resource_warning_timer -= delta
	if resource_warning_timer > 0.0:
		return
	resource_warning_timer = 1.0
	var active: bool = not is_destroyed() and not is_demolition_in_progress() and not has_gatherable_resources()
	resource_warning.set_meta("fog_visible", active)
	resource_warning.visible = active and not bool(get_meta("fog_hidden", false))


func has_gatherable_resources() -> bool:
	for resource: Node in get_tree().get_nodes_in_group("resources"):
		if resource is ResourceBase and not resource.is_queued_for_deletion():
			if resource.get_resource_id() == production_resource_id and resource.can_gather() and is_position_in_work_range(resource.global_position):
				return true
	return false


func on_resource_matured(resource: ResourceBase) -> void:
	if is_destroyed() or is_demolition_in_progress() or resource.get_resource_id() != production_resource_id or not is_position_in_work_range(resource.global_position):
		return
	resource_warning_timer = 0.0
	for worker: Node in workers:
		if is_instance_valid(worker) and worker.workplace == self and worker.state in [worker.State.IDLE, worker.State.RETURN_TO_IDLE] and worker.current_task == null and worker.carried_amount <= 0.0:
			resume_worker(worker)


func get_max_health() -> float:
	return max_health


func get_health() -> float:
	return current_health


func is_destroyed() -> bool:
	return destroyed


func take_damage(amount: float, _source: Node = null) -> float:
	if destroyed:
		return 0.0
	var actual_damage: float = minf(maxf(amount - armor, 1.0), current_health) if amount > 0.0 else 0.0
	if actual_damage <= 0.0:
		return 0.0
	current_health = maxf(current_health - actual_damage, 0.0)
	health_changed.emit(current_health, max_health)
	if current_health <= 0.0:
		destroyed = true
		release_all_workers()
		release_build_grid_area()
		queue_free()
	return actual_damage


# ============================================================
# 子类职业配置
# ============================================================

## 子类需要重写这个函数。
##
## LumberCamp → LUMBERJACK
## Quarry     → MINER
func get_worker_job() -> int:

	return -1


## 恢复资源建筑工人的工作状态。
## 所有继承 ResourceBuildingBase 的资源建筑共用这套流程。
func resume_worker(worker: Node) -> bool:
	if worker == null or not workers.has(worker):
		return false
	if not worker.has_method("get_job_resource_id"):
		return false

	worker.state = worker.State.FIND_RESOURCE
	return true


# ============================================================
# 当前工人数
# ============================================================

func get_worker_count() -> int:
	_prune_workers()
	return workers.size()


func _prune_workers() -> void:
	for index in range(workers.size() - 1, -1, -1):
		var worker: Variant = workers[index]
		if not is_instance_valid(worker) or worker.is_queued_for_deletion() or (worker.has_method("is_dead") and worker.is_dead()):
			workers.remove_at(index)
			if is_instance_valid(worker) and worker.get("workplace") == self and worker.has_method("release_target_field"):
				worker.release_target_field()


func get_max_worker_count() -> int:

	return max_workers


# ============================================================
# 是否还有空岗位
# ============================================================

func has_free_slot() -> bool:
	return get_shelter_occupants().size() < max_workers


# ============================================================
# 添加工人
# ============================================================

func add_worker(worker: Node) -> bool:

	if worker == null:
		return false
	if worker.has_method("has_combat_role") and worker.has_combat_role():
		print("❌ ", worker.name, " 是军事单位，不能加入资源建筑")
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

	var previous_state: int = int(worker.get("state"))
	var was_resting: bool = (
		previous_state == worker.State.NEED_REST
		or previous_state == worker.State.MOVE_TO_REST
		or previous_state == worker.State.RESTING
	)

	workers.append(worker)

	assign_worker_job(worker)
	if was_resting:
		worker.set("state", previous_state)


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


func release_all_workers() -> void:
	_prune_workers()
	var current_workers: Array[Node] = workers.duplicate()
	for worker: Node in current_workers:
		if is_instance_valid(worker):
			remove_worker(worker)


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
	resource_key: Variant,
	amount: float
) -> float:

	if storage == null:
		return 0.0


	return storage.add(
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


func has_resource(
	resource_key: Variant
) -> bool:

	if storage == null:
		return false


	return not storage.is_empty(
		resource_key
	)


func get_resource_amount(
	resource_key: Variant
) -> float:

	if storage == null:
		return 0.0


	return storage.get_amount(
		resource_key
	)


func get_resource_capacity(
	resource_key: Variant
) -> float:

	if storage == null:
		return 0.0


	return storage.get_capacity(
		resource_key
	)


# ============================================================
# 当前生产资源库存
# ============================================================

func get_free_storage() -> float:

	if storage == null:
		return 0.0


	return storage.get_free_space(
		production_resource_id
	)


func is_storage_full() -> bool:

	if storage == null:
		return true


	return storage.is_full(
		production_resource_id
	)


# ============================================================
# UI 通用接口
# ============================================================

func get_storage_amount() -> float:

	return get_resource_amount(
		production_resource_id
	)


func get_storage_capacity() -> float:

	return get_resource_capacity(
		production_resource_id
	)
# ============================================================
# 子类负责分配具体职业
# ============================================================

func assign_worker_job(_worker: Node) -> void:

	push_error(
		"ResourceBuildingBase：%s 没有实现 assign_worker_job()" % name
	)
