@tool
class_name RaidEventEntry
extends Resource

@export var raid_group: RaidGroupData
@export var raid_database: RaidGroupDatabase
@export var raid_group_id: StringName = &""
@export var start_time: float = 120.0
@export_range(0.0, 600.0, 1.0) var random_offset: float = 30.0
@export var repeat: bool = false
@export_range(1.0, 3600.0, 1.0) var repeat_interval: float = 180.0

var triggered: bool = false
var next_trigger_time: float = -1.0

func prepare(current_time: float) -> void:
	next_trigger_time = current_time + start_time + randf_range(-random_offset, random_offset)
	triggered = false

func should_trigger(current_time: float) -> bool:
	return get_raid_group() != null and not triggered and next_trigger_time >= 0.0 and current_time >= next_trigger_time

func mark_triggered(current_time: float) -> void:
	if repeat:
		next_trigger_time = current_time + repeat_interval + randf_range(-random_offset, random_offset)
	else:
		triggered = true

func get_raid_group() -> RaidGroupData:
	if raid_database != null and not raid_group_id.is_empty():
		return raid_database.get_group(raid_group_id)
	return raid_group
