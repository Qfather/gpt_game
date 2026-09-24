@tool
class_name LevelEventEntry
extends Resource

@export var monster_group: RaidGroupData
@export var monster_database: RaidGroupDatabase
@export var monster_group_id: StringName = &""
@export var event_name: String = ""
@export var start_time: float = 120.0
@export_range(0.0, 600.0, 1.0) var random_offset: float = 0.0
@export var repeat: bool = false
@export_range(1.0, 3600.0, 1.0) var repeat_interval: float = 180.0
@export_range(1, 100, 1) var random_total_count: int = 3
@export_range(1, 10, 1) var rift_wave_count: int = 3
@export_range(0.0, 600.0, 0.5) var rift_wave_interval: float = 5.0
@export_range(0.0, 120.0, 0.5) var rift_countdown: float = 10.0

var triggered: bool = false
var next_trigger_time: float = -1.0

func prepare(current_time: float) -> void:
	next_trigger_time = maxf(current_time + start_time + randf_range(-random_offset, random_offset), current_time)
	triggered = false

func should_trigger(current_time: float) -> bool:
	return get_monster_group() != null and not triggered and next_trigger_time >= 0.0 and current_time >= next_trigger_time

func mark_triggered(current_time: float) -> void:
	if repeat:
		next_trigger_time = current_time + repeat_interval + randf_range(-random_offset, random_offset)
	else:
		triggered = true

func get_monster_group() -> RaidGroupData:
	if monster_database != null and not monster_group_id.is_empty():
		return monster_database.get_group(monster_group_id)
	return monster_group
