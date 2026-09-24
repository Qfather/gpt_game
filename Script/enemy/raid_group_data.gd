@tool
class_name RaidGroupData
extends Resource

enum GroupType { RAID, RIFT }
enum SpawnMode { FIXED, RANDOM }

@export var id: StringName = &""
@export var display_name: String = ""
@export var group_type: GroupType = GroupType.RAID
@export var spawn_mode: SpawnMode = SpawnMode.FIXED
@export var is_boss_group: bool = false
@export var unit_data: Array[EnemyData] = []
@export var fixed_unit_counts: PackedInt32Array = PackedInt32Array()
@export var unit_probabilities: PackedFloat32Array = PackedFloat32Array()
@export_range(1, 20, 1) var min_count: int = 1
@export_range(1, 20, 1) var max_count: int = 2

func _init() -> void:
	if unit_data == null:
		unit_data = []

func get_random_count() -> int:
	return randi_range(min_count, max_count)

func ensure_unit_settings() -> void:
	while fixed_unit_counts.size() < unit_data.size():
		fixed_unit_counts.append(1)
	while unit_probabilities.size() < unit_data.size():
		unit_probabilities.append(100.0)
	if fixed_unit_counts.size() > unit_data.size():
		fixed_unit_counts.resize(unit_data.size())
	if unit_probabilities.size() > unit_data.size():
		unit_probabilities.resize(unit_data.size())

func get_fixed_unit_count(index: int) -> int:
	ensure_unit_settings()
	return maxi(fixed_unit_counts[index], 0) if index >= 0 and index < fixed_unit_counts.size() else 0

func set_fixed_unit_count(index: int, count: int) -> void:
	ensure_unit_settings()
	if index >= 0 and index < fixed_unit_counts.size():
		fixed_unit_counts[index] = maxi(count, 0)

func get_unit_probability(index: int) -> float:
	ensure_unit_settings()
	return maxf(unit_probabilities[index], 0.0) if index >= 0 and index < unit_probabilities.size() else 0.0

func set_unit_probability(index: int, probability: float) -> void:
	ensure_unit_settings()
	if index >= 0 and index < unit_probabilities.size():
		unit_probabilities[index] = clampf(probability, 0.0, 100.0)

func get_fixed_plan() -> Array[EnemyData]:
	ensure_unit_settings()
	var result: Array[EnemyData] = []
	for index: int in range(unit_data.size()):
		var unit: EnemyData = unit_data[index]
		if not is_unit_compatible(unit):
			continue
		for _count: int in range(get_fixed_unit_count(index)):
			result.append(unit)
	return result

func get_random_plan(requested_count: int = -1) -> Array[EnemyData]:
	var valid: Array[EnemyData] = get_valid_units()
	var result: Array[EnemyData] = []
	if valid.is_empty():
		return result
	ensure_unit_settings()
	var total_weight: float = 0.0
	for index: int in range(unit_data.size()):
		if is_unit_compatible(unit_data[index]):
			total_weight += get_unit_probability(index)
	var amount: int = requested_count if requested_count >= 0 else 3
	for _count: int in range(maxi(amount, 0)):
		if total_weight <= 0.0:
			result.append(valid.pick_random())
			continue
		var choice: float = randf() * total_weight
		for index: int in range(unit_data.size()):
			if not is_unit_compatible(unit_data[index]):
				continue
			choice -= get_unit_probability(index)
			if choice <= 0.0:
				result.append(unit_data[index])
				break
	return result

func get_spawn_plan(random_count: int = -1) -> Array[EnemyData]:
	return get_random_plan(random_count) if spawn_mode == SpawnMode.RANDOM else get_fixed_plan()

func get_valid_units() -> Array[EnemyData]:
	var result: Array[EnemyData] = []
	for unit: EnemyData in unit_data:
		if is_unit_compatible(unit):
			result.append(unit)
	return result


func is_unit_compatible(unit: EnemyData) -> bool:
	if unit == null or unit.is_boss != is_boss_group:
		return false
	var expected_faction: int = EnemyData.Faction.RIFT if group_type == GroupType.RIFT else EnemyData.Faction.RAID
	return int(unit.faction) == expected_faction
