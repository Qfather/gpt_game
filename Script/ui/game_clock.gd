extends Control

var time_label: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	time_label = Label.new()
	time_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	time_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	time_label.add_theme_font_size_override("font_size", 18)
	add_child(time_label)
	time_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(queue_redraw)
	set_elapsed_time(0.0)


func set_elapsed_time(seconds: float) -> void:
	var total: int = maxi(int(seconds), 0)
	time_label.text = "%02d:%02d" % [total / 60, total % 60]


func _draw() -> void:
	var center: Vector2 = size * 0.5
	var radius: float = minf(size.x, size.y) * 0.5 - 4.0
	draw_circle(center, radius, Color(0.04, 0.07, 0.11, 0.9))
	draw_arc(center, radius, 0.0, TAU, 96, Color(0.55, 0.75, 0.9), 3.0, true)
