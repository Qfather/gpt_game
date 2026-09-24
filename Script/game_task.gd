class_name GameTask
extends RefCounted

enum TaskType {
	DELIVER_CONSTRUCTION_RESOURCE,
	BUILD,
	TRAIN_SWORDSMAN,
	PICKUP_LOOT
}

enum State {
	AVAILABLE,
	CLAIMED,
	IN_PROGRESS,
	COMPLETED,
	CANCELLED
}

var id: StringName
var type: int
var state: int = State.AVAILABLE
var priority: int = 0
var requester: Node
var target: Node
var assigned_worker: Node
var data: Dictionary = {}


func _init(
	task_id: StringName = &"",
	task_type: int = TaskType.BUILD
) -> void:

	id = task_id
	type = task_type
