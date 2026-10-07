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
@export_storage var road_kind: int = 0

@export_category("道路加速")
@export_enum("固定值", "百分比") var road_speed_mode: int = 1:
	set(value):
		road_speed_mode = value
		notify_property_list_changed()
@export_range(0, 1000, 1) var road_speed_add: int = 0
@export_range(0, 1000, 0.1, "suffix:%") var road_speed_percent: float = 0.0

@export_category("道路材质与形态")
@export var road_material: StandardMaterial3D
## 贴图上方对应北方；尽头朝北、直线南北、拐角北东、三通北东西。
@export var road_texture_isolated: Texture2D
@export var road_texture_end: Texture2D
@export var road_texture_straight: Texture2D
@export var road_texture_corner: Texture2D
@export var road_texture_t: Texture2D
@export var road_texture_cross: Texture2D

@export_category("城墙连接场景")
## 模型原点位于格中心；北方为-Z。尽头朝北，直墙南北，拐角北东，三通北东西。
@export var wall_scene_isolated: PackedScene
@export var wall_scene_end: PackedScene
@export var wall_scene_straight: PackedScene
@export var wall_scene_corner: PackedScene
@export var wall_scene_t: PackedScene
@export var wall_scene_cross: PackedScene

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

@export_category("地表干燥影响")
@export var surface_drying_enabled: bool = true:
	set(value):
		surface_drying_enabled = value
		notify_property_list_changed()
## 从自然湿润度中最多减去的值；多个建筑取最强影响。
@export_range(0.0, 1.0, 0.01) var surface_drying_strength: float = 0.35
## 从占地边缘向外延伸的距离，单位米。
@export_range(0.0, 20.0, 0.1) var surface_drying_range: float = 2.0
@export_range(0.0, 1.0, 0.01) var surface_drying_noise: float = 0.3

@export_category("资源消耗")
## 键填写资源ID，例如 wood（木材）、stone（石头）；值填写所需数量。
@export var construction_cost: Dictionary[StringName, float] = {}
## 键填写资源ID，例如 wood（木材）、stone（石头）；值填写所需数量。
@export var training_cost: Dictionary[StringName, float] = {}

@export_category("建造参数")
@export var construction_time: float = 0.0
@export var max_construction_workers: int = 1

@export_category("放置选项")
@export var allow_rotation: bool = true
@export var allow_mirror: bool = true

@export_category("军事参数")
@export var garrison_capacity: int = 0


func _validate_property(property: Dictionary) -> void:
	var key: String = property.name
	var hidden: bool = false
	if key.begins_with("wall_scene_"):
		hidden = not is_wall()
	elif key.begins_with("road_"):
		hidden = road_kind == 0 or key == "road_kind"
		if key == "road_speed_add": hidden = hidden or road_speed_mode != 0
		if key == "road_speed_percent": hidden = hidden or road_speed_mode != 1
	elif road_kind > 0:
		hidden = key in ["building_scene", "max_health", "armor", "grid_size", "training_cost", "max_construction_workers", "allow_rotation", "allow_mirror", "garrison_capacity", "category"] or key.begins_with("surface_drying_")
	else:
		if key == "training_cost": hidden = id not in [&"swordsman_camp", &"archer_camp"]
		if key == "garrison_capacity":
			hidden = id not in [&"barracks", &"arrow_tower"] and not is_wall_tower()
			property.hint = PROPERTY_HINT_RANGE
			property.hint_string = "0,1,1" if is_wall_tower() else ("0,2,1" if id == &"arrow_tower" else "0,1000000,1")
		if key.begins_with("surface_drying_") and key != "surface_drying_enabled": hidden = not surface_drying_enabled
		if id == &"base" and key in ["sort_id", "construction_cost", "construction_time", "max_construction_workers"]: hidden = true
	if hidden: property.usage = PROPERTY_USAGE_NO_EDITOR


func road_move_speed(base_speed: float) -> float:
	return base_speed + road_speed_add if road_speed_mode == 0 else base_speed * (1.0 + road_speed_percent / 100.0)


func road_shape_material(shape: int) -> StandardMaterial3D:
	var textures: Array[Texture2D] = [road_texture_isolated, road_texture_end, road_texture_straight, road_texture_corner, road_texture_t, road_texture_cross]
	var material: StandardMaterial3D = road_material.duplicate() if road_material != null else StandardMaterial3D.new()
	if road_material == null:
		material.roughness = 1.0
		material.albedo_color = Color.WHITE if textures[shape] != null else (Color(0.43, 0.28, 0.13) if road_kind == 1 else Color(0.55, 0.59, 0.63))
	if textures[shape] != null: material.albedo_texture = textures[shape]
	return material


func is_wall() -> bool:
	return id in [&"wall", &"wood_wall"]

func is_gate() -> bool:
	return id in [&"gate", &"wood_gate"]

func is_wall_tower() -> bool:
	return id in [&"wall_tower", &"wood_wall_tower"]

func wall_family() -> StringName:
	return &"wood" if String(id).begins_with("wood_") else &"stone"

func wall_scenes() -> Array[PackedScene]:
	return [wall_scene_isolated, wall_scene_end, wall_scene_straight, wall_scene_corner, wall_scene_t, wall_scene_cross]
