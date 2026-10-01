@tool
class_name CampPoolEntry
extends Resource

@export var camp: TreasureCampData
@export_range(0.0, 1000.0, 0.1) var weight: float = 1.0
@export_range(0.0, 86400.0, 1.0) var start_time: float = 0.0
## -1 表示不限制结束时间；时间区间为开始包含、结束不包含。
@export_range(-1.0, 86400.0, 1.0) var end_time: float = -1.0


func is_available(elapsed: float) -> bool:
	return camp != null and weight > 0.0 and elapsed >= start_time and (end_time < 0.0 or elapsed < end_time)
