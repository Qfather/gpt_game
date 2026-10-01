extends Node3D

var effect: CompositorEffect
var camera: Camera3D
var initial_camera_transform: Transform3D
var orbit_target: Vector3
var orbit_yaw: float
var orbit_pitch: float
var orbit_distance: float = 22.0


func _ready() -> void:
	var original: Node3D = preload("res://addons/lens_effects/demo/upstream_demo.tscn").instantiate()
	add_child(original)
	camera = original.get_node("Camera3D")
	effect = original.get_node("WorldEnvironment").compositor.compositor_effects[0]
	initial_camera_transform = camera.transform
	orbit_target = camera.position - camera.basis.z * orbit_distance
	_sync_orbit()
	_create_controls()


func _sync_orbit() -> void:
	var offset := camera.position - orbit_target
	orbit_distance = offset.length()
	orbit_yaw = atan2(offset.x, offset.z)
	orbit_pitch = asin(offset.y / orbit_distance)


func _create_controls() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)
	var panel := PanelContainer.new()
	panel.position = Vector2(16.0, 16.0)
	panel.custom_minimum_size.x = 280.0
	canvas.add_child(panel)
	var margin := MarginContainer.new()
	for side: String in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	panel.add_child(margin)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	margin.add_child(content)
	var title := Label.new()
	title.text = "原项目光束演示"
	title.add_theme_font_size_override("font_size", 22)
	content.add_child(title)
	var toggle := CheckButton.new()
	toggle.text = "启用原插件效果"
	toggle.button_pressed = effect.enabled
	toggle.toggled.connect(func(enabled: bool) -> void: effect.enabled = enabled)
	content.add_child(toggle)
	_add_effect_slider(content, "效果强度", "Effect_Multiplier", 0.0, 5.0, 0.01)
	_add_effect_slider(content, "采样数", "SampleCount", 16.0, 200.0, 1.0)
	_add_effect_slider(content, "光束衰减", "Decay", 0.9, 1.0, 0.001)
	_add_effect_slider(content, "光束延伸", "Density", 0.1, 1.0, 0.01)
	_add_effect_slider(content, "遮挡权重", "Weight", 0.01, 0.5, 0.001)
	for view: String in ["作者视角", "俯视角度"]:
		var button := Button.new()
		button.text = view
		button.pressed.connect(_set_view.bind(view == "俯视角度"))
		content.add_child(button)
	var help := Label.new()
	help.text = "右键拖动：环绕镜头\n滚轮：拉近 / 拉远\n光束来自屏幕深度遮挡采样"
	content.add_child(help)


func _add_effect_slider(parent: VBoxContainer, title: String, property: String,
		minimum: float, maximum: float, step: float) -> void:
	var label := Label.new()
	label.text = "%s：%.3f" % [title, float(effect.get(property))]
	parent.add_child(label)
	var slider := HSlider.new()
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = step
	slider.value = float(effect.get(property))
	slider.value_changed.connect(func(value: float) -> void:
		label.text = "%s：%.3f" % [title, value]
		effect.set(property, int(value) if property == "SampleCount" else value))
	parent.add_child(slider)


func _set_view(top_down: bool) -> void:
	camera.transform = initial_camera_transform
	_sync_orbit()
	if top_down:
		orbit_pitch = 0.65
		_update_camera()


func _update_camera() -> void:
	var offset := Vector3(sin(orbit_yaw) * cos(orbit_pitch), sin(orbit_pitch),
		cos(orbit_yaw) * cos(orbit_pitch)) * orbit_distance
	camera.look_at_from_position(orbit_target + offset, orbit_target)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		orbit_yaw -= event.relative.x * 0.006
		orbit_pitch = clampf(orbit_pitch + event.relative.y * 0.006, -1.3, 1.3)
		_update_camera()
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			orbit_distance = maxf(5.0, orbit_distance - 1.5)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			orbit_distance = minf(45.0, orbit_distance + 1.5)
		_update_camera()
