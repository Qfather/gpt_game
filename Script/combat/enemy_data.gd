class_name EnemyData
extends Resource


@export_category("敌人标识")
@export var id: StringName = &""
@export var display_name: String = ""
@export var visual_scene: PackedScene
@export var abilities: Array[Resource] = []
@export var features: Array[FeatureEntry] = []

@export_category("基础战斗参数")
@export_range(1.0, 100000.0, 1.0) var max_health: float = 30.0
@export_range(0.0, 100000.0, 0.1) var damage: float = 5.0
@export_range(0.0, 100.0, 0.1) var move_speed: float = 2.5
@export_range(0.0, 100.0, 0.1) var attack_range: float = 1.2
@export_range(0.0, 1000.0, 0.1) var attack_interval: float = 1.0
@export_range(0.0, 100.0, 0.1) var detection_range: float = 8.0

@export_category("特殊标记")
@export var is_boss: bool = false

@export_category("阵营")
enum Faction {
	SETTLEMENT,
	HOSTILE,
}
@export var faction: Faction = Faction.HOSTILE
