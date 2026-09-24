class_name ThreatDetectionManager
extends Node

signal threat_changed(has_threat: bool, direction: String)

var has_threat: bool = false
var threat_direction: String = "暂无"
var _last_direction: String = ""
var _last_has_threat: bool = false

func _ready() -> void:
	add_to_group("threat_detection")

func _process(_delta: float) -> void:
	var base: Node3D = get_tree().get_first_node_in_group("bases") as Node3D
	var enemy: Node3D = _find_nearest_enemy(base)
	var next_has_threat: bool = is_instance_valid(enemy)
	var next_direction: String = _get_direction(base, enemy) if next_has_threat else "暂无"
	if next_has_threat != _last_has_threat or next_direction != _last_direction:
		_last_has_threat = next_has_threat
		_last_direction = next_direction
		has_threat = next_has_threat
		threat_direction = next_direction
		threat_changed.emit(has_threat, threat_direction)

func _find_nearest_enemy(base: Node3D) -> Node3D:
	if base == null or not is_instance_valid(base):
		return null
	var nearest: Node3D = null
	var nearest_distance: float = INF
	for candidate: Node in get_tree().get_nodes_in_group("enemies"):
		var enemy: Node3D = candidate as Node3D
		if enemy == null or not is_instance_valid(enemy) or not enemy.is_visible_in_tree():
			continue
		if enemy.has_method("is_dead") and enemy.is_dead():
			continue
		var distance: float = base.global_position.distance_squared_to(enemy.global_position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = enemy
	return nearest

func _get_direction(base: Node3D, enemy: Node3D) -> String:
	var offset: Vector3 = enemy.global_position - base.global_position
	if absf(offset.x) >= absf(offset.z):
		return "东侧" if offset.x > 0.0 else "西侧"
	return "南侧" if offset.z > 0.0 else "北侧"
