class_name ResourceBase
extends Node3D

signal resource_clicked(resource: ResourceBase)

# ============================================================
# 参数
# ============================================================

# 资源类型统一使用全局 ResourceType
var resource_type: ResourceType.Type = ResourceType.Type.WOOD

@export var min_amount: int = 5
@export var max_amount: int = 10


# ============================================================
# 运行数据
# ============================================================

var resource_amount: int = 0
var reserved_by: Node = null


# ============================================================
# 初始化
# ============================================================

func _ready():
	add_to_group("resources")

	resource_amount = randi_range(
		min_amount,
		max_amount
	)

	print(
		"🌍 ResourceBase启动：",
		name,
		" | groups = ",
		get_groups(),
		" | type = ",
		resource_type
	)

	var click_body: CollisionObject3D = get_node_or_null("StaticBody3D")
	if click_body != null:
		click_body.input_event.connect(_on_click_body_input_event)
	call_deferred("_register_with_main")


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
	var main_node: Node = get_tree().current_scene
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
