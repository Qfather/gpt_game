extends Camera3D

@export var move_speed := 8.0
@export var mouse_sensitivity := 0.003

var _pitch := 0.0

func _ready() -> void:
	_pitch = rotation.x

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if event.pressed else Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotation.y -= event.relative.x * mouse_sensitivity
		_pitch = clampf(_pitch - event.relative.y * mouse_sensitivity, deg_to_rad(-80.0), deg_to_rad(80.0))
		rotation.x = _pitch
	elif event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _process(delta: float) -> void:
	var move_direction := Vector3.ZERO
	var forward := -global_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var right := global_transform.basis.x
	right.y = 0.0
	right = right.normalized()

	if Input.is_physical_key_pressed(KEY_W):
		move_direction += forward
	if Input.is_physical_key_pressed(KEY_S):
		move_direction -= forward
	if Input.is_physical_key_pressed(KEY_D):
		move_direction += right
	if Input.is_physical_key_pressed(KEY_A):
		move_direction -= right
	if Input.is_physical_key_pressed(KEY_E):
		move_direction.y += 1.0
	if Input.is_physical_key_pressed(KEY_Q):
		move_direction.y -= 1.0

	if move_direction.length_squared() > 0.0:
		var speed := move_speed * (3.0 if Input.is_physical_key_pressed(KEY_SHIFT) else 1.0)
		global_position += move_direction.normalized() * speed * delta
