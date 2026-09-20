class_name BuildingBase
extends Node3D


signal building_clicked(building: BuildingBase)


# ============================================================
# 点击区域
# ============================================================

@onready var click_area: CollisionObject3D = get_node_or_null("ClickArea")

var interaction_positions: Dictionary = {}


# ============================================================
# 初始化
# ============================================================

func _ready() -> void:
	add_to_group("buildings")

	if click_area == null:
		push_warning(
			"BuildingBase：%s 没有找到 ClickArea" % name
		)
		return

	click_area.input_event.connect(
		_on_click_area_input_event
	)


func get_interaction_position(worker: Node) -> Vector3:
	var worker_id: int = worker.get_instance_id() if worker != null else 0
	if not interaction_positions.has(worker_id):
		var slot_index: int = interaction_positions.size()
		var angle: float = float(slot_index) * 2.399963
		var radius: float = 2.0 + float(slot_index % 3) * 0.35
		interaction_positions[worker_id] = Vector3(
			cos(angle) * radius,
			0.0,
			sin(angle) * radius
		)

	return global_position + interaction_positions[worker_id]


# ============================================================
# 点击建筑
# ============================================================

func _on_click_area_input_event(
	_camera: Node,
	event: InputEvent,
	_event_position: Vector3,
	_normal: Vector3,
	_shape_idx: int
) -> void:

	if event is InputEventMouseButton:

		var mouse_event := event as InputEventMouseButton

		if (
			mouse_event.button_index == MOUSE_BUTTON_LEFT
			and mouse_event.pressed
		):
			building_clicked.emit(self)
			get_viewport().set_input_as_handled()
