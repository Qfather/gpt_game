class_name LevelConfig
extends Resource

@export_category("初始资源")
@export var initial_wood: float = 0.0
@export var initial_stone: float = 0.0
@export var initial_grain: float = 0.0

@export_category("初始居民")
@export var initial_villagers: int = 0

@export_category("人口规则")
@export var immigration_rules: ImmigrationRules = preload(
	"res://data/population/immigration_rules.tres"
)
