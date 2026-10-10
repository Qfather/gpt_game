extends ResourceBuildingBase

@export_category("捕鱼")
@export_range(1, 1000, 1) var boat_capacity: int = 10
@export_range(1, 100, 1) var catch_min: int = 1
@export_range(1, 100, 1) var catch_max: int = 3
@export_range(1, 120, 0.1) var fishing_time: float = 10.0
@export_range(1, 120, 0.1) var processing_time: float = 5.0
@export_range(0.1, 20, 0.1) var boat_speed: float = 2.0


var boat: Node3D
var launching: bool = false
var boat_retry: float = 0.0


func _ready() -> void:
	super._ready()
	call_deferred("_launch_boat")


func _launch_boat() -> void:
	if is_queued_for_deletion(): return
	boat = load("res://Scene/unit/fishing_boat.tscn").instantiate()
	get_tree().current_scene.add_child(boat)
	var dock := get_dock_position()
	boat.global_position = Vector3(global_position.x, dock.y, global_position.z)
	boat.get_node("Visual").rotation.y = rotation.y + PI
	launching = true
	var tween := create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.tween_property(boat, "global_position", dock, 1.2)
	await tween.finished
	launching = false


func _process(delta: float) -> void:
	super._process(delta)
	if launching or not is_instance_valid(boat) or boat.occupied: return
	var dock := get_dock_position()
	if boat.global_position.distance_to(dock) < 0.01: return
	var grid: BuildGrid = get_tree().get_first_node_in_group("build_grid")
	if grid == null: return
	if boat.route.is_empty():
		boat_retry -= delta
		if boat_retry > 0.0: return
		boat_retry = 1.0
		if not boat.navigate(grid, global_position, maxf(work_radius, boat.global_position.distance_to(global_position) + 2.0), dock): return
	boat.sail(grid, boat_speed, delta)


func _exit_tree() -> void:
	# 正在出海的船由渔民实际返岸后释放，空船随小屋移除。
	if is_instance_valid(boat) and not boat.occupied: boat.queue_free()


func get_worker_job() -> int:
	return 5


func assign_worker_job(worker: Node) -> void:
	worker.assign_job(worker.Job.FISHER, self)


func resume_worker(worker: Node) -> bool:
	if not workers.has(worker): return false
	worker.state = worker.State.FISHING
	return true


func has_gatherable_resources() -> bool:
	var grid: BuildGrid = get_tree().get_first_node_in_group("build_grid")
	return grid != null and grid.is_water_cell(grid.world_to_grid(get_dock_position()))


func get_dock_position() -> Vector3:
	var grid: BuildGrid = get_tree().get_first_node_in_group("build_grid")
	var point := to_global(Vector3(0, 0, -1.6))
	if grid != null: point.y = grid.water_height
	return point


func get_interior_position() -> Vector3:
	return to_global(Vector3(0, 0, 0))
