class_name Watchtower
extends ResourceBuildingBase

func _ready() -> void:
	max_workers = 1
	super._ready()
	add_to_group("watchtowers")
	get_node("HealthBar3D").position.y = 5.0

func has_gatherable_resources() -> bool:
	return true

func get_shelter_capacity() -> int:
	return 0

func get_interior_position() -> Vector3:
	return $WatchPlatform.global_position

func assign_worker_job(worker: Node) -> void:
	worker.assign_job(worker.Job.WATCHER, self)

func resume_worker(worker: Node) -> bool:
	if not workers.has(worker): return false
	worker.go_to_workplace()
	return true

func begin_watch(worker: Node) -> void:
	worker.state = worker.State.WATCHING
	if not await worker._pass_building_door(self, true):
		if not worker.is_dead() and worker.workplace == self and not worker.is_quitting_job: worker.go_to_workplace()
	elif worker.workplace != self or worker.is_quitting_job:
		await worker._leave_idle_building()
		if not worker.is_dead() and worker.job == worker.Job.NONE: worker.return_to_idle()

func is_staffed() -> bool:
	if is_destroyed() or is_queued_for_deletion() or is_demolition_in_progress(): return false
	_prune_workers()
	for worker: Node in workers:
		if worker.workplace == self and worker.state == worker.State.WATCHING and worker.indoor_building == self and not worker.passing_door and not worker.is_quitting_job:
			return true
	return false
