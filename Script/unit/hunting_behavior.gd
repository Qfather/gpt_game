extends RefCounted

var target: Node3D
var prey_count: int = 0
var raw_meat: float = 0.0
var returning: bool = false
var return_destination: Vector3 = Vector3.INF
var processing_time: float = -1.0
var inside_processing: bool = false
var roam_time: float = 0.0
var bundle: MeshInstance3D

func release_target(hunter: Node) -> void:
	if is_instance_valid(target): target.release(hunter)
	target = null

func request_return(hunter: Node) -> void:
	release_target(hunter)
	returning = true
	return_destination = Vector3.INF
	hunter.state = hunter.State.HUNTING

func process(hunter: Node3D, delta: float) -> void:
	var house: Node3D = hunter.workplace
	if not is_instance_valid(house) or house.is_queued_for_deletion():
		inside_processing = false
		hunter.visible = true
		hunter.collision_layer = 2
		hunter.collision_mask = 3
		release_target(hunter)
		# 小屋被毁时原猎物无法处理，释放职业并移除背包。
		clear_bundle()
		prey_count = 0
		raw_meat = 0.0
		hunter.finish_quit_job()
		return
	hunter.combat_attack_cooldown = maxf(hunter.combat_attack_cooldown - delta, 0.0)
	if returning:
		if return_destination == Vector3.INF:
			return_destination = NavigationServer3D.map_get_closest_point(
				hunter.navigation_agent.get_navigation_map(), house.get_interaction_position(hunter)
			)
		var destination: Vector3 = return_destination
		if not inside_processing and Vector2(hunter.global_position.x, hunter.global_position.z).distance_to(Vector2(destination.x, destination.z)) > 1.8:
			move(hunter, destination)
			return
		hunter.velocity = Vector3.ZERO
		if prey_count > 0:
			if not inside_processing:
				if processing_time < 0.0: processing_time = randf_range(house.processing_min, house.processing_max)
				_enter_house(hunter, house)
				return
			processing_time -= delta
			if processing_time > 0.0: return
			var amount: float = house.deposit_resource(&"meat", raw_meat)
			raw_meat -= amount
			# 满仓时自行搬运库存，为尚未存入的肉腾出空间。
			if raw_meat > 0.0:
				_leave_house(hunter, house, true)
				return
			prey_count = 0
			processing_time = -1.0
			clear_bundle()
			_leave_house(hunter, house, false)
			return
		if house.is_storage_full() and transport_meat(hunter, house): return
		returning = false
		if hunter.is_quitting_job:
			hunter.finish_quit_job()
			return
		return
	if is_instance_valid(target):
		if target.is_dead():
			if hunter.global_position.distance_to(target.global_position) > 1.8:
				move(hunter, target.global_position)
				return
			prey_count += 1
			raw_meat += target.data.meat_yield
			target.queue_free()
			target = null
			update_bundle(hunter)
			if prey_count >= 3: request_return(hunter)
			return
		if hunter.global_position.distance_to(target.global_position) > hunter.combat_attack_range:
			move(hunter, target.global_position)
			return
		hunter.velocity = Vector3.ZERO
		if hunter.combat_attack_cooldown <= 0.0:
			hunter.fire_arrow(target)
			hunter.combat_attack_cooldown = hunter.combat_attack_interval
		return
	for animal: Node3D in hunter.get_tree().get_nodes_in_group("wildlife"):
		if animal.is_queued_for_deletion() or not animal.is_visible_in_tree(): continue
		if hunter.global_position.distance_to(animal.global_position) <= hunter.combat_attack_range and animal.claim(hunter):
			target = animal
			return
	if prey_count > 0:
		request_return(hunter)
		return
	roam_time -= delta
	if roam_time <= 0.0:
		roam_time = 5.0
		var base: Node3D = hunter.target_base
		var center: Vector3 = base.global_position if is_instance_valid(base) else house.global_position
		var point: Vector3 = center + Vector3(randf_range(-house.work_radius, house.work_radius), 0, randf_range(-house.work_radius, house.work_radius))
		hunter.navigation_agent.target_position = NavigationServer3D.map_get_closest_point(hunter.get_world_3d().get_navigation_map(), point)
	hunter.move_along_navigation()

func move(hunter: Node, destination: Vector3) -> void:
	# 静止目标只设置一次；移动猎物走出半米后才更新路径。
	if hunter.navigation_agent.target_position.distance_squared_to(destination) > 0.25:
		hunter.navigation_agent.target_position = destination
	hunter.move_along_navigation()

func transport_meat(hunter: Node, house: Node) -> bool:
	if not is_instance_valid(hunter.target_base): hunter.find_base()
	if not is_instance_valid(hunter.target_base): return false
	var amount: float = house.take_resource(&"meat", hunter.carry_capacity)
	if amount <= 0.0: return false
	hunter.carried_resource_id = &"meat"
	hunter.carried_amount = amount
	hunter.carried_resource_changed.emit()
	hunter.is_transporting = true
	hunter.go_to_base()
	return true

func _enter_house(hunter: Node, house: BuildingBase) -> void:
	if not await hunter._pass_building_door(house, true):
		processing_time = -1.0
		hunter.return_to_idle()
	else:
		inside_processing = true


func _leave_house(hunter: Node, house: BuildingBase, needs_space: bool) -> void:
	inside_processing = false
	await hunter._pass_building_door(house, false)
	if hunter.is_dead() or not is_instance_valid(house): return
	if needs_space:
		transport_meat(hunter, house)
		return
	returning = false
	if house.is_storage_full() and transport_meat(hunter, house): return
	if hunter.is_quitting_job: hunter.finish_quit_job()


func update_bundle(hunter: Node) -> void:
	if not is_instance_valid(bundle):
		bundle = MeshInstance3D.new()
		bundle.mesh = BoxMesh.new()
		bundle.mesh.size = Vector3(0.5, 0.35, 0.4)
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(0.5, 0.22, 0.12)
		bundle.material_override = material
		bundle.position = Vector3(0, 0.8, -0.45)
		hunter.add_child(bundle)
	bundle.scale.y = float(prey_count)

func clear_bundle() -> void:
	if is_instance_valid(bundle): bundle.queue_free()
	bundle = null
