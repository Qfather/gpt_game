class_name ResourceBase
extends Node3D

signal resource_clicked(resource: ResourceBase)

# ============================================================
# 参数
# ============================================================

var resource_id: StringName = &"wood"

# 旧资源类型接口，仅保留兼容。
var resource_type: ResourceType.Type:
	get:
		return ResourceStorage.resource_type_from_id(resource_id)
	set(value):
		resource_id = ResourceStorage.resource_id_from_key(value)


func get_resource_id() -> StringName:
	return resource_id

@export var min_amount: int = 5
@export var max_amount: int = 10

## meshs 的直接子节点为完整外观候选；只缩放外观，不改变碰撞与资源量。
@export var visual_scale_min: float = 1.0
@export var visual_scale_max: float = 1.0
var visual_seed: int = -1


# ============================================================
# 运行数据
# ============================================================

var resource_amount: int = 0
var reserved_by: Node = null
var _build_obstacle_shape: Shape3D
var _build_obstacle_bounds: AABB


func get_build_obstacle_bounds() -> AABB:
	var collision: CollisionShape3D = get_node_or_null("StaticBody3D/CollisionShape3D") as CollisionShape3D
	if collision == null or collision.disabled or collision.shape == null:
		return AABB()
	# 缓存局部碰撞包围盒；位置、旋转与缩放仍按当前世界变换计算。
	if _build_obstacle_shape != collision.shape:
		if _build_obstacle_shape != null:
			_build_obstacle_shape.changed.disconnect(_refresh_build_obstacle_bounds)
		_build_obstacle_shape = collision.shape
		_build_obstacle_shape.changed.connect(_refresh_build_obstacle_bounds)
		_refresh_build_obstacle_bounds()
	return collision.global_transform * _build_obstacle_bounds


func _refresh_build_obstacle_bounds() -> void:
	_build_obstacle_bounds = _build_obstacle_shape.get_debug_mesh().get_aabb()


func overlaps_clearance_box(bounds: AABB, box_transform: Transform3D) -> bool:
	var own_bounds: AABB = get_build_obstacle_bounds()
	var box_bounds: AABB = box_transform * bounds
	if own_bounds.size == Vector3.ZERO or not own_bounds.intersects(box_bounds):
		return false
	var collision: CollisionShape3D = get_node("StaticBody3D/CollisionShape3D") as CollisionShape3D
	var outline: PackedVector2Array = ResourceSpacing.projected_box(bounds, box_transform)
	var scale: Vector3 = collision.global_basis.get_scale().abs()
	if collision.shape is CylinderShape3D and is_equal_approx(scale.x, scale.z) and collision.global_basis.y.normalized().is_equal_approx(Vector3.UP):
		var center := Vector2(collision.global_position.x, collision.global_position.z)
		return ResourceSpacing.circle_gap(center, (collision.shape as CylinderShape3D).radius * scale.x, outline) <= 0.001
	return ResourceSpacing.gap(ResourceSpacing.projected_box(_build_obstacle_bounds, collision.global_transform), outline) <= 0.001


func clear_for_construction() -> void:
	# 不走 gather，清障不产生库存收益；采集者沿既有失去目标分支重新选点。
	resource_amount = 0
	reserved_by = null
	queue_free()


func is_in_gather_range(position: Vector3) -> bool:
	var bounds: AABB = get_build_obstacle_bounds()
	var closest: Vector3 = position.clamp(bounds.position, bounds.end)
	return absf(position.y - closest.y) <= 1.0 and Vector2(position.x - closest.x, position.z - closest.z).length() <= 1.2


func get_gather_position(from: Vector3, navigation_map: RID) -> Vector3:
	var bounds: AABB = get_build_obstacle_bounds()
	var center: Vector3 = bounds.get_center()
	var direction := Vector2(from.x - center.x, from.z - center.z)
	var angle: float = direction.angle()
	var best := Vector3.INF
	var best_length: float = INF
	# 先检查朝向居民的一侧，再比较周围八个候选点的实际路径。
	for index: int in range(8):
		var normal := Vector2.from_angle(angle + float(index) * TAU / 8.0)
		var radius: float = minf(
			bounds.size.x * 0.5 / maxf(absf(normal.x), 0.0001),
			bounds.size.z * 0.5 / maxf(absf(normal.y), 0.0001)
		) + 0.9
		var candidate := Vector3(center.x + normal.x * radius, bounds.position.y, center.z + normal.y * radius)
		var point: Vector3 = NavigationServer3D.map_get_closest_point(navigation_map, candidate)
		if Vector2(point.x - candidate.x, point.z - candidate.z).length() > 0.4 or absf(point.y - candidate.y) > 1.0 or not is_in_gather_range(point):
			continue
		var path: PackedVector3Array = NavigationServer3D.map_get_path(navigation_map, from, point, true)
		if path.is_empty() or path[path.size() - 1].distance_to(point) > 0.2:
			continue
		var length: float = 0.0
		for segment: int in range(1, path.size()):
			length += path[segment - 1].distance_to(path[segment])
		if length < best_length:
			best_length = length
			best = point
	return best


# ============================================================
# 初始化
# ============================================================

func _ready():
	add_to_group("resources")
	_randomize_visual()

	resource_amount = randi_range(
		min_amount,
		max_amount
	)

	var click_body: CollisionObject3D = get_node_or_null("StaticBody3D")
	if click_body != null:
		click_body.process_mode = Node.PROCESS_MODE_ALWAYS
		click_body.input_event.connect(_on_click_body_input_event)
	call_deferred("_register_with_main")


func _randomize_visual() -> void:
	var container: Node3D = get_node_or_null("meshs") as Node3D
	if container == null or container.get_child_count() == 0:
		return
	var rng := RandomNumberGenerator.new()
	if visual_seed < 0:
		rng.randomize()
	else:
		rng.seed = visual_seed
	var chosen: int = rng.randi_range(0, container.get_child_count() - 1)
	for index: int in range(container.get_child_count()):
		var candidate: Node3D = container.get_child(index) as Node3D
		if index == chosen:
			candidate.show()
		else:
			candidate.hide()
			candidate.queue_free()
	container.rotate_y(rng.randf_range(0.0, TAU))
	container.scale *= rng.randf_range(visual_scale_min, visual_scale_max)


func _on_click_body_input_event(
	_camera: Node,
	event: InputEvent,
	_event_position: Vector3,
	_normal: Vector3,
	_shape_idx: int
) -> void:
	if not event is InputEventMouseButton:
		return

	var mouse_event: InputEventMouseButton = event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
		return

	resource_clicked.emit(self)
	get_viewport().set_input_as_handled()


func _register_with_main() -> void:
	if not is_inside_tree():
		return
	var scene_tree := get_tree()
	if scene_tree == null:
		return
	var main_node: Node = scene_tree.current_scene
	if main_node != null and main_node.has_method("register_resource"):
		main_node.register_resource(self)


# ============================================================
# 预约
# ============================================================

func is_reserved() -> bool:
	return reserved_by != null


func reserve(worker: Node) -> bool:

	if is_reserved():
		return false

	reserved_by = worker
	return true


func release(worker: Node):

	if reserved_by == worker:
		reserved_by = null


# ============================================================
# 采集
# ============================================================

func gather(amount: int) -> int:

	var gathered_amount: int = mini(
		amount,
		resource_amount
	)

	resource_amount -= gathered_amount

	print(
		"⛏️ 采集资源：",
		gathered_amount,
		" 剩余：",
		resource_amount
	)

	if resource_amount <= 0:
		queue_free()

	return gathered_amount
