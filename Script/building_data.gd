@tool
class_name BuildingData
extends Resource

enum Category { PRODUCTION, MILITARY, STRATEGY, ROAD, PROCESSING }
const CATEGORY_NAMES: Array[String] = ["生产", "军事", "战略", "道路", "加工"]

@export_category("建筑标识")
@export var id: StringName
@export var display_name: String = ""
@export_multiline var description: String = ""
@export_storage var function_text: String = ""
@export_enum("生产", "军事", "战略", "道路", "加工") var category: int = Category.PRODUCTION
@export var sort_id: int = 0
@export_enum("普通建筑", "土路", "石路") var road_kind: int = 0
@export_range(1.0, 3.0, 0.01) var road_speed_multiplier: float = 1.0

static func menu_less(a: BuildingData, b: BuildingData) -> bool:
	return a.sort_id < b.sort_id if a.sort_id != b.sort_id else str(a.id).naturalnocasecmp_to(str(b.id)) < 0

@export_category("建筑场景")
@export var building_scene: PackedScene
@export_storage var model_scene: PackedScene

@export_category("生命与仓储")
@export_range(1, 1000000, 1) var max_health: float = 300.0
@export_range(0, 1000000, 1) var armor: float = 1.0
@export_storage var storage_capacities: Dictionary[StringName, float] = {}

@export_category("建造参数")
@export var grid_size: Vector2i = Vector2i(1, 1)

@export_category("资源消耗")
@export var construction_cost: Dictionary[StringName, float] = {}
@export var training_cost: Dictionary[StringName, float] = {}

@export_category("建造参数")
@export var construction_time: float = 0.0
@export var max_construction_workers: int = 1

@export_category("放置选项")
@export var allow_rotation: bool = true
@export var allow_mirror: bool = true

@export_category("军事参数")
@export var garrison_capacity: int = 0
