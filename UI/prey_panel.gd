extends PanelContainer

signal closed

var prey: Node3D
var title: Label
var details: Label
var close_button: Button

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	offset_left = -360.0
	offset_right = -20.0
	offset_top = 130.0
	var margin := MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 14)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	margin.add_child(column)
	title = Label.new()
	title.add_theme_font_size_override("font_size", 20)
	column.add_child(title)
	details = Label.new()
	details.custom_minimum_size.x = 310.0
	column.add_child(details)
	close_button = Button.new()
	close_button.text = "关闭"
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.pressed.connect(func() -> void:
		hide()
		closed.emit()
	)
	column.add_child(close_button)
	hide()

func open_prey(value: Node3D) -> void:
	prey = value
	refresh()
	show()

func _process(_delta: float) -> void:
	if not visible:
		return
	if not is_instance_valid(prey) or prey.is_queued_for_deletion() or bool(prey.get_meta("fog_hidden", false)):
		hide()
		closed.emit()
		return
	refresh()

func refresh() -> void:
	title.text = prey.data.display_name
	details.text = "血量：%.0f / %d\n产肉量：%d" % [prey.health, prey.data.health, prey.data.meat_yield]
