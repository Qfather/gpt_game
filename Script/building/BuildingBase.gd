class_name BuildingBase
extends Node3D

const HEALTH_BAR_SCRIPT: Script = preload("res://Script/combat/health_bar_3d.gd")

signal building_clicked(building: BuildingBase)
signal building_demolished(building: BuildingBase)

@export var demolition_refund_ratio: float = 0.3

enum DemolitionState {
	NONE,
	WAITING_FOR_WORKER,
	WORKING,
	WAITING_FOR_DELIVERY
}

var building_data: BuildingData = null
var demolition_state: DemolitionState = DemolitionState.NONE
var demolition_workers: Array[Node] = []
var demolition_carrier: Node = null
var demolition_worker_target_count: int = 0
var demolition_progress: float = 0.0
var demolition_duration: float = 0.0
var demolition_resources: Dictionary[StringName, float] = {}
var build_grid_position: Vector2i = Vector2i.ZERO
var build_grid_size: Vector2i = Vector2i.ZERO
var build_grid_rotation_step: int = 0
var build_grid_area_registered: bool = false


# ============================================================
# 点击区域
# ============================================================

@onready var click_area: CollisionObject3D = get_node_or_null("ClickArea")

var interaction_positions: Dictionary = {}


# ============================================================
# 初始化
# ============================================================

func _ready() -> void:
	add_to_group("buildings")
	_create_health_bar()

	if click_area == null:
		push_warning(
			"BuildingBase：%s 没有找到 ClickArea" % name
		)
		return

	click_area.process_mode = Node.PROCESS_MODE_ALWAYS
	click_area.input_event.connect(
		_on_click_area_input_event
	)


func _create_health_bar() -> void:
	if has_node("HealthBar2D") or has_node("HealthBar3D"):
		return
	if (
		not has_signal("health_changed")
		or not has_method("get_health")
		or not has_method("get_max_health")
	):
		return

	var health_bar: Node3D = Node3D.new()
	health_bar.name = "HealthBar3D"
	health_bar.position.y = 2.3
	health_bar.set_script(HEALTH_BAR_SCRIPT)
	health_bar.set("bar_color", Color(0.9, 0.2, 0.15, 1.0))
	health_bar.set("bar_width", 1.8)
	health_bar.set("bar_height", 0.14)
	add_child(health_bar)


func _process(delta: float) -> void:
	if demolition_state == DemolitionState.WAITING_FOR_WORKER:
		_try_assign_demolition_worker()
		return
	if (
		demolition_state == DemolitionState.WAITING_FOR_DELIVERY
		and not is_instance_valid(demolition_carrier)
	):
		_try_assign_demolition_worker()
		return

	if demolition_state != DemolitionState.WORKING:
		return
	if demolition_workers.size() < demolition_worker_target_count:
		_try_assign_demolition_worker()

	for worker: Node in demolition_workers.duplicate():
		if not is_instance_valid(worker):
			demolition_workers.erase(worker)
	if demolition_workers.is_empty():
		demolition_state = DemolitionState.WAITING_FOR_WORKER
		return

	demolition_progress = minf(
		demolition_progress + delta * float(demolition_workers.size()),
		demolition_duration
	)
	if demolition_progress >= demolition_duration:
		_finish_dismantling()


func get_interaction_position(worker: Node) -> Vector3:
	var worker_id: int = worker.get_instance_id() if worker != null else 0
	if not interaction_positions.has(worker_id):
		var slot_index: int = interaction_positions.size()
		var angle: float = float(slot_index) * 2.399963
		var radius: float = 2.0 + float(slot_index % 3) * 0.35
		interaction_positions[worker_id] = Vector3(
			cos(angle) * radius,
			0.0,
			sin(angle) * radius
		)

	return global_position + interaction_positions[worker_id]


func set_building_data(data: BuildingData) -> void:
	building_data = data


func set_build_grid_occupancy(
	grid_position: Vector2i,
	grid_size: Vector2i,
	rotation_step: int
) -> void:
	build_grid_position = grid_position
	build_grid_size = grid_size
	build_grid_rotation_step = rotation_step
	build_grid_area_registered = true


func release_build_grid_area() -> bool:
	if not build_grid_area_registered:
		return false

	var current_scene: Node = get_tree().current_scene
	var build_grid: Node = null
	if current_scene != null:
		build_grid = current_scene.get_node_or_null("Systems/BuildGrid")
	if build_grid == null or not build_grid.has_method("release_area"):
		return false

	var released: bool = build_grid.release_area(
		build_grid_position,
		build_grid_size,
		build_grid_rotation_step
	)
	if released:
		build_grid_area_registered = false
	return released


func get_building_data() -> BuildingData:
	return building_data


func can_be_demolished() -> bool:
	return (
		building_data != null
		and not is_in_group("bases")
		and not is_in_group("construction_sites")
		and demolition_state == DemolitionState.NONE
	)


func demolish() -> bool:
	if not can_be_demolished():
		return false

	var existing_workers: Array[Node] = []
	if has_method("release_all_workers"):
		var workers_variant: Variant = get("workers")
		if workers_variant is Array:
			for worker: Node in workers_variant:
				if (
					is_instance_valid(worker)
					and float(worker.get("carried_amount")) <= 0.0
				):
					existing_workers.append(worker)

	var task_managers: Array[Node] = get_tree().get_nodes_in_group(
		"task_manager"
	)
	if not task_managers.is_empty() and task_managers[0].has_method(
		"cancel_tasks_for_target"
	):
		task_managers[0].cancel_tasks_for_target(self, true)

	if has_method("release_all_workers"):
		call("release_all_workers")

	demolition_state = DemolitionState.WAITING_FOR_WORKER
	demolition_workers.clear()
	demolition_carrier = null
	demolition_worker_target_count = get_max_demolition_workers()
	demolition_progress = 0.0
	demolition_duration = maxf(
		building_data.construction_time * 0.5,
		0.1
	)
	print(
		"建筑开始拆除：",
		name,
		"，需要时间：",
		demolition_duration
	)
	for worker: Node in existing_workers:
		if demolition_workers.size() >= get_max_demolition_workers():
			break
		if worker.has_method("assign_demolition") and worker.assign_demolition(
			self,
			true
		):
			if not demolition_workers.has(worker):
				demolition_workers.append(worker)
	return true


func is_demolition_in_progress() -> bool:
	return demolition_state != DemolitionState.NONE


func can_cancel_demolition() -> bool:
	return (
		demolition_state == DemolitionState.WAITING_FOR_WORKER
		or demolition_state == DemolitionState.WORKING
	)


func cancel_demolition() -> bool:
	if not can_cancel_demolition():
		print("当前拆除阶段不能取消：", demolition_state)
		return false

	var workers_to_release: Array[Node] = demolition_workers.duplicate()
	demolition_state = DemolitionState.NONE
	demolition_workers.clear()
	demolition_carrier = null
	for worker: Node in workers_to_release:
		if is_instance_valid(worker) and worker.has_method("finish_demolition"):
			worker.finish_demolition()

	demolition_worker_target_count = 0
	demolition_progress = 0.0
	demolition_duration = 0.0
	demolition_resources.clear()
	print("已取消拆除建筑：", name)
	return true


func get_demolition_status_text() -> String:
	match demolition_state:
		DemolitionState.WAITING_FOR_WORKER:
			return "等待拆除工人"
		DemolitionState.WORKING:
			return "拆除：%d / %d" % [
				int(demolition_progress),
				int(ceil(demolition_duration))
			]
		DemolitionState.WAITING_FOR_DELIVERY:
			return "等待材料运回据点"
		_:
			return "拆除建筑"


func get_max_demolition_workers() -> int:
	if building_data == null:
		return 1
	return maxi(building_data.max_construction_workers, 1)


func get_demolition_worker_count() -> int:
	return demolition_workers.size()


func get_demolition_worker_target_count() -> int:
	return demolition_worker_target_count


func get_demolition_progress_ratio() -> float:
	if demolition_duration <= 0.0:
		return 0.0
	return clampf(demolition_progress / demolition_duration, 0.0, 1.0)


func request_additional_demolition_worker() -> bool:
	if not is_demolition_in_progress():
		return false
	if demolition_worker_target_count >= get_max_demolition_workers():
		return false
	demolition_worker_target_count += 1
	_try_assign_demolition_worker()
	return true


func cancel_one_demolition_worker() -> bool:
	if not is_demolition_in_progress():
		return false
	if demolition_worker_target_count <= 0:
		return false
	demolition_worker_target_count -= 1
	for worker: Node in demolition_workers.duplicate():
		if not is_instance_valid(worker):
			demolition_workers.erase(worker)
			continue
		if worker == demolition_carrier and float(worker.get("carried_amount")) > 0.0:
			continue
		demolition_workers.erase(worker)
		if worker.has_method("finish_demolition"):
			worker.finish_demolition()
		return true
	return true


func get_demolition_refund_resources() -> Dictionary[StringName, float]:
	var refund: Dictionary[StringName, float] = {}
	if building_data == null:
		return refund
	for resource_key: StringName in building_data.construction_cost.keys():
		var amount: float = float(
			building_data.construction_cost[resource_key]
		) * clampf(demolition_refund_ratio, 0.0, 1.0)
		if amount > 0.0:
			refund[resource_key] = amount
	return refund


func get_demolition_remaining_resources() -> Dictionary[StringName, float]:
	return demolition_resources.duplicate()


func _try_assign_demolition_worker() -> void:
	if demolition_workers.size() >= demolition_worker_target_count:
		return
	for villager: Node in get_tree().get_nodes_in_group("villagers"):
		if not villager.has_method("is_idle"):
			continue
		if villager.has_method("has_combat_role") and villager.has_combat_role():
			continue
		if not villager.is_idle():
			continue
		if not villager.has_method("assign_demolition"):
			continue
		if villager.assign_demolition(self):
			if (
				demolition_state == DemolitionState.WAITING_FOR_DELIVERY
				and demolition_carrier == null
			):
				demolition_carrier = villager
			if not demolition_workers.has(villager):
				demolition_workers.append(villager)
			if demolition_workers.size() >= demolition_worker_target_count:
				return


func begin_demolition_work(worker: Node) -> bool:
	if (
		demolition_state != DemolitionState.WAITING_FOR_WORKER
		and demolition_state != DemolitionState.WORKING
	):
		return false
	if not demolition_workers.has(worker):
		demolition_workers.append(worker)
	if demolition_workers.size() > get_max_demolition_workers():
		demolition_workers.erase(worker)
		return false

	demolition_state = DemolitionState.WORKING
	if worker.has_method("set_demolition_working"):
		worker.set_demolition_working()
	return true


func arrive_at_demolition_site(worker: Node) -> bool:
	if demolition_state == DemolitionState.WAITING_FOR_WORKER:
		if not demolition_workers.has(worker):
			return false
		return begin_demolition_work(worker)
	if worker != demolition_carrier:
		return false
	if demolition_state != DemolitionState.WAITING_FOR_DELIVERY:
		return false

	_load_next_demolition_resource()
	return true


func _finish_dismantling() -> void:
	demolition_state = DemolitionState.WAITING_FOR_DELIVERY
	demolition_carrier = demolition_workers[0] if not demolition_workers.is_empty() else null
	for worker: Node in demolition_workers:
		if worker != demolition_carrier and worker.has_method("finish_demolition"):
			worker.finish_demolition()
	demolition_workers.clear()
	if is_instance_valid(demolition_carrier):
		demolition_workers.append(demolition_carrier)
	demolition_resources.clear()
	var refund_resources := get_demolition_refund_resources()
	for resource_key: StringName in refund_resources.keys():
		demolition_resources[resource_key] = refund_resources[resource_key]

	_load_next_demolition_resource()


func _load_next_demolition_resource() -> void:
	if not is_instance_valid(demolition_carrier):
		return
	for resource_id: StringName in demolition_resources.keys():
		var amount: float = float(demolition_resources[resource_id])
		if amount <= 0.0:
			continue
		var load_amount: float = minf(
			amount,
			float(demolition_carrier.get("carry_capacity"))
		)
		demolition_resources[resource_id] = amount - load_amount
		if demolition_carrier.has_method("begin_demolition_transport"):
			demolition_carrier.begin_demolition_transport(
				self,
				resource_id,
				load_amount
			)
		if _demolition_resources_loaded():
			_finish_demolition_pickup()
		return

	_complete_demolition()


func _demolition_resources_loaded() -> bool:
	for amount: float in demolition_resources.values():
		if amount > 0.0:
			return false
	return true


func _finish_demolition_pickup() -> void:
	if is_instance_valid(demolition_carrier) and demolition_carrier.has_method(
		"finish_demolition_pickup"
	):
		demolition_carrier.finish_demolition_pickup()
	print("拆除材料已全部取出，建筑删除：", name)
	building_demolished.emit(self)
	release_build_grid_area()
	queue_free()


func demolition_delivery_completed(worker: Node) -> void:
	if worker != demolition_carrier:
		return
	if demolition_worker_target_count <= 0:
		demolition_carrier = null
		demolition_workers.erase(worker)
		if worker.has_method("finish_demolition"):
			worker.finish_demolition()
		return
	if worker.has_method("return_to_demolition_site"):
		worker.return_to_demolition_site(self)


func _complete_demolition() -> void:
	if is_instance_valid(demolition_carrier) and demolition_carrier.has_method(
		"finish_demolition"
	):
		demolition_carrier.finish_demolition()
	print("建筑拆除完成，材料已运回据点：", name)
	building_demolished.emit(self)
	release_build_grid_area()
	queue_free()


# ============================================================
# 点击建筑
# ============================================================

func _on_click_area_input_event(
	_camera: Node,
	event: InputEvent,
	_event_position: Vector3,
	_normal: Vector3,
	_shape_idx: int
) -> void:

	if event is InputEventMouseButton:

		var mouse_event := event as InputEventMouseButton

		if (
			mouse_event.button_index == MOUSE_BUTTON_LEFT
			and mouse_event.pressed
		):
			building_clicked.emit(self)
			get_viewport().set_input_as_handled()
