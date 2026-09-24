class_name LootBundle
extends Node3D

var resources: Dictionary[StringName, float] = {}
var pickup_task: GameTask
var picked_up: bool = false


func configure(next_resource_id: StringName, next_amount: float) -> void:
	configure_resources({next_resource_id: next_amount})


func configure_resources(next_resources: Dictionary) -> void:
	resources.clear()
	for key: Variant in next_resources:
		var resource_id: StringName = StringName(key)
		var amount: float = maxf(float(next_resources[key]), 0.0)
		if not resource_id.is_empty() and amount > 0.0:
			resources[resource_id] = amount


func _ready() -> void:
	add_to_group("loot_bundles")
	call_deferred("_create_pickup_task")
	call_deferred("_request_resource_refresh")


func _create_pickup_task() -> void:
	var managers: Array[Node] = get_tree().get_nodes_in_group("task_manager")
	if managers.is_empty() or resources.is_empty() or picked_up:
		return
	pickup_task = managers[0].create_task(
		GameTask.TaskType.PICKUP_LOOT,
		self,
		self,
		100
	)


func pick_up(worker: Node) -> bool:
	if picked_up or not is_instance_valid(worker) or not worker.has_method("receive_loot"):
		return false
	var resource_id: StringName = _get_next_resource_id()
	var carry_capacity: float = float(worker.get("carry_capacity"))
	var amount: float = minf(float(resources.get(resource_id, 0.0)), carry_capacity)
	if resource_id.is_empty() or amount <= 0.0:
		return false
	picked_up = true
	if not worker.receive_loot(resource_id, amount):
		picked_up = false
		return false
	resources[resource_id] = float(resources[resource_id]) - amount
	if resources[resource_id] <= 0.0:
		resources.erase(resource_id)
	pickup_task = null
	_request_resource_refresh()
	print("📦 居民回收战利品：", resource_id, " x", amount)
	if resources.is_empty():
		queue_free()
	else:
		picked_up = false
		call_deferred("_create_pickup_task")
	return true


func get_resource_id() -> StringName:
	return _get_next_resource_id()


func get_amount() -> float:
	var total: float = 0.0
	for amount: float in resources.values():
		total += amount
	return total if not picked_up else 0.0


func get_amount_for(resource_id: StringName) -> float:
	return float(resources.get(resource_id, 0.0)) if not picked_up else 0.0


func get_resource_ids() -> Array[StringName]:
	var resource_ids: Array[StringName] = []
	if not picked_up:
		for resource_id: StringName in resources:
			resource_ids.append(resource_id)
	return resource_ids


func _get_next_resource_id() -> StringName:
	for resource_id: StringName in resources:
		if float(resources[resource_id]) > 0.0:
			return resource_id
	return &""


func _request_resource_refresh() -> void:
	var managers: Array[Node] = get_tree().get_nodes_in_group("resource_manager")
	if not managers.is_empty() and managers[0].has_method("request_refresh"):
		managers[0].request_refresh()
