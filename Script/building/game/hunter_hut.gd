extends ResourceBuildingBase

@export_category("猎物处理")
@export_range(1, 60, 0.1) var processing_min: float = 5.0
@export_range(1, 60, 0.1) var processing_max: float = 15.0

func has_gatherable_resources() -> bool:
	var base: Node3D = get_tree().get_first_node_in_group("bases") as Node3D
	var center: Vector3 = base.global_position if base != null else global_position
	for animal: Node3D in get_tree().get_nodes_in_group("wildlife"):
		if not animal.is_queued_for_deletion() and not animal.is_dead() and center.distance_to(animal.global_position) <= work_radius:
			return true
	return false


func get_worker_job() -> int:
	return 4

func assign_worker_job(worker: Node) -> void:
	worker.assign_job(worker.Job.HUNTER, self)

func resume_worker(worker: Node) -> bool:
	if not workers.has(worker): return false
	worker.state = worker.State.HUNTING
	return true

func _process(delta: float) -> void:
	super._process(delta)
	for worker: Node in workers.duplicate():
		if not is_instance_valid(worker) or worker.is_dead(): workers.erase(worker)
