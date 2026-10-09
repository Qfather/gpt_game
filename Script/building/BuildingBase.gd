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
var door_queue: Array[Node] = []
var indoor_residents: Array[Node] = []
var upgrade_site: ConstructionSite


func get_upgrade_data() -> BuildingData:
	if building_data == null or self is ConstructionSite: return null
	var paths: Dictionary = {&"wood_wall": "WallData", &"wood_gate": "GateData", &"wood_wall_tower": "WallTowerData"}
	if not paths.has(building_data.id): return null
	return load("res://data/buildings/" + paths[building_data.id] + ".tres") as BuildingData


func get_upgrade_cost() -> Dictionary[StringName, float]:
	var cost: Dictionary[StringName, float] = {}
	var next: BuildingData = get_upgrade_data()
	if next == null: return cost
	for resource_id: StringName in next.construction_cost:
		var amount: float = maxf(next.construction_cost[resource_id] - building_data.construction_cost.get(resource_id, 0.0), 0.0)
		if amount > 0: cost[resource_id] = amount
	return cost


func can_upgrade() -> bool:
	return get_upgrade_data() != null and not is_instance_valid(upgrade_site) and not is_destroyed() and not is_queued_for_deletion() and not is_demolition_in_progress() and (not self is Wall or not is_instance_valid((self as Wall).tower_site))


func request_upgrade() -> bool:
	if not can_upgrade(): return false
	var site := ConstructionSite.new()
	site.upgrade_from = self
	site.setup(get_upgrade_data(), build_grid_position, build_grid_rotation_step, scale.x < 0)
	site.required_resources = get_upgrade_cost()
	site.exterior_construction_started = true
	site._refresh_state()
	upgrade_site = site
	get_parent().add_child(site)
	site.global_transform = global_transform
	if not tree_exiting.is_connected(_cancel_upgrade): tree_exiting.connect(_cancel_upgrade)
	site.tree_exiting.connect(_clear_upgrade_site)
	var main: Node = get_tree().current_scene
	if main != null and main.has_method("register_building"): main.register_building(site)
	return true


func _cancel_upgrade() -> void:
	if is_instance_valid(upgrade_site) and upgrade_site.can_cancel_construction(): upgrade_site.cancel_construction()


func _clear_upgrade_site() -> void:
	upgrade_site = null


func add_indoor_resident(resident: Node) -> void:
	if not indoor_residents.has(resident): indoor_residents.append(resident)
	if not has_node("OccupancyIndicator"):
		var indicator: Node3D = preload("res://Script/ui/building_occupancy_indicator.gd").new()
		indicator.name = "OccupancyIndicator"
		add_child(indicator)


func remove_indoor_resident(resident: Node) -> void:
	indoor_residents.erase(resident)


func get_indoor_residents() -> Array[Node]:
	for index: int in range(indoor_residents.size() - 1, -1, -1):
		var resident: Variant = indoor_residents[index]
		if not is_instance_valid(resident) or resident.is_queued_for_deletion() or resident.is_dead() or resident.indoor_building != self:
			indoor_residents.remove_at(index)
	return indoor_residents


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
	return get_entrance_position()


static func get_local_entrance(root: Node3D) -> Vector3:
	var marker: Node3D = root.find_child("Entrance", true, false) as Node3D
	if marker == null:
		marker = root.find_child("ImmigrationEntrance", true, false) as Node3D
	if marker == null:
		marker = root.find_child("Door_*", true, false) as Node3D
	if marker == null:
		# 开放式资源建筑的入口在模型正面，可添加 Entrance 标记覆盖。
		return Vector3(0, 0, 1.9)
	var point := Vector3.ZERO
	var current: Node3D = marker
	while current != root:
		point = current.transform * point
		current = current.get_parent() as Node3D
	point.y = 0.0
	if String(marker.name).begins_with("Door_"): point.z += 0.9
	return point


func get_entrance_position() -> Vector3:
	var root: Node3D = model_instance if is_instance_valid(model_instance) else self
	return to_global(get_local_entrance(self)) if root == self else root.to_global(get_local_entrance(root))


func get_interior_position() -> Vector3:
	var marker: Node3D = find_child("Interior", true, false) as Node3D
	if marker == null: marker = find_child("ImmigrationInterior", true, false) as Node3D
	if marker != null: return marker.global_position
	var local: Vector3 = to_local(get_entrance_position())
	return to_global(Vector3(local.x, 0, local.z - 1.8))


func is_at_entrance_front(world_position: Vector3, tolerance: float = 0.0) -> bool:
	var entrance: Vector3 = get_entrance_position()
	if absf(world_position.y - entrance.y) > 0.8:
		return false
	var point: Vector3 = to_local(world_position)
	var bounds: AABB = _get_entrance_front_bounds().grow(tolerance)
	return point.x >= bounds.position.x and point.x <= bounds.end.x and point.z >= bounds.position.z and point.z <= bounds.end.z


func get_entrance_approach_positions() -> Array[Vector3]:
	var positions: Array[Vector3] = [get_entrance_position()]
	var bounds: AABB = _get_entrance_front_bounds()
	var door: Vector3 = to_local(positions[0])
	for x: float in [bounds.position.x + 0.2, bounds.get_center().x, bounds.end.x - 0.2]:
		for z: float in [bounds.position.z + 0.2, bounds.get_center().z, bounds.end.z - 0.2]:
			positions.append(to_global(Vector3(x, door.y, z)))
	return positions


func _get_entrance_front_bounds() -> AABB:
	# 点击形状表示建筑主体；农场仅使用工具屋的实体形状。
	var collision: CollisionShape3D = get_node_or_null("StaticBody3D/CollisionShape3D") if self is Farm else get_node_or_null("ClickArea/CollisionShape3D")
	var bounds := AABB(Vector3(-0.5, 0, -0.5), Vector3(1, 1, 1))
	if collision != null and collision.shape != null:
		var shape_bounds: AABB = AABB(-collision.shape.size * 0.5, collision.shape.size) if collision.shape is BoxShape3D else collision.shape.get_debug_mesh().get_aabb()
		# 实体碰撞在运行时缩窄过，入口仍覆盖原始建筑正面宽度。
		var transform := Transform3D(collision.transform.basis.orthonormalized(), collision.position)
		bounds = transform * shape_bounds
	var door: Vector3 = to_local(get_entrance_position())
	var center: Vector3 = bounds.get_center()
	var along_x: bool = absf(door.x - center.x) / maxf(bounds.size.x, 0.1) > absf(door.z - center.z) / maxf(bounds.size.z, 0.1)
	var axis: int = 0 if along_x else 2
	var across: int = 2 if along_x else 0
	var facing: float = 1.0 if door[axis] >= center[axis] else -1.0
	var face: float = bounds.end[axis] if facing > 0 else -bounds.position[axis]
	var near_face: float = face - 0.1
	var far_face: float = maxf(face + 1.5, door[axis] * facing + 0.3)
	var start: Vector3 = bounds.position
	var end: Vector3 = bounds.end
	start[across] -= 0.2
	end[across] += 0.2
	start[axis] = near_face if facing > 0 else -far_face
	end[axis] = far_face if facing > 0 else -near_face
	return AABB(start, end - start)


func join_door_queue(worker: Node) -> void:
	if not door_queue.has(worker): door_queue.append(worker)


func has_door_turn(worker: Node) -> bool:
	for index: int in range(door_queue.size() - 1, -1, -1):
		var queued: Variant = door_queue[index]
		if not is_instance_valid(queued) or queued.is_queued_for_deletion() or queued.is_dead():
			door_queue.remove_at(index)
	return not door_queue.is_empty() and door_queue[0] == worker


func release_door(worker: Node) -> void:
	door_queue.erase(worker)


static func create_entrance_arrow(entrance: Vector3) -> MeshInstance3D:
	var arrow := MeshInstance3D.new()
	arrow.name = "EntranceArrow"
	var mesh := ArrayMesh.new()
	var vertices := PackedVector3Array([
		Vector3(-0.16, 0, 0), Vector3(0.16, 0, 0), Vector3(0.16, 0, 0.6),
		Vector3(-0.16, 0, 0), Vector3(0.16, 0, 0.6), Vector3(-0.16, 0, 0.6),
		Vector3(-0.5, 0, 0.6), Vector3(0.5, 0, 0.6), Vector3(0, 0, 1.2)])
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	arrow.mesh = mesh
	arrow.position = entrance + Vector3(0, 0.35, 0)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.no_depth_test = true
	material.albedo_color = Color(1, 0.8, 0.1)
	arrow.material_override = material
	arrow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return arrow


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
	_notify_defense_changed()

func _notify_defense_changed() -> void:
	if not is_inside_tree() or building_data == null: return
	if not building_data.is_wall() and not building_data.is_gate() and not building_data.is_wall_tower(): return
	var alarm: Node = get_tree().get_first_node_in_group("settlement_alarm")
	if alarm != null: alarm.mark_defenses_dirty()


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
		_notify_defense_changed()
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
	if not grid.is_area_free(new_grid_position, building_data.grid_size, new_rotation_step, building_data.is_wall(), true, old_cells):
		return false
	if not can_pay_relocation_cost(new_transform.origin):
		return false
	var cost := get_relocation_cost(new_transform.origin)
	var base: Node = get_tree().get_first_node_in_group("bases")
	for resource_id: StringName in cost:
		base.take_resource(resource_id, cost[resource_id])
	if build_grid_area_registered:
		grid.release_area(build_grid_position, build_grid_size, build_grid_rotation_step)
	grid.occupy_area(new_grid_position, building_data.grid_size, new_rotation_step, building_data.is_wall(), true)
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
			set_meta("selection_double_click", mouse_event.double_click)
			building_clicked.emit(self)
			get_viewport().set_input_as_handled()
