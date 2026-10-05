extends RefCounted

const TURN_SPEED: float = PI / 0.4

# 单位模型以 +Z 为正面，只改变外观的水平朝向。
static func face_direction(visual: Node3D, direction: Vector3) -> void:
	if not is_instance_valid(visual) or Vector2(direction.x, direction.z).length_squared() < 0.0001:
		return
	visual.set_meta("facing_target_yaw", atan2(direction.x, direction.z))


static func update(visual: Node3D, delta: float) -> void:
	if not is_instance_valid(visual) or not visual.has_meta("facing_target_yaw"):
		return
	var yaw: float = visual.global_rotation.y
	var difference: float = wrapf(float(visual.get_meta("facing_target_yaw")) - yaw, -PI, PI)
	# 正好在身后时固定选择正方向，避免浮点误差使左右方向跳变。
	if is_equal_approx(absf(difference), PI):
		difference = PI
	visual.global_rotation.y = yaw + clampf(difference, -TURN_SPEED * delta, TURN_SPEED * delta)
