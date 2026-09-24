@tool
class_name RiftEventEntry
extends Resource

@export var start_time: float = 120.0
@export_range(0.0, 600.0, 1.0) var random_offset: float = 0.0
@export_range(0.0, 120.0, 0.5) var countdown: float = 10.0
@export_range(1, 10, 1) var total_waves: int = 3
@export_range(0.0, 600.0, 0.5) var wave_interval: float = 5.0

var triggered: bool = false
var next_trigger_time: float = -1.0


func prepare(current_time: float) -> void:
	var offset: float = randf_range(-random_offset, random_offset)
	next_trigger_time = maxf(current_time + start_time + offset, current_time)
	triggered = false


func should_trigger(current_time: float) -> bool:
	return not triggered and next_trigger_time >= 0.0 and current_time >= next_trigger_time


func mark_triggered() -> void:
	triggered = true
	next_trigger_time = -1.0
