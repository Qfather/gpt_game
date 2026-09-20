class_name FarmField
extends Node3D

enum State {
	EMPTY,
	PLOWING,
	READY_TO_SOW,
	SOWING,
	GROWING,
	MATURE,
	HARVESTING
}

const STATE_NAMES: PackedStringArray = [
	"空地",
	"耕地中",
	"等待播种",
	"播种中",
	"生长中",
	"成熟",
	"收割中"
]

@export var field_id: String = "A"
@export var debug_initial_state: State = State.EMPTY
@export_range(1.0, 120.0, 1.0) var grow_time: float = 20.0

var state: State = State.EMPTY
var grow_timer: float = 0.0
var claimed_worker: Node = null
var claimed_state: State = State.EMPTY
var _field_mesh: MeshInstance3D = null
var _last_visual_state: State = State.EMPTY


func _ready() -> void:
	_field_mesh = get_node_or_null("FieldMesh") as MeshInstance3D
	set_state(debug_initial_state)


func _process(delta: float) -> void:
	if state != State.GROWING:
		return

	grow_timer += delta
	var current_grow_time := grow_time
	var farm := get_parent() as Farm
	if farm != null:
		current_grow_time = farm.grow_time
	if grow_timer >= current_grow_time:
		set_state(State.MATURE)


func set_state(next_state: State) -> void:
	state = next_state
	grow_timer = 0.0
	_update_visual()
	if state == State.MATURE:
		call_deferred("_notify_farm_field_available")


func get_state_name() -> String:
	if state < 0 or state >= STATE_NAMES.size():
		return "未知"
	return STATE_NAMES[state]


func get_state_text() -> String:
	var claim_text := "（处理中）" if is_instance_valid(claimed_worker) else ""
	return "Field %s：%s%s" % [field_id, get_state_name(), claim_text]


func can_claim() -> bool:
	if claimed_worker != null and not is_instance_valid(claimed_worker):
		_restore_claimed_state()
		claimed_worker = null
	return (
		claimed_worker == null
		and state in [State.EMPTY, State.READY_TO_SOW, State.MATURE]
	)


func claim(worker: Node) -> bool:
	if worker == null or not can_claim():
		return false
	claimed_worker = worker
	claimed_state = state
	match state:
		State.EMPTY:
			set_state(State.PLOWING)
		State.READY_TO_SOW:
			set_state(State.SOWING)
		State.MATURE:
			set_state(State.HARVESTING)
	return true


func release(worker: Node) -> void:
	if claimed_worker == worker:
		_restore_claimed_state()
		claimed_worker = null


func complete_work(worker: Node) -> bool:
	if claimed_worker != worker:
		return false

	var next_state: State
	match state:
		State.PLOWING:
			next_state = State.READY_TO_SOW
		State.SOWING:
			next_state = State.GROWING
		State.HARVESTING:
			next_state = State.EMPTY
		_:
			release(worker)
			return false

	claimed_worker = null
	set_state(next_state)
	return true


func _restore_claimed_state() -> void:
	if state in [State.PLOWING, State.SOWING, State.HARVESTING]:
		set_state(claimed_state)


func _notify_farm_field_available() -> void:
	var farm := get_parent() as Farm
	if farm != null:
		farm.dispatch_available_farmers()


func debug_advance_state() -> void:
	match state:
		State.EMPTY:
			set_state(State.PLOWING)
		State.PLOWING:
			set_state(State.READY_TO_SOW)
		State.READY_TO_SOW:
			set_state(State.SOWING)
		State.SOWING:
			set_state(State.GROWING)
		State.GROWING:
			set_state(State.MATURE)
		State.MATURE:
			set_state(State.HARVESTING)
		State.HARVESTING:
			set_state(State.EMPTY)


func _update_visual() -> void:
	if _field_mesh == null:
		return
	if _last_visual_state == state and _field_mesh.material_override != null:
		return

	var material := StandardMaterial3D.new()
	material.albedo_color = _get_state_color(state)
	_field_mesh.material_override = material
	_last_visual_state = state


func _get_state_color(current_state: State) -> Color:
	match current_state:
		State.EMPTY:
			return Color(0.24, 0.16, 0.08, 1.0)
		State.PLOWING:
			return Color(0.40, 0.25, 0.12, 1.0)
		State.READY_TO_SOW:
			return Color(0.60, 0.38, 0.14, 1.0)
		State.SOWING:
			return Color(0.30, 0.48, 0.16, 1.0)
		State.GROWING:
			return Color(0.20, 0.60, 0.18, 1.0)
		State.MATURE:
			return Color(0.88, 0.68, 0.14, 1.0)
		State.HARVESTING:
			return Color(0.92, 0.42, 0.10, 1.0)

	return Color.WHITE
