class_name Farm
extends ResourceBuildingBase

@export_category("农业测试参数")
@export_range(0.5, 10.0, 0.5) var plow_time: float = 2.0
@export_range(0.5, 10.0, 0.5) var sow_time: float = 2.0
@export_range(1.0, 120.0, 1.0) var grow_time: float = 20.0
@export_range(0.5, 10.0, 0.5) var harvest_time: float = 2.0
@export_range(1.0, 50.0, 1.0) var grain_yield: float = 5.0


func _ready() -> void:
	super._ready()
	print("========== Farm 启动 ==========")


func _process(_delta: float) -> void:
	dispatch_available_farmers()


func assign_worker_job(worker: Node) -> void:
	worker.assign_job(
		worker.Job.FARMER,
		self
	)
	if worker.has_method("return_to_idle"):
		worker.return_to_idle()


func resume_worker(worker: Node) -> bool:
	if worker == null or not workers.has(worker):
		return false
	if worker.has_method("start_farm_work"):
		worker.start_farm_work()
	return true


func dispatch_available_farmers() -> void:
	for worker: Node in workers:
		if not is_instance_valid(worker) or not worker.has_method("start_farm_work"):
			continue
		if int(worker.get("state")) != worker.State.IDLE:
			continue
		if has_available_field():
			worker.start_farm_work()
		elif should_transport_grain() and worker.has_method("start_farm_transport"):
			worker.start_farm_transport()


func has_available_field() -> bool:
	for child: Node in get_children():
		var field := child as FarmField
		if field != null and field.can_claim():
			return true
	return false


func should_transport_grain() -> bool:
	return has_resource(&"grain") and not has_available_field()


func claim_next_field(worker: Node) -> FarmField:
	var fields: Array[FarmField] = []
	for child: Node in get_children():
		var field := child as FarmField
		if field != null and field.can_claim():
			fields.append(field)

	var priority := {
		FarmField.State.MATURE: 0,
		FarmField.State.READY_TO_SOW: 1,
		FarmField.State.EMPTY: 2
	}
	fields.sort_custom(func(a: FarmField, b: FarmField) -> bool:
		return int(priority[a.state]) < int(priority[b.state])
	)

	for field: FarmField in fields:
		if field.claim(worker):
			return field
	return null


func release_field(worker: Node, field: FarmField) -> void:
	if field != null:
		field.release(worker)


func get_field_work_time(field_state: FarmField.State) -> float:
	match field_state:
		FarmField.State.PLOWING:
			return plow_time
		FarmField.State.SOWING:
			return sow_time
		FarmField.State.HARVESTING:
			return harvest_time
	return 0.0


func get_field_status_text() -> String:
	var lines: PackedStringArray = []
	for child: Node in get_children():
		var field := child as FarmField
		if field != null:
			lines.append(field.get_state_text())
	return "\n".join(lines)
