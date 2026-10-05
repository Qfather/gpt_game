@tool
class_name ResourceHitEffect
extends Resource

enum Kind { NONE, ROTATION, TRANSLATION, SCALE }
@export_enum("无动效", "旋转回弹", "位移回弹", "缩放回弹") var kind: int = Kind.NONE:
	set(value):
		kind = value
		notify_property_list_changed()
@export_range(0, 30, 0.1) var rotation_angle: float = 3.0
@export_range(0.01, 2, 0.01) var rotation_hit_time: float = 0.08
@export_range(0.01, 3, 0.01) var rotation_return_time: float = 0.25
@export_range(0, 1, 0.01) var translation_distance: float = 0.08
@export_range(0.01, 2, 0.01) var translation_hit_time: float = 0.06
@export_range(0.01, 3, 0.01) var translation_return_time: float = 0.18
@export_range(0, 0.8, 0.01) var scale_compression: float = 0.12
@export_range(0.01, 2, 0.01) var scale_hit_time: float = 0.07
@export_range(0.01, 3, 0.01) var scale_return_time: float = 0.22

func _validate_property(property: Dictionary) -> void:
	var prefixes: Array[String] = ["", "rotation_", "translation_", "scale_"]
	for index: int in range(1, prefixes.size()):
		if str(property.name).begins_with(prefixes[index]) and kind != index:
			property.usage &= ~PROPERTY_USAGE_EDITOR

func displaced(rest: Transform3D, away: Vector3) -> Transform3D:
	var result: Transform3D = rest
	match kind:
		Kind.ROTATION:
			result.basis = Basis(Vector3.UP.cross(away).normalized(), deg_to_rad(rotation_angle)) * rest.basis
		Kind.TRANSLATION:
			result.origin += away * translation_distance
		Kind.SCALE:
			result.basis = rest.basis.scaled_local(Vector3(1.0 + scale_compression * 0.5, 1.0 - scale_compression, 1.0 + scale_compression * 0.5))
	return result

func hit_time() -> float:
	return [0.0, rotation_hit_time, translation_hit_time, scale_hit_time][kind]

func return_time() -> float:
	return [0.0, rotation_return_time, translation_return_time, scale_return_time][kind]
