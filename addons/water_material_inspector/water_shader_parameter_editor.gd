@tool
extends EditorProperty

var _parameter_name := ""
var _control: Control
var _updating := false


func configure(parameter_name: String, display_label: String, value_type: Variant.Type) -> bool:
	_parameter_name = parameter_name
	label = display_label
	match value_type:
		TYPE_BOOL:
			var checkbox := CheckBox.new()
			checkbox.toggled.connect(_on_value_changed)
			_control = checkbox
		TYPE_INT, TYPE_FLOAT:
			var number := EditorSpinSlider.new()
			number.min_value = -1000000000.0
			number.max_value = 1000000000.0
			number.step = 0.001 if value_type == TYPE_FLOAT else 1.0
			number.editing_integer = value_type == TYPE_INT
			number.control_state = EditorSpinSlider.CONTROL_STATE_HIDE
			number.value_changed.connect(_on_value_changed)
			_control = number
		TYPE_COLOR:
			var color_picker := ColorPickerButton.new()
			color_picker.edit_alpha = true
			color_picker.color_changed.connect(_on_value_changed)
			_control = color_picker
		TYPE_OBJECT:
			var resource_picker := EditorResourcePicker.new()
			resource_picker.base_type = "Texture2D"
			resource_picker.resource_changed.connect(_on_value_changed)
			_control = resource_picker
		_:
			return false

	add_child(_control)
	add_focusable(_control)
	return true


func _update_property() -> void:
	var material := get_edited_object() as ShaderMaterial
	if material == null or _control == null:
		return
	var value: Variant = material.get_shader_parameter(_parameter_name)
	_updating = true
	if _control is CheckBox:
		_control.button_pressed = value
	elif _control is EditorSpinSlider:
		_control.value = value
	elif _control is ColorPickerButton:
		_control.color = value
	elif _control is EditorResourcePicker:
		_control.edited_resource = value
	_updating = false


func _on_value_changed(value: Variant) -> void:
	if _updating:
		return
	if _control is EditorSpinSlider and _control.editing_integer:
		value = roundi(value)
	emit_changed(get_edited_property(), value)
