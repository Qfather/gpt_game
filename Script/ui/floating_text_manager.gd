class_name FloatingTextManager
extends CanvasLayer

@export var display_duration: float = 1.0
@export var rise_speed: float = 45.0

var floating_items: Array[Dictionary] = []


func show_resource_loss(world_position: Vector3, amount: float) -> void:
	var label := Label.new()
	label.text = "-%s" % _format_amount(amount)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.custom_minimum_size = Vector2(90.0, 32.0)
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", Color(1.0, 0.82, 0.18, 1.0))
	label.add_theme_color_override("font_shadow_color", Color(0.12, 0.06, 0.0, 0.9))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	floating_items.append({
		"label": label,
		"world_position": world_position,
		"age": 0.0,
	})


func _process(delta: float) -> void:
	var camera: Camera3D = get_viewport().get_camera_3d()
	for index: int in range(floating_items.size() - 1, -1, -1):
		var item: Dictionary = floating_items[index]
		var label: Label = item["label"] as Label
		item["age"] = float(item["age"]) + delta
		var age: float = float(item["age"])
		if age >= display_duration or not is_instance_valid(label):
			if is_instance_valid(label):
				label.queue_free()
			floating_items.remove_at(index)
			continue
		if camera == null:
			continue
		var world_position: Vector3 = item["world_position"]
		label.visible = not camera.is_position_behind(world_position)
		if label.visible:
			label.position = camera.unproject_position(world_position) - Vector2(45.0, age * rise_speed)
		label.modulate.a = 1.0 - age / display_duration
		floating_items[index] = item


func _format_amount(amount: float) -> String:
	if is_equal_approx(amount, roundf(amount)):
		return str(int(roundf(amount)))
	return "%.1f" % amount
