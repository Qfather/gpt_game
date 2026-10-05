class_name GameCameraController
extends Camera3D


@export_group("初始视角")
@export var 水平旋转弧度: float = 0.128
@export var 俯视角弧度: float = 0.738
@export var 初始视距: float = 21.445

@export_group("摄像机操作")
@export var 缩放步长: float = 1.5
@export var 最近视距: float = 5.0
@export var 最远视距: float = 35.0
@export var 鼠标平移速度: float = 0.035
@export var 键盘平移速度: float = 10.0
@export var 鼠标旋转速度: float = 0.008
@export var 键盘旋转速度: float = 2.5
@export var 聚焦平滑速度: float = 8.0

var focus_target: Vector3 = Vector3.ZERO
var focus_destination: Vector3 = Vector3.ZERO
var orbit_yaw: float = 0.128
var orbit_pitch: float = 0.738
var orbit_distance: float = 21.445
var middle_button_held: bool = false
var island_cells: Array[Rect2] = []
var character_camera: Camera3D = null
var viewed_character: CharacterBody3D = null
var generated_eye_viewpoint: Marker3D = null


func set_island_bounds(cells: Array[Vector2i], map_size: Vector2i, cell_size: float) -> void:
	island_cells.clear()
	var half_size: Vector2 = Vector2(map_size) * cell_size * 0.5
	for cell: Vector2i in cells:
		island_cells.append(Rect2(Vector2(cell) * cell_size - half_size, Vector2.ONE * cell_size))
	focus_target = _clamp_focus(focus_target)
	focus_destination = _clamp_focus(focus_destination)


func _clamp_focus(point: Vector3) -> Vector3:
	if island_cells.is_empty():
		return point
	var position_2d := Vector2(point.x, point.z)
	var nearest: Vector2 = position_2d
	var distance: float = INF
	for cell: Rect2 in island_cells:
		if cell.has_point(position_2d):
			return point
		var candidate: Vector2 = position_2d.clamp(cell.position + Vector2.ONE * 0.01, cell.end - Vector2.ONE * 0.01)
		var candidate_distance: float = candidate.distance_squared_to(position_2d)
		if candidate_distance < distance:
			distance = candidate_distance
			nearest = candidate
	return Vector3(nearest.x, point.y, nearest.y)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var base: Node3D = get_tree().get_first_node_in_group("bases") as Node3D
	if base != null:
		focus_target = base.global_position
		focus_destination = focus_target
	else:
		focus_target = global_position + (-global_transform.basis.z * 10.0)
		focus_destination = focus_target
	orbit_yaw = 水平旋转弧度
	orbit_pitch = clampf(俯视角弧度, 0.4, 0.8)
	orbit_distance = clampf(初始视距, 最近视距, 最远视距)
	_update_camera_transform()


func focus_on_position(target: Vector3) -> void:
	# 开局定位同步当前焦点与目标焦点，保留玩家使用的角度和缩放。
	focus_target = _clamp_focus(target)
	focus_destination = focus_target
	_update_camera_transform()


func _process(delta: float) -> void:
	if viewed_character != null or character_camera != null:
		if not is_instance_valid(viewed_character) or viewed_character.is_queued_for_deletion() or not is_instance_valid(character_camera):
			_leave_character_view()
		elif viewed_character.has_method("is_dead") and viewed_character.call("is_dead"):
			_leave_character_view()
		return
	_process_keyboard_pan(delta)
	_process_keyboard_rotate(delta)
	if not focus_target.is_equal_approx(focus_destination):
		focus_target = focus_target.lerp(
			focus_destination,
			clampf(delta * 聚焦平滑速度, 0.0, 1.0)
		)
	# 平滑聚焦也不能穿过岛屿轮廓中的海湾或空洞。
	focus_target = _clamp_focus(focus_target)
	_update_camera_transform()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_T:
		if is_instance_valid(character_camera):
			_leave_character_view()
		else:
			_enter_character_view()
		get_viewport().set_input_as_handled()
		return
	if is_instance_valid(character_camera):
		# 角色视角只旁观，输入不传给相机、建造工具或世界点击。
		get_viewport().set_input_as_handled()


func _enter_character_view() -> void:
	var main_node: Node = get_tree().current_scene
	if main_node == null:
		return
	var selected := main_node.get("selected_object") as CharacterBody3D
	if not is_instance_valid(selected) or selected.is_queued_for_deletion() or selected.get_meta("fog_hidden", false):
		return
	if selected.has_method("is_dead") and selected.call("is_dead"):
		return
	var viewpoint := selected.find_child("EyeViewpoint", true, false) as Node3D
	if viewpoint != null and viewpoint.is_queued_for_deletion():
		viewpoint = null
	if viewpoint == null:
		var left_eye := selected.find_child("LeftEye", true, false) as Node3D
		var right_eye := selected.find_child("RightEye", true, false) as Node3D
		if left_eye == null:
			left_eye = selected.find_child("Eye-1", true, false) as Node3D
			right_eye = selected.find_child("Eye-2", true, false) as Node3D
		generated_eye_viewpoint = Marker3D.new()
		generated_eye_viewpoint.name = "EyeViewpoint"
		if left_eye != null and right_eye != null:
			var model := left_eye.get_parent() as Node3D
			model.add_child(generated_eye_viewpoint)
			generated_eye_viewpoint.position = model.to_local((left_eye.global_position + right_eye.global_position) * 0.5) + Vector3(0, 0, 0.03)
		else:
			selected.add_child(generated_eye_viewpoint)
			generated_eye_viewpoint.position = Vector3(0, 1.4, 0.25)
		# 现有模型正脸朝 +Z；自定义 EyeViewpoint 使用 -Z 作为视线方向。
		generated_eye_viewpoint.rotation.y = PI
		viewpoint = generated_eye_viewpoint
	character_camera = Camera3D.new()
	character_camera.name = "CharacterEyeCamera"
	character_camera.near = 0.03
	character_camera.far = far
	character_camera.cull_mask = cull_mask
	viewpoint.add_child(character_camera)
	viewed_character = selected
	middle_button_held = false
	character_camera.make_current()


func _leave_character_view() -> void:
	make_current()
	if is_instance_valid(character_camera):
		character_camera.queue_free()
	if is_instance_valid(generated_eye_viewpoint):
		generated_eye_viewpoint.queue_free()
	character_camera = null
	generated_eye_viewpoint = null
	viewed_character = null
	middle_button_held = false


func _unhandled_input(event: InputEvent) -> void:
	if is_instance_valid(character_camera):
		return
	if event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if mouse_button.button_index == MOUSE_BUTTON_MIDDLE:
			middle_button_held = mouse_button.pressed
			get_viewport().set_input_as_handled()
			return
		if mouse_button.pressed:
			if mouse_button.button_index == MOUSE_BUTTON_WHEEL_UP:
				_set_zoom(orbit_distance - 缩放步长)
				get_viewport().set_input_as_handled()
				return
			if mouse_button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_set_zoom(orbit_distance + 缩放步长)
				get_viewport().set_input_as_handled()
				return

	if event is InputEventMouseMotion and middle_button_held:
		var mouse_motion := event as InputEventMouseMotion
		if Input.is_key_pressed(KEY_SHIFT):
			_pan_by_mouse(mouse_motion.relative)
		else:
			orbit_yaw -= mouse_motion.relative.x * 鼠标旋转速度
			orbit_pitch = clampf(orbit_pitch + mouse_motion.relative.y * 鼠标旋转速度, 0.4, 0.8)
		get_viewport().set_input_as_handled()
		return

	if event is InputEventKey:
		var key_event := event as InputEventKey
		if not key_event.pressed or key_event.echo:
			return
		if key_event.keycode == KEY_F:
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
		* 键盘平移速度 * delta)


func _process_keyboard_rotate(delta: float) -> void:
	var direction: float = 0.0
	if Input.is_key_pressed(KEY_Q):
		direction -= 1.0
	if Input.is_key_pressed(KEY_E):
		direction += 1.0
	if is_zero_approx(direction):
		return
	orbit_yaw += direction * 键盘旋转速度 * delta


func _pan_by_mouse(relative: Vector2) -> void:
	var forward: Vector3 = -global_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var right: Vector3 = global_transform.basis.x
	right.y = 0.0
	right = right.normalized()
	_move_focus((-right * relative.x + forward * relative.y) * 鼠标平移速度)


func _move_focus(offset: Vector3) -> void:
	focus_target = _clamp_focus(focus_target + offset)
	focus_destination = _clamp_focus(focus_destination + offset)


func _set_zoom(distance: float) -> void:
	orbit_distance = clampf(distance, 最近视距, 最远视距)


func _focus_selected_object() -> void:
	var main_node: Node = get_tree().current_scene
	if main_node == null:
		return
	var selected := main_node.get("selected_object") as Node3D
	if not is_instance_valid(selected):
		return
	focus_destination = _clamp_focus(selected.global_position)


func _update_camera_transform() -> void:
	var horizontal_distance: float = orbit_distance * cos(orbit_pitch)
	var offset := Vector3(
		sin(orbit_yaw) * horizontal_distance,
		sin(orbit_pitch) * orbit_distance,
		cos(orbit_yaw) * horizontal_distance
	)
	global_position = focus_target + offset
	look_at(focus_target, Vector3.UP)
