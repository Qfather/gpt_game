@tool
class_name LevelFlowData
extends Resource

const WildlifeConfigResource = preload("res://Script/world/wildlife_config.gd")

@export_group("地图与资源")
@export var map_config: WFCLevelConfig
@export var layout_seed: int = -1
@export var fog_of_war_enabled: bool = true
@export_range(0, 200, 1) var rift_min_base_distance: float = 30.0
@export var map_resources: Array[MapResourceEntry] = []
@export var wildlife_config: WildlifeConfigResource = _default_wildlife_config()
@export var settlement_config: LevelConfig = preload("res://data/levels/Level_01.tres").duplicate(true)
@export_group("营地")
@export var camp_config: CampSpawnConfig
@export_group("出怪")
@export var monster_database: RaidGroupDatabase
@export var events: Array[LevelEventEntry] = []

func _default_wildlife_config() -> WildlifeConfigResource:
	var config: WildlifeConfigResource = preload("res://data/wildlife/WildlifeConfig.tres").duplicate(true)
	# 默认猎物嵌入各关卡，保存关卡即可保存调整，避免写到共用模板。
	for index: int in range(config.prey_pool.size()):
		config.prey_pool[index] = config.prey_pool[index].duplicate(true)
	return config

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
