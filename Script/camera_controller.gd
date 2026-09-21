class_name GameCameraController
extends Camera3D


@export var zoom_step: float = 1.5
@export var min_distance: float = 5.0
@export var max_distance: float = 35.0
@export var pan_speed: float = 0.035
@export var keyboard_pan_speed: float = 10.0
@export var rotate_speed: float = 0.008
@export var focus_smooth_speed: float = 8.0

var focus_target: Vector3 = Vector3.ZERO
var focus_destination: Vector3 = Vector3.ZERO
var orbit_yaw: float = 0.0
var orbit_pitch: float = 0.6
var orbit_distance: float = 18.0
var middle_button_held: bool = false


func _ready() -> void:
	var base: Node3D = get_tree().get_first_node_in_group("bases") as Node3D
	if base != null:
		focus_target = base.global_position
		focus_destination = focus_target
	else:
		focus_target = global_position + (-global_transform.basis.z * 10.0)
		focus_destination = focus_target
	var offset: Vector3 = global_position - focus_target
	orbit_distance = clampf(offset.length(), min_distance, max_distance)
	if orbit_distance > 0.01:
		orbit_yaw = atan2(offset.x, offset.z)
		orbit_pitch = asin(clampf(offset.y / orbit_distance, -0.95, 0.95))
	_update_camera_transform()


func _process(delta: float) -> void:
	_process_keyboard_pan(delta)
	if not focus_target.is_equal_approx(focus_destination):
		focus_target = focus_target.lerp(
			focus_destination,
			clampf(delta * focus_smooth_speed, 0.0, 1.0)
		)
	_update_camera_transform()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if mouse_button.button_index == MOUSE_BUTTON_MIDDLE:
			middle_button_held = mouse_button.pressed
			get_viewport().set_input_as_handled()
			return
		if mouse_button.pressed:
			if mouse_button.button_index == MOUSE_BUTTON_WHEEL_UP:
				_set_zoom(orbit_distance - zoom_step)
				get_viewport().set_input_as_handled()
				return
			if mouse_button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_set_zoom(orbit_distance + zoom_step)
				get_viewport().set_input_as_handled()
				return

	if event is InputEventMouseMotion and middle_button_held:
		var mouse_motion := event as InputEventMouseMotion
		if Input.is_key_pressed(KEY_SHIFT):
			_pan_by_mouse(mouse_motion.relative)
		else:
			orbit_yaw -= mouse_motion.relative.x * rotate_speed
			orbit_pitch = clampf(
				orbit_pitch + mouse_motion.relative.y * rotate_speed,
				0.15,
				1.35
			)
		get_viewport().set_input_as_handled()
		return

	if event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.pressed and not key_event.echo and key_event.keycode == KEY_F:
			_focus_selected_object()
			get_viewport().set_input_as_handled()


func _process_keyboard_pan(delta: float) -> void:
	var movement := Vector2.ZERO
	if Input.is_key_pressed(KEY_W):
		movement.y += 1.0
	if Input.is_key_pressed(KEY_S):
		movement.y -= 1.0
	if Input.is_key_pressed(KEY_A):
		movement.x -= 1.0
	if Input.is_key_pressed(KEY_D):
		movement.x += 1.0
	if movement.length_squared() <= 0.0:
		return
	movement = movement.normalized()
	var forward: Vector3 = -global_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var right: Vector3 = global_transform.basis.x
	right.y = 0.0
	right = right.normalized()
	_move_focus((right * movement.x + forward * movement.y)
		* keyboard_pan_speed * delta)


func _pan_by_mouse(relative: Vector2) -> void:
	var forward: Vector3 = -global_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var right: Vector3 = global_transform.basis.x
	right.y = 0.0
	right = right.normalized()
	_move_focus((-right * relative.x + forward * relative.y) * pan_speed)


func _move_focus(offset: Vector3) -> void:
	focus_target += offset
	focus_destination += offset


func _set_zoom(distance: float) -> void:
	orbit_distance = clampf(distance, min_distance, max_distance)


func _focus_selected_object() -> void:
	var main_node: Node = get_tree().current_scene
	if main_node == null:
		return
	var selected := main_node.get("selected_object") as Node3D
	if not is_instance_valid(selected):
		return
	focus_destination = selected.global_position


func _update_camera_transform() -> void:
	var horizontal_distance: float = orbit_distance * cos(orbit_pitch)
	var offset := Vector3(
		sin(orbit_yaw) * horizontal_distance,
		sin(orbit_pitch) * orbit_distance,
		cos(orbit_yaw) * horizontal_distance
	)
	global_position = focus_target + offset
	look_at(focus_target, Vector3.UP)
