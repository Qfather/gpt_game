@tool
class_name LevelFlowData
extends Resource

@export_group("地图与资源")
@export var map_config: WFCLevelConfig
@export var layout_seed: int = -1
@export_range(0, 200, 1) var rift_min_base_distance: float = 30.0
@export var map_resources: Array[MapResourceEntry] = []
@export_group("出怪")
@export var monster_database: RaidGroupDatabase
@export var events: Array[LevelEventEntry] = []

func get_final_rift_boss_event() -> LevelEventEntry:
	var final_event: LevelEventEntry
	for event: LevelEventEntry in events:
		if event == null:
			continue
		var group: RaidGroupData = event.get_monster_group()
		if group == null or group.group_type != RaidGroupData.GroupType.RIFT or not group.is_boss_group:
			continue
		if final_event == null or event.start_time > final_event.start_time:
			final_event = event
	return final_event
