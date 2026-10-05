class_name BuildingBase
extends Node3D

const HEALTH_BAR_SCRIPT: Script = preload("res://Script/combat/health_bar_3d.gd")

signal building_clicked(building: BuildingBase)
signal building_demolished(building: BuildingBase)
signal health_changed(current_health: float, max_health: float)

@export_range(1, 1000000, 1) var max_health: float = 300.0
var armor: float = 1.0
var current_health: float = 300.0
var health_destroyed: bool = false
var model_instance: Node3D

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
var shelter_residents: Array[Node] = []


# ============================================================
# 初始化
# ============================================================

func _ready() -> void:
	add_to_group("buildings")
	health_changed.connect(_queue_repair)
	current_health = max_health
	if building_data != null:
		_apply_building_data()
	_create_health_bar()
	_setup_solid_collision()

	if click_area == null:
		push_warning(
			"BuildingBase：%s 没有找到 ClickArea" % name
		)
		return

	click_area.process_mode = Node.PROCESS_MODE_ALWAYS
	click_area.input_event.connect(
		_on_click_area_input_event
	)


func _setup_solid_collision() -> void:
	# 蓝图可施工、城门保留通道；农场只阻挡工具屋，不阻挡田地。
	if self is ConstructionSite or self is Gate:
		return
	var body: StaticBody3D = get_node_or_null("StaticBody3D") as StaticBody3D
	if body == null:
		var click_shape: CollisionShape3D = get_node_or_null("ClickArea/CollisionShape3D") as CollisionShape3D
		if click_shape == null or click_shape.shape == null:
			return
		body = StaticBody3D.new()
		body.name = "StaticBody3D"
		body.input_ray_pickable = false
		add_child(body)
		var collision := CollisionShape3D.new()
		collision.name = "CollisionShape3D"
		collision.shape = click_shape.shape
		body.add_child(collision)
		collision.transform = click_shape.transform
	# 点击范围保持不变，实体只阻挡主体，给屋檐和外缘留出通行余量。
	if not self is Wall:
		for child: Node in body.get_children():
			if child is CollisionShape3D:
				child.scale.x *= 0.5
				child.scale.z *= 0.5
	add_to_group("navigation_solid_buildings")
	tree_exiting.connect(_request_navigation_update)
	# 建造系统在 add_child 后才设置最终位置和旋转。
	call_deferred("_request_navigation_update")


func _request_navigation_update() -> void:
	if not is_inside_tree():
		return
	get_tree().call_group("map_generate_runtime", "request_navigation_update")


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
		var radius: float = 2.0
		var collision: CollisionShape3D = get_node_or_null("StaticBody3D/CollisionShape3D") as CollisionShape3D
		if collision != null and collision.shape != null:
			var bounds: AABB = collision.transform * collision.shape.get_debug_mesh().get_aabb()
			radius = maxf(radius, maxf(maxf(absf(bounds.position.x), absf(bounds.end.x)), maxf(absf(bounds.position.z), absf(bounds.end.z))) + 0.9)
		radius += float(slot_index % 3) * 0.35
		interaction_positions[worker_id] = Vector3(
			cos(angle) * radius,
			0.0,
			sin(angle) * radius
		)

	return global_position + interaction_positions[worker_id]


func get_shelter_capacity() -> int:
	if self is SwordsmanCamp: return (self as SwordsmanCamp).get_training_slots()
	if self is ResourceBuildingBase: return (self as ResourceBuildingBase).get_max_worker_count()
	if self is House: return (self as House).get_housing_capacity()
	return 0


func get_shelter_occupants() -> Array[Node]:
	var occupants: Array[Node] = []
	if self is SwordsmanCamp:
		occupants.assign((self as SwordsmanCamp).training_workers)
	if self is ResourceBuildingBase:
		(self as ResourceBuildingBase).get_worker_count()
		occupants.assign((self as ResourceBuildingBase).workers)
	for resident: Node in shelter_residents.duplicate():
		if not is_instance_valid(resident) or resident.is_queued_for_deletion() or resident.is_dead() or resident.shelter_target != self:
			shelter_residents.erase(resident)
		elif not occupants.has(resident):
			occupants.append(resident)
	return occupants


func can_shelter(resident: Node) -> bool:
	if get_shelter_capacity() <= 0 or is_destroyed() or is_queued_for_deletion() or is_demolition_in_progress(): return false
	var occupants: Array[Node] = get_shelter_occupants()
	return occupants.has(resident) or occupants.size() < get_shelter_capacity()


func reserve_shelter(resident: Node) -> bool:
	if not can_shelter(resident): return false
	if not shelter_residents.has(resident): shelter_residents.append(resident)
	return true


func release_shelter(resident: Node) -> void:
	shelter_residents.erase(resident)


func set_building_data(data: BuildingData) -> void:
	building_data = data
	if is_node_ready():
		_apply_building_data()


func _apply_building_data() -> void:
	max_health = building_data.max_health
	armor = building_data.armor
	current_health = max_health
	var durability: Node = get_node_or_null("BuildingDurability")
	if durability != null:
		durability.armor = armor
		durability.setup(max_health)
	var storage: ResourceStorage = get_node_or_null("ResourceStorage") as ResourceStorage
	if storage == null and not building_data.storage_capacities.is_empty() and not self is Barracks:
		storage = ResourceStorage.new()
		storage.name = "ResourceStorage"
		storage.wood_capacity = 0.0
		storage.stone_capacity = 0.0
		storage.food_capacity = 0.0
		add_child(storage)
	if storage != null:
		storage.configure_capacities(building_data.storage_capacities)
	if building_data.model_scene != null and model_instance == null:
		_hide_original_model(self)
		model_instance = building_data.model_scene.instantiate() as Node3D
		if model_instance != null:
			add_child(model_instance)
	health_changed.emit(current_health, max_health)


func _hide_original_model(node: Node) -> void:
	if node is GeometryInstance3D:
		node.hide()
	for child: Node in node.get_children():
		if child.name != &"HealthBar3D": _hide_original_model(child)


func get_max_health() -> float:
	return max_health


func get_health() -> float:
	return current_health


func is_destroyed() -> bool:
	return health_destroyed


func take_damage(amount: float, _source: Node = null) -> float:
	if health_destroyed or amount <= 0.0:
		return 0.0
	var actual: float = minf(maxf(amount - armor, 1.0), current_health)
	current_health -= actual
	health_changed.emit(current_health, max_health)
	if current_health <= 0.0:
		health_destroyed = true
		_before_destroyed()
		get_tree().call_group("task_manager", "cancel_tasks_for_target", self, true)
		release_build_grid_area()
		queue_free()
	return actual


func _before_destroyed() -> void:
	pass


func _queue_repair(_health: float = 0.0, _maximum: float = 0.0) -> void:
	if self is ConstructionSite or building_data == null or is_destroyed() or is_queued_for_deletion():
		return
	if get_health() <= 0.0 or get_health() >= get_max_health() or is_demolition_in_progress():
		return
	get_tree().call_group_flags(SceneTree.GROUP_CALL_DEFERRED, "task_manager", "create_repair_task", self)


func repair(amount: float) -> float:
	var durability: BuildingDurability = get_node_or_null("BuildingDurability") as BuildingDurability
	if durability != null:
		return durability.repair(amount)
	if is_destroyed() or amount <= 0.0:
		return 0.0
	var restored: float = minf(amount, max_health - current_health)
	current_health += restored
	if restored > 0.0:
		health_changed.emit(current_health, max_health)
	return restored


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


func can_be_moved() -> bool:
	return building_data != null and (self is ResourceBuildingBase or building_data.id in [&"swordsman_camp", &"archer_camp", &"barracks", &"house"]) and not self is ConstructionSite and not is_destroyed() and not is_queued_for_deletion() and demolition_state == DemolitionState.NONE


func get_relocation_cost(new_position: Vector3) -> Dictionary[StringName, float]:
	var cost: Dictionary[StringName, float] = {}
	var distance: float = Vector2(global_position.x, global_position.z).distance_to(Vector2(new_position.x, new_position.z))
	var ratio: float = lerpf(0.1, 0.5, clampf(distance / 30.0, 0.0, 1.0))
	for resource_id: StringName in building_data.construction_cost:
		if building_data.construction_cost[resource_id] > 0.0:
			cost[resource_id] = ceilf(snappedf(building_data.construction_cost[resource_id] * ratio, 0.000001))
	return cost


func can_pay_relocation_cost(new_position: Vector3) -> bool:
	var cost := get_relocation_cost(new_position)
	var base: Node = get_tree().get_first_node_in_group("bases")
	if not is_instance_valid(base):
		return cost.is_empty()
	for resource_id: StringName in cost:
		if base.get_resource(resource_id) < cost[resource_id]:
			return false
	return true


func relocate(grid: BuildGrid, new_grid_position: Vector2i, new_rotation_step: int, mirrored: bool, new_transform: Transform3D) -> bool:
	if not can_be_moved():
		return false
	var old_cells: Array[Vector2i] = []
	if build_grid_area_registered:
		old_cells = grid._get_area_cells(build_grid_position, build_grid_size, build_grid_rotation_step)
	if not grid.is_area_free(new_grid_position, building_data.grid_size, new_rotation_step, building_data.id == &"wall", true, old_cells):
		return false
	if not can_pay_relocation_cost(new_transform.origin):
		return false
	var cost := get_relocation_cost(new_transform.origin)
	var base: Node = get_tree().get_first_node_in_group("bases")
	for resource_id: StringName in cost:
		base.take_resource(resource_id, cost[resource_id])
	if build_grid_area_registered:
		grid.release_area(build_grid_position, build_grid_size, build_grid_rotation_step)
	grid.occupy_area(new_grid_position, building_data.grid_size, new_rotation_step, building_data.id == &"wall", true)
	set_build_grid_occupancy(new_grid_position, building_data.grid_size, new_rotation_step)
	var old_transform: Transform3D = global_transform
	global_transform = new_transform
	rotation.y = float(new_rotation_step) * PI * 0.5
	scale.x = -1.0 if mirrored else 1.0
	interaction_positions.clear()
	_request_navigation_update()
	get_tree().call_group("villagers", "on_building_relocated", self, old_transform)
	return true


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
