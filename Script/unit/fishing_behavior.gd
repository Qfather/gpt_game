extends RefCounted

enum Phase { APPROACH, BOARDING, SAILING, FISHING, RETURNING, LANDING, PROCESSING, LEAVING }
var phase: int = Phase.APPROACH
var boat: Node3D
var cargo: int = 0
var timer: float = 0.0
var waiting: float = 0.0
var transition: bool = false
var home: Node3D
var dock := Vector3.INF
var shore := Vector3.INF
var pending_retreat: bool = false
var approach_target := Vector3.INF
var approach_retry: float = 0.0
var departure_origin := Vector3.INF
var departure_transform := Transform3D.IDENTITY
var rng := RandomNumberGenerator.new()

func _init() -> void:
	rng.randomize()


func active() -> bool:
	return phase != Phase.APPROACH or transition


func request_return() -> void:
	if phase in [Phase.SAILING, Phase.FISHING]:
		phase = Phase.RETURNING
		if is_instance_valid(boat): boat.route.clear()
		waiting = 0.0


func reset(preserve_cargo: bool = false) -> void:
	_release_boat()
	boat = null
	home = null
	phase = Phase.APPROACH
	transition = false
	if not preserve_cargo: cargo = 0
	pending_retreat = false
	approach_target = Vector3.INF


func _release_boat() -> void:
	if not is_instance_valid(boat): return
	boat.clear_passenger()
	boat.route.clear()
	if not is_instance_valid(home) or home.is_queued_for_deletion(): boat.queue_free()
	boat = null


func process(worker: Node3D, delta: float) -> void:
	if transition: return
	var grid: BuildGrid = worker.get_tree().get_first_node_in_group("build_grid")
	if grid == null: return
	var valid_home: bool = is_instance_valid(worker.workplace) and not worker.workplace.is_queued_for_deletion() and not worker.workplace.is_destroyed()
	if not valid_home:
		# 船和原靠岸点不随小屋释放，实际返岸后再结束职业。
		if phase == Phase.APPROACH:
			worker.finish_quit_job()
			return
		worker.is_quitting_job = true
		request_return()
	if phase == Phase.APPROACH:
		home = worker.workplace
		shore = home.get_entrance_position()
		dock = home.get_dock_position()
		approach_retry -= delta
		if approach_target == Vector3.INF or approach_retry <= 0.0:
			approach_target = worker._get_reachable_workplace_position()
			approach_retry = 1.5
		var destination: Vector3 = approach_target
		var approach_distance := Vector2(worker.global_position.x - destination.x, worker.global_position.z - destination.z).length()
		if not home.is_at_entrance_front(worker.global_position, 0.2) or approach_distance > 0.35:
			if worker.navigation_agent.target_position.distance_to(destination) > 0.2: worker.navigation_agent.target_position = destination
			worker.move_along_navigation()
			return
		if worker.is_quitting_job:
			worker.finish_quit_job()
			return
		# 靠岸恢复点是实际可站立的正面导航位置，门标记仍用于公共进出屋动画。
		shore = destination
		if home.get_free_storage() < home.boat_capacity and home.get_storage_amount() > 0:
			_transport(worker, home)
			return
		waiting -= delta
		if waiting > 0.0: return
		waiting = 1.0
		if not _shore_clear(worker) or home.launching or not is_instance_valid(home.boat): return
		if home.boat.occupied or home.boat.global_position.distance_to(dock) > 0.01: return
		_enter_and_board(worker, home)
		return
	if is_instance_valid(boat) and phase in [Phase.SAILING, Phase.FISHING, Phase.RETURNING]:
		if worker._civilian_alarm_required(): pending_retreat = true
		if pending_retreat or worker.is_hungry() or worker.is_tired() or worker.is_quitting_job: request_return()
		worker.velocity = Vector3.ZERO
		var center: Vector3 = departure_origin
		var radius: float = home.work_radius if valid_home else 35.0
		var speed: float = home.boat_speed if valid_home else 2.0
		if phase == Phase.SAILING or phase == Phase.RETURNING:
			if boat.route.is_empty():
				waiting -= delta
				if waiting > 0.0: return
				waiting = 1.0
				if phase == Phase.RETURNING:
					if not boat.navigate(grid, center, radius, dock): return
				else:
					if boat.choose_fishing_point(grid, center, radius, rng) == Vector3.INF: return
			if boat.sail(grid, speed, delta):
				if phase == Phase.RETURNING:
					_land(worker, valid_home and home.global_transform.is_equal_approx(departure_transform))
				else:
					phase = Phase.FISHING
					timer = home.fishing_time
		elif phase == Phase.FISHING:
			timer -= delta
			if timer <= 0.0:
				cargo = mini(cargo + rng.randi_range(home.catch_min, maxi(home.catch_min, home.catch_max)), home.boat_capacity)
				phase = Phase.RETURNING if cargo >= home.boat_capacity else Phase.SAILING
				waiting = 0.0
		if is_instance_valid(boat): worker.global_position = boat.global_position + Vector3.UP * 0.3
		return
	if phase == Phase.PROCESSING:
		if worker._civilian_alarm_required(): pending_retreat = true
		var home_unchanged: bool = valid_home and home.global_transform.is_equal_approx(departure_transform)
		if pending_retreat or worker.is_hungry() or worker.is_tired() or not home_unchanged:
			waiting -= delta
			if waiting > 0.0: return
			waiting = 1.0
			_leave(worker, home_unchanged)
			return
		timer -= delta
		if timer > 0.0: return
		var deposited: float = home.deposit_resource(&"fish", cargo)
		cargo -= int(deposited)
		_leave(worker, valid_home)


func _enter_and_board(worker: Node3D, building: Node3D) -> void:
	transition = true
	phase = Phase.BOARDING
	departure_origin = building.global_position
	departure_transform = building.global_transform
	var entered: bool = await worker._pass_building_door(building, true)
	if not is_instance_valid(worker) or worker.is_dead(): return
	if not _same_job(worker, building):
		phase = Phase.PROCESSING
		transition = false
		return
	if not entered:
		phase = Phase.APPROACH
		transition = false
		return
	worker.indoor_building = building
	building.add_indoor_resident(worker)
	if cargo > 0:
		phase = Phase.PROCESSING
		timer = building.processing_time
		transition = false
		return
	if not is_instance_valid(building.boat) or building.boat.is_queued_for_deletion():
		phase = Phase.PROCESSING
		timer = 0.0
		transition = false
		return
	boat = building.boat
	boat.occupied = true
	boat.passenger = worker.visual_instance.duplicate()
	boat.passenger.position.y = 0.3
	boat.get_node("Visual").add_child(boat.passenger)
	# 已实际通过合法入口，室内角色直接切换为船上的等比例外观。
	building.remove_indoor_resident(worker)
	worker.indoor_building = null
	worker.visible = false
	phase = Phase.SAILING
	transition = false
	waiting = 0.0


func _same_job(worker: Node, building: Node) -> bool:
	return is_instance_valid(worker) and not worker.is_dead() and is_instance_valid(building) and not building.is_queued_for_deletion() and worker.workplace == building and worker.job == worker.Job.FISHER


func _land(worker: Node3D, valid_home: bool) -> void:
	if not _shore_clear(worker): return
	phase = Phase.LANDING
	transition = true
	if is_instance_valid(boat) and is_instance_valid(boat.passenger): boat.passenger.visible = false
	if valid_home:
		worker.visible = false
		worker.global_position = home.get_interior_position()
	else:
		worker.visible = true
		var tween: Tween = worker.create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
		tween.tween_property(worker, "global_position", shore, 0.8)
		await tween.finished
		if not is_instance_valid(worker) or worker.is_dead(): return
	_release_boat()
	transition = false
	if valid_home and _same_job(worker, home):
		worker.visible = false
		worker.indoor_building = home
		home.add_indoor_resident(worker)
		phase = Phase.PROCESSING
		timer = home.processing_time
	else:
		if worker.global_position.distance_to(shore) > 0.35:
			phase = Phase.PROCESSING
			return
		worker.visible = true
		worker.collision_layer = 2
		worker.collision_mask = 3
		# 未处理渔获保留在角色的捕鱼背包，重新任职后处理，不提前变成库存鱼。
		phase = Phase.APPROACH
		if is_instance_valid(home) and worker.workplace == home and not home.is_queued_for_deletion():
			approach_target = Vector3.INF
			worker.state = worker.State.FISHING
		else:
			worker.finish_quit_job()
		if worker.carried_amount > 0.0: worker.go_to_base()


func _leave(worker: Node3D, valid_home: bool) -> void:
	if valid_home: shore = worker._get_reachable_workplace_position()
	if not _shore_clear(worker): return
	phase = Phase.LEAVING
	transition = true
	if valid_home:
		await worker._pass_building_door(home, false, shore)
	else:
		worker.visible = true
		var tween: Tween = worker.create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
		tween.tween_property(worker, "global_position", shore, maxf(worker.global_position.distance_to(shore) / worker.get_move_speed(), 0.2))
		await tween.finished
	if not is_instance_valid(worker) or worker.is_dead(): return
	if is_instance_valid(home): home.remove_indoor_resident(worker)
	worker.indoor_building = null
	worker.visible = true
	worker.collision_layer = 2
	worker.collision_mask = 3
	phase = Phase.APPROACH
	transition = false
	approach_target = Vector3.INF
	if worker.is_quitting_job:
		worker.finish_quit_job()
		if worker.carried_amount > 0.0: worker.go_to_base()
	elif pending_retreat:
		pending_retreat = false
		worker._begin_civilian_retreat()
	elif worker.is_hungry() or worker.is_tired():
		worker.evaluate_needs()
	else:
		worker.state = worker.State.FISHING


func _shore_clear(worker: Node3D) -> bool:
	var map: RID = worker.navigation_agent.get_navigation_map()
	if not map.is_valid() or NavigationServer3D.map_get_closest_point(map, shore).distance_to(shore) > 0.35: return false
	var query := PhysicsShapeQueryParameters3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.1
	query.shape = shape
	query.collision_mask = 1
	query.exclude = [worker.get_rid()]
	if is_instance_valid(home):
		var body: StaticBody3D = home.get_node_or_null("StaticBody3D")
		if body != null: query.exclude = [worker.get_rid(), body.get_rid()]
	query.transform = Transform3D(Basis.IDENTITY, worker.global_position + Vector3.UP * 0.5)
	query.motion = shore - worker.global_position
	var result := worker.get_world_3d().direct_space_state.cast_motion(query)
	return result[0] >= 1.0 and worker.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()


func _transport(worker: Node3D, building: Node3D) -> void:
	worker.carried_resource_id = &"fish"
	worker.carried_amount = building.take_resource(&"fish", worker.carry_capacity)
	worker.carried_resource_changed.emit()
	if worker.carried_amount > 0.0:
		worker.is_transporting = true
		worker.go_to_base()
