@tool
class_name EnemyData
extends Resource

@export_category("敌人标识")
@export var id: StringName = &""
@export var display_name: String = ""
@export var visual_scene: PackedScene
@export var visual_tint: Color = Color.WHITE
@export var abilities: Array[Resource] = []
@export var ability_entries: Array[AbilityEntry] = []
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
	RAID,
	RIFT,
}
@export var faction: Faction = Faction.RAID

@export_category("袭扰行为")
enum RaidObjective {
	NONE,
	KILL_UNITS,
	DESTROY_BUILDINGS,
	STEAL_RESOURCES,
}
@export var raid_objective: RaidObjective = RaidObjective.NONE
@export var raid_kill_unit_id: StringName = &""
@export var raid_destroy_building_id: StringName = &""
@export var raid_steal_resource_id: StringName = &""
## 每次偷取的资源数量。
@export_range(1.0, 100.0, 1.0) var raid_steal_amount_per_tick: float = 3.0
## 两次偷取之间的间隔秒数。
@export_range(0.1, 30.0, 0.1) var raid_steal_interval: float = 1.0
## 本次袭扰的总携带额度，达到额度或找不到可偷资源时撤退。
@export_range(1.0, 100.0, 1.0) var raid_steal_quota: float = 15.0


func get_raid_steal_resource_id() -> StringName:
	return raid_steal_resource_id
