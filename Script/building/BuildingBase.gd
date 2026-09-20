class_name BuildingBase
extends Node3D


signal building_clicked(building: BuildingBase)
signal building_demolished(building: BuildingBase)

@export var demolition_refund_ratio: float = 0.3

var building_data: BuildingData = null


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


func set_building_data(data: BuildingData) -> void:
	building_data = data


func get_building_data() -> BuildingData:
	return building_data


func can_be_demolished() -> bool:
	return (
		building_data != null
		and not is_in_group("bases")
		and not is_in_group("construction_sites")
	)


func demolish() -> bool:
	if not can_be_demolished():
		return false

	var task_managers: Array[Node] = get_tree().get_nodes_in_group(
		"task_manager"
	)
	if not task_managers.is_empty() and task_managers[0].has_method(
		"cancel_tasks_for_target"
	):
		task_managers[0].cancel_tasks_for_target(self, true)

	if has_method("release_all_workers"):
		call("release_all_workers")

	var refund_ratio: float = clampf(
		demolition_refund_ratio,
		0.0,
		1.0
	)
	var bases: Array[Node] = get_tree().get_nodes_in_group("bases")
	if not bases.is_empty() and bases[0].has_method("add_resource"):
		var base: Node = bases[0]
		for resource_key: StringName in building_data.construction_cost.keys():
			var construction_amount: float = float(
				building_data.construction_cost[resource_key]
			)
			var refund_amount: float = construction_amount * refund_ratio
			if refund_amount > 0.0:
				base.add_resource(resource_key, refund_amount)
				print(
					"拆除返还：",
					resource_key,
					" +",
					refund_amount
				)

	print("建筑拆除：", name, "，返还比例：", refund_ratio * 100.0, "%")
	building_demolished.emit(self)
	queue_free()
	return true


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
