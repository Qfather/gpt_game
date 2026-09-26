@tool
class_name MapResourceEntry
extends Resource

@export_group("关卡资源")
@export var enabled: bool = true
@export var display_name: String = "新地图资源"
@export var scene: PackedScene
@export_enum("树林噪声", "紧密资源簇") var distribution: int = 1:
	set(value):
		distribution = value
		notify_property_list_changed()
@export_range(0, 10000, 1) var count: int = 48
@export_range(0, 1, 0.01) var nearby_ratio: float = 0.5
@export_group("间距与簇（米）")
@export_range(0, 30, 0.05) var minimum_spacing: float = 1.45
@export_range(0, 30, 0.05) var neighbor_distance_max: float = 1.9
@export_storage var spacing_version: int = 0
@export_range(1, 1000, 1) var cluster_size: int = 8
@export_range(0.1, 100, 0.1) var cluster_radius: float = 4.0
@export_range(0, 100, 0.1) var cluster_separation: float = 0.0
@export_range(0, 1, 0.01) var scattered_weight: float = 0.015
@export_group("据点附近与远处（米）")
@export_range(0, 100, 0.5) var near_distance_min: float = 8.0
@export_range(0, 100, 0.5) var near_distance_max: float = 18.0
@export_range(0, 200, 0.5) var far_distance_min: float = 28.0
@export_group("地形权重")
@export var base_weight: float = 0.7
@export var altitude_weight: float = 0.25
@export var cliff_foot_bonus: float = 1.0
@export var cliff_top_bonus: float = 0.4


func migrate_spacing() -> void:
	if spacing_version >= 1 or scene == null:
		return
	var instance: Node = scene.instantiate()
	var collision: CollisionShape3D = instance.get_node_or_null("StaticBody3D/CollisionShape3D") as CollisionShape3D
	if collision != null and collision.shape != null:
		var bounds: AABB = (collision.get_parent() as Node3D).transform * collision.transform * collision.shape.get_debug_mesh().get_aabb()
		var radius: float = Vector2(bounds.size.x, bounds.size.z).length() * 0.5
		if collision.shape is CylinderShape3D:
			radius = maxf(bounds.size.x, bounds.size.z) * 0.5
		minimum_spacing = maxf(0.0, minimum_spacing - radius * 2.0)
		neighbor_distance_max = maxf(minimum_spacing, neighbor_distance_max - radius * 2.0)
		spacing_version = 1
	instance.free()


func validation_error() -> String:
	if scene == null:
		return "请选择资源场景"
	if neighbor_distance_max < minimum_spacing:
		return "簇内最大间距不能小于最小间距"
	if near_distance_max < near_distance_min:
		return "据点附近最大距离不能小于最小距离"
	if minimum_spacing < 0 or cluster_radius <= 0 or cluster_size < 1 or count < 0:
		return "间距、半径、簇数量或总数量无效"
	return ""


func _validate_property(property: Dictionary) -> void:
	if (property.name == "cluster_size" and distribution == 0) or (property.name == "scattered_weight" and distribution == 1):
		property.usage = PROPERTY_USAGE_NO_EDITOR
