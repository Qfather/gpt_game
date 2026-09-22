class_name WorldBounds
extends Node3D


@export_category("地图范围")
@export var world_size: Vector2 = Vector2(30.0, 30.0)
@export var settlement_size: Vector2 = Vector2(26.0, 26.0)
@export var patrol_margin: float = 2.0
@export var navigation_height: float = 0.3


func _ready() -> void:
	add_to_group("world_bounds")


func get_world_bounds() -> AABB:
	return _make_bounds(world_size)


func get_settlement_bounds() -> AABB:
	return _make_bounds(settlement_size)


func get_settlement_center() -> Vector3:
	return global_position


func get_patrol_point(index: int) -> Vector3:
	var bounds: AABB = get_settlement_bounds()
	var half_size: Vector2 = Vector2(bounds.size.x, bounds.size.z) * 0.5
	var patrol_half_size: Vector2 = Vector2(
		maxf(half_size.x - patrol_margin, 0.5),
		maxf(half_size.y - patrol_margin, 0.5)
	)
	var points: Array[Vector2] = [
		Vector2(-patrol_half_size.x, -patrol_half_size.y),
		Vector2(patrol_half_size.x, -patrol_half_size.y),
		Vector2(patrol_half_size.x, patrol_half_size.y),
		Vector2(-patrol_half_size.x, patrol_half_size.y)
	]
	var safe_index: int = posmod(index, points.size())
	return get_settlement_center() + Vector3(
		points[safe_index].x,
		navigation_height,
		points[safe_index].y
	)


func _make_bounds(size: Vector2) -> AABB:
	var safe_size: Vector2 = Vector2(maxf(size.x, 1.0), maxf(size.y, 1.0))
	return AABB(
		get_settlement_center() + Vector3(-safe_size.x * 0.5, 0.0, -safe_size.y * 0.5),
		Vector3(safe_size.x, 0.0, safe_size.y)
	)
