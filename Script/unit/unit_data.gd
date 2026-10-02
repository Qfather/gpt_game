@tool
class_name UnitData
extends Resource

# 配置字段对应现有居民脚本字段，保留原有行为入口。
const PARAMETERS: Dictionary = {
	"max_health": "base_max_health", "health_regen": "base_health_regen",
	"move_speed": "base_move_speed", "work_speed": "base_work_speed", "gather_speed": "base_gather_speed",
	"damage": "combat_damage", "attack_range": "combat_attack_range", "attack_interval": "combat_attack_interval",
	"detection_range": "combat_detection_range", "carry_capacity": "carry_capacity",
	"chop_amount": "chop_amount", "chop_interval": "chop_interval",
	"hunger_rate": "hunger_rate", "fatigue_rate": "fatigue_rate", "rest_recovery_rate": "rest_recovery_rate",
}

@export_category("单位标识与外观")
@export var id: StringName
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var visual_scene: PackedScene
@export var visual_tint: Color = Color.WHITE

@export_category("生命与移动")
@export_range(1, 100000, 1) var max_health: float = 100.0
@export_range(0, 1000, 0.1) var health_regen: float = 1.0
@export_range(0.1, 100, 0.1) var move_speed: float = 3.0

@export_category("工作与携带")
@export_range(0.1, 100, 0.1) var work_speed: float = 1.0
@export_range(0.1, 100, 0.1) var gather_speed: float = 1.0
@export_range(1, 1000, 1) var chop_amount: int = 1
@export_range(0.1, 1000, 0.1) var chop_interval: float = 1.0
@export_range(1, 1000, 1) var carry_capacity: float = 5.0

@export_category("战斗")
@export var uses_arrows: bool = false
@export_range(1, 100, 0.1) var arrow_speed: float = 18.0
@export_range(0, 100000, 0.1) var damage: float = 10.0
@export_range(0, 100, 0.1) var attack_range: float = 1.5
@export_range(0.1, 1000, 0.1) var attack_interval: float = 1.0
@export_range(0, 100, 0.1) var detection_range: float = 10.0

@export_category("居民需求")
@export_range(0, 10, 0.01) var hunger_rate: float = 0.12
@export_range(0, 10, 0.01) var fatigue_rate: float = 0.6
@export_range(0, 20, 0.1) var rest_recovery_rate: float = 4.0
