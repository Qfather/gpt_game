extends Node3D

@onready var day_night: Node = $StylizedDayNight
@onready var time_label: Label = $CanvasLayer/TimeLabel
@onready var camera: Camera3D = $Camera3D

var _rotating_camera: bool = false
var _camera_yaw: float = deg_to_rad(37.0)
var _camera_pitch: float = deg_to_rad(22.0)
var _camera_distance: float = 21.5
var _save_timer: Timer
var _setting_value_labels: Dictionary = {}
var _ring_list: VBoxContainer
var _ring_controls: VBoxContainer

const SETTINGS_PATH := "user://stylized_day_night_demo.cfg"


func _ready() -> void:
	_load_settings()
	_create_settings_hud()
	_save_timer = Timer.new()
	_save_timer.one_shot = true
	_save_timer.wait_time = 0.4
	_save_timer.timeout.connect(_save_settings)
	add_child(_save_timer)
	_update_camera()


func _exit_tree() -> void:
	_save_settings()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			_rotating_camera = event.pressed
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_camera_distance = maxf(7.0, _camera_distance - 1.5)
			_update_camera()
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_camera_distance = minf(45.0, _camera_distance + 1.5)
			_update_camera()
	elif event is InputEventMouseMotion and _rotating_camera:
		_camera_yaw -= event.relative.x * 0.006
		_camera_pitch = clampf(_camera_pitch + event.relative.y * 0.006, deg_to_rad(10.0), deg_to_rad(80.0))
		_update_camera()


func _process(_delta: float) -> void:
	var game_hour: float = float(day_night.get("game_hour"))
	var visibility: float = float(day_night.get("current_visibility_multiplier"))
	var hour: int = int(game_hour)
	var minute: int = int((game_hour - hour) * 60.0)
	time_label.text = "右键拖动旋转 · 滚轮缩放\n昼夜循环演示  %02d:%02d  视野倍率：%.0f%%" % [hour, minute, visibility * 100.0]
	for key in _setting_value_labels:
		if key == &"game_hour":
			_setting_value_labels[key].text = "%02d:%02d" % [hour, minute]


func _update_camera() -> void:
	var horizontal_distance := cos(_camera_pitch) * _camera_distance
	camera.global_position = Vector3(
		sin(_camera_yaw) * horizontal_distance,
		sin(_camera_pitch) * _camera_distance,
		cos(_camera_yaw) * horizontal_distance
	)
	camera.look_at(Vector3.ZERO, Vector3.UP)


func _create_settings_hud() -> void:
	var layer := CanvasLayer.new()
	layer.name = "SettingsHUD"
	add_child(layer)
	var panel := PanelContainer.new()
	panel.name = "SettingsPanel"
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.offset_left = -330.0
	panel.offset_right = -20.0
	panel.offset_top = 20.0
	panel.custom_minimum_size.x = 310.0
	layer.add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(310.0, 620.0)
	panel.add_child(scroll)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 7)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)
	var title := Label.new()
	title.text = "天空与昼夜设置（自动保存）"
	title.add_theme_font_size_override("font_size", 18)
	content.add_child(title)

	_add_slider(content, "当前时刻", &"game_hour", 0.0, 24.0, 0.1, float(day_night.get("game_hour")), "时")
	_add_slider(content, "昼夜周期", &"cycle_length_seconds", 60.0, 1800.0, 10.0, float(day_night.get("cycle_length_seconds")), "秒")
	_add_slider(content, "夜间视野", &"night_visibility_multiplier", 0.0, 1.0, 0.01, float(day_night.get("night_visibility_multiplier")), "%")
	_add_toggle(content, "昼夜计时暂停", &"cycle_paused", bool(day_night.get("cycle_paused")))
	_add_toggle(content, "启用云层", &"clouds_enabled", bool(day_night.get("clouds_enabled")))
	_add_cloud_style_selector(content)
	_add_slider(content, "云层密度", &"cloud_density", 0.25, 0.75, 0.01, float(day_night.get("cloud_density")), "")
	_add_slider(content, "云层大小", &"cloud_scale", 2.0, 12.0, 0.1, float(day_night.get("cloud_scale")), "")
	_add_slider(content, "模型云高度", &"mesh_cloud_altitude", -10.0, 10.0, 0.1, float(day_night.get("mesh_cloud_altitude")), "米")
	_add_cloud_ring_controls(content)
	_add_slider(content, "云层速度", &"cloud_speed", 0.0, 0.08, 0.001, float(day_night.get("cloud_speed")), "")
	_add_slider(content, "云层不透明度", &"cloud_opacity", 0.0, 1.0, 0.01, float(day_night.get("cloud_opacity")), "%")
	_add_hint(content)


func _add_slider(parent: VBoxContainer, title: String, property: StringName, minimum: float, maximum: float, step: float, initial: float, suffix: String) -> void:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var name_label := Label.new()
	name_label.text = title
	name_label.custom_minimum_size.x = 88.0
	row.add_child(name_label)
	var slider := HSlider.new()
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = step
	slider.value = initial
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(slider)
	var value_label := Label.new()
	value_label.custom_minimum_size.x = 48.0
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.text = _format_value(property, initial, suffix)
	row.add_child(value_label)
	_setting_value_labels[property] = value_label
	slider.value_changed.connect(_on_slider_changed.bind(property, suffix))


func _add_toggle(parent: VBoxContainer, title: String, property: StringName, initial: bool) -> void:
	var toggle := CheckButton.new()
	toggle.text = title
	toggle.button_pressed = initial
	parent.add_child(toggle)
	toggle.toggled.connect(_on_toggle_changed.bind(property))


func _add_cloud_style_selector(parent: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var title := Label.new()
	title.text = "云层样式"
	title.custom_minimum_size.x = 88.0
	row.add_child(title)
	var selector := OptionButton.new()
	selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	selector.add_item("程序化云", 0)
	selector.add_item("Synty 环形云 01", 1)
	selector.add_item("Synty 环形云 02", 2)
	selector.add_item("小云团环", 3)
	selector.select(int(day_night.get("cloud_style")))
	selector.item_selected.connect(_on_cloud_style_selected)
	row.add_child(selector)


func _add_cloud_ring_controls(parent: VBoxContainer) -> void:
	_ring_controls = VBoxContainer.new()
	_ring_controls.add_theme_constant_override("separation", 5)
	_ring_controls.visible = int(day_night.get("cloud_style")) == 3
	parent.add_child(_ring_controls)
	var title_row := HBoxContainer.new()
	_ring_controls.add_child(title_row)
	var title := Label.new()
	title.text = "环形云团"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title)
	var duplicate_button := Button.new()
	duplicate_button.text = "复制一环"
	duplicate_button.pressed.connect(_on_duplicate_ring_pressed)
	title_row.add_child(duplicate_button)
	_ring_list = VBoxContainer.new()
	_ring_list.add_theme_constant_override("separation", 5)
	_ring_controls.add_child(_ring_list)
	_refresh_cloud_ring_controls()


func _refresh_cloud_ring_controls() -> void:
	if _ring_list == null:
		return
	for child in _ring_list.get_children():
		_ring_list.remove_child(child)
		child.queue_free()
	var rings: Array[Dictionary] = day_night.get("cloud_rings")
	for ring_index in range(rings.size()):
		var ring_data: Dictionary = rings[ring_index]
		var header := HBoxContainer.new()
		_ring_list.add_child(header)
		var ring_title := Label.new()
		ring_title.text = "第 %d 环" % (ring_index + 1)
		ring_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		header.add_child(ring_title)
		var remove_button := Button.new()
		remove_button.text = "删除"
		remove_button.disabled = rings.size() <= 1
		remove_button.pressed.connect(_on_remove_ring_pressed.bind(ring_index))
		header.add_child(remove_button)
		_add_ring_slider(_ring_list, "半径", ring_index, "radius", 5.0, 80.0, 0.5, float(ring_data.get("radius", 25.0)), "米")
		_add_ring_slider(_ring_list, "高度", ring_index, "height", -10.0, 10.0, 0.1, float(ring_data.get("height", 0.0)), "米")
		_add_ring_slider(_ring_list, "Y旋转", ring_index, "rotation", 0.0, 360.0, 1.0, float(ring_data.get("rotation", 0.0)), "°")


func _add_ring_slider(parent: VBoxContainer, title: String, ring_index: int, key: String, minimum: float, maximum: float, step: float, initial: float, suffix: String) -> void:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var name_label := Label.new()
	name_label.text = title
	name_label.custom_minimum_size.x = 48.0
	row.add_child(name_label)
	var slider := HSlider.new()
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = step
	slider.value = initial
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(slider)
	var value_label := Label.new()
	value_label.custom_minimum_size.x = 45.0
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.text = _format_ring_value(key, initial, suffix)
	row.add_child(value_label)
	slider.value_changed.connect(_on_ring_setting_changed.bind(ring_index, key, value_label, suffix))


func _format_ring_value(key: String, value: float, suffix: String) -> String:
	if key == "rotation":
		return "%d%s" % [int(round(value)), suffix]
	return "%.1f%s" % [value, suffix]


func _on_ring_setting_changed(value: float, ring_index: int, key: String, value_label: Label, suffix: String) -> void:
	var rings: Array[Dictionary] = day_night.get("cloud_rings")
	var ring_data: Dictionary = rings[ring_index]
	ring_data[key] = value
	rings[ring_index] = ring_data
	day_night.set("cloud_rings", rings)
	day_night.call("refresh_settings")
	value_label.text = _format_ring_value(key, value, suffix)
	_schedule_save()


func _on_duplicate_ring_pressed() -> void:
	var rings: Array[Dictionary] = day_night.get("cloud_rings")
	var new_ring: Dictionary = {"radius": 25.0, "height": 0.0, "rotation": 0.0}
	if not rings.is_empty():
		new_ring = rings[rings.size() - 1].duplicate()
		new_ring["height"] = clampf(float(new_ring.get("height", 0.0)) + 3.0, -10.0, 10.0)
		new_ring["rotation"] = fposmod(float(new_ring.get("rotation", 0.0)) + 30.0, 360.0)
	rings.append(new_ring)
	day_night.set("cloud_rings", rings)
	day_night.call("refresh_settings")
	_refresh_cloud_ring_controls()
	_schedule_save()


func _on_remove_ring_pressed(ring_index: int) -> void:
	var rings: Array[Dictionary] = day_night.get("cloud_rings")
	if rings.size() <= 1:
		return
	rings.remove_at(ring_index)
	day_night.set("cloud_rings", rings)
	day_night.call("refresh_settings")
	_refresh_cloud_ring_controls()
	_schedule_save()


func _add_hint(parent: VBoxContainer) -> void:
	var hint := Label.new()
	hint.text = "右键拖动旋转镜头，滚轮缩放"
	hint.modulate = Color(0.78, 0.82, 0.9)
	parent.add_child(hint)


func _on_slider_changed(value: float, property: StringName, suffix: String) -> void:
	if property == &"game_hour":
		day_night.call("set_game_hour", value)
	else:
		day_night.set(property, value)
	day_night.call("refresh_settings")
	if property != &"game_hour":
		_setting_value_labels[property].text = _format_value(property, value, suffix)
	_schedule_save()


func _on_toggle_changed(enabled: bool, property: StringName) -> void:
	day_night.set(property, enabled)
	day_night.call("refresh_settings")
	_schedule_save()


func _on_cloud_style_selected(index: int) -> void:
	day_night.set("cloud_style", index)
	_ring_controls.visible = index == 3
	day_night.call("refresh_settings")
	_schedule_save()


func _format_value(property: StringName, value: float, suffix: String) -> String:
	if property == &"game_hour":
		var hour := int(value)
		var minute := int((value - hour) * 60.0)
		return "%02d:%02d" % [hour, minute]
	if property == &"night_visibility_multiplier" or property == &"cloud_opacity":
		return "%d%%" % int(round(value * 100.0))
	if property == &"cycle_length_seconds":
		return "%d%s" % [int(value), suffix]
	if property == &"mesh_cloud_altitude":
		return "%.1f%s" % [value, suffix]
	if property == &"cloud_speed":
		return "%.3f" % value
	return "%.2f%s" % [value, suffix]


func _load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return
	day_night.set("cycle_length_seconds", float(config.get_value("天空", "昼夜周期", day_night.get("cycle_length_seconds"))))
	day_night.set("night_visibility_multiplier", float(config.get_value("天空", "夜间视野", day_night.get("night_visibility_multiplier"))))
	day_night.set("cycle_paused", bool(config.get_value("天空", "计时暂停", day_night.get("cycle_paused"))))
	day_night.set("clouds_enabled", bool(config.get_value("云层", "启用", day_night.get("clouds_enabled"))))
	day_night.set("cloud_style", int(config.get_value("云层", "样式", day_night.get("cloud_style"))))
	day_night.set("cloud_density", float(config.get_value("云层", "密度", day_night.get("cloud_density"))))
	day_night.set("cloud_scale", float(config.get_value("云层", "大小", day_night.get("cloud_scale"))))
	var saved_cloud_height: float = float(config.get_value("云层", "模型云高度", day_night.get("mesh_cloud_altitude")))
	if saved_cloud_height < -10.0 or saved_cloud_height > 10.0:
		saved_cloud_height = 0.0
	day_night.set("mesh_cloud_altitude", saved_cloud_height)
	day_night.set("cloud_speed", float(config.get_value("云层", "速度", day_night.get("cloud_speed"))))
	day_night.set("cloud_opacity", float(config.get_value("云层", "不透明度", day_night.get("cloud_opacity"))))
	var saved_cloud_rings: Array[Dictionary] = []
	var ring_config: Variant = config.get_value("云层", "环形配置", [])
	if ring_config is Array:
		for ring in ring_config:
			if ring is Dictionary:
				saved_cloud_rings.append(ring)
	if not saved_cloud_rings.is_empty():
		day_night.set("cloud_rings", saved_cloud_rings)
	day_night.call("set_game_hour", float(config.get_value("天空", "当前时刻", day_night.get("start_hour"))))
	day_night.call("refresh_settings")


func _schedule_save() -> void:
	_save_timer.start()


func _save_settings() -> void:
	if not is_instance_valid(day_night):
		return
	var config := ConfigFile.new()
	config.set_value("天空", "昼夜周期", day_night.get("cycle_length_seconds"))
	config.set_value("天空", "夜间视野", day_night.get("night_visibility_multiplier"))
	config.set_value("天空", "计时暂停", day_night.get("cycle_paused"))
	config.set_value("天空", "当前时刻", day_night.get("game_hour"))
	config.set_value("云层", "启用", day_night.get("clouds_enabled"))
	config.set_value("云层", "样式", day_night.get("cloud_style"))
	config.set_value("云层", "密度", day_night.get("cloud_density"))
	config.set_value("云层", "大小", day_night.get("cloud_scale"))
	config.set_value("云层", "模型云高度", day_night.get("mesh_cloud_altitude"))
	config.set_value("云层", "速度", day_night.get("cloud_speed"))
	config.set_value("云层", "不透明度", day_night.get("cloud_opacity"))
	config.set_value("云层", "环形配置", day_night.get("cloud_rings"))
	config.save(SETTINGS_PATH)
