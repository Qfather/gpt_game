extends ResourceBuildingBase

@export_category("猎物处理")
@export_range(1, 60, 0.1) var processing_min: float = 5.0
@export_range(1, 60, 0.1) var processing_max: float = 15.0

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
