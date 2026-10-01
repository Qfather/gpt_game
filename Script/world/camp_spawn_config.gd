@tool
class_name CampSpawnConfig
extends Resource

@export var enabled: bool = false
@export_range(0.0, 86400.0, 1.0) var first_spawn_time: float = 60.0
@export_range(1.0, 86400.0, 1.0) var interval_min: float = 120.0
@export_range(1.0, 86400.0, 1.0) var interval_max: float = 180.0
@export_range(1, 20, 1) var maximum_camps: int = 2
@export_range(0.0, 1000.0, 1.0) var minimum_base_distance: float = 30.0
@export_range(1.0, 1000.0, 1.0) var maximum_base_distance: float = 100.0
@export_range(0.0, 100.0, 0.5) var camp_spacing: float = 10.0
@export var camp_pool: Array[CampPoolEntry] = []


func validation_error() -> String:
	if interval_min > interval_max:
		return "刷新最小间隔不能超过最大间隔"
	if minimum_base_distance > maximum_base_distance:
		return "距据点最小距离不能超过最大距离"
	if enabled and camp_pool.is_empty():
		return "启用营地生成时必须配置营地池"
	for entry: CampPoolEntry in camp_pool:
		if entry == null or entry.camp == null:
			return "营地池存在空方案"
		if entry.end_time >= 0.0 and entry.end_time <= entry.start_time:
			return "营地结束时间必须大于开始时间"
		var error: String = entry.camp.validation_error()
		if not error.is_empty():
			return entry.camp.display_name + "：" + error
	return ""


func draw_camp(elapsed: float, rng: RandomNumberGenerator) -> TreasureCampData:
	var available: Array[CampPoolEntry] = []
	var total: float = 0.0
	for entry: CampPoolEntry in camp_pool:
		if entry != null and entry.is_available(elapsed):
			available.append(entry)
			total += entry.weight
	if available.is_empty():
		return null
	var choice: float = rng.randf() * total
	for entry: CampPoolEntry in available:
		choice -= entry.weight
		if choice <= 0.0:
			return entry.camp
	return available.back().camp
