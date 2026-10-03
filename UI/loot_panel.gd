extends PanelContainer

signal closed

const RESOURCE_DATABASE: ResourceDatabase = preload("res://data/resources/resource_database.tres")

var bundle: LootBundle
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
	var title := Label.new()
	title.text = "战利品包裹"
	title.add_theme_font_size_override("font_size", 20)
	column.add_child(title)
	details = Label.new()
	details.custom_minimum_size.x = 310.0
	details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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

func open_bundle(value: LootBundle) -> void:
	bundle = value
	refresh()
	show()

func _process(_delta: float) -> void:
	if visible:
		if not is_instance_valid(bundle) or bundle.is_queued_for_deletion() or bool(bundle.get_meta("fog_hidden", false)):
			hide()
			closed.emit()
			return
		refresh()

func refresh() -> void:
	var lines: PackedStringArray = ["剩余物资："]
	for id: StringName in bundle.get_resource_ids():
		var data: ResourceData = RESOURCE_DATABASE.get_resource_data(id)
		lines.append("%s × %s" % [data.display_name if data != null else str(id), String.num(bundle.get_amount_for(id), 2)])
	var task: GameTask = bundle.pickup_task
	var status: String = "等待居民回收"
	if task != null and is_instance_valid(task.assigned_worker):
		status = "居民正在前来回收"
	lines.append("\n状态：" + status)
	details.text = "\n".join(lines)
