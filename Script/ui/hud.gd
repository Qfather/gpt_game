class_name GameHUD
extends CanvasLayer

signal build_requested(building_data: BuildingData)

const LUMBER_CAMP_DATA: BuildingData = preload(
	"res://data/buildings/LumberCampData.tres"
)
const QUARRY_DATA: BuildingData = preload(
	"res://data/buildings/QuarryData.tres"
)
const RESOURCE_DATABASE: ResourceDatabase = preload(
	"res://data/resources/resource_database.tres"
)
const BUILDING_OPTIONS: Array[BuildingData] = [
	LUMBER_CAMP_DATA,
	QUARRY_DATA
]


# ============================================================
# UI
# ============================================================

@onready var wood_label: Label = %WoodLabel
@onready var stone_label: Label = %StoneLabel
@onready var build_buttons: HBoxContainer = $BuildMenu/BuildButtons


# ============================================================
# ResourceManager
# ============================================================

var resource_manager: ResourceManager = null
var building_popup: PanelContainer = null
var building_popup_tab: Label = null
var building_popup_body: Label = null


# ============================================================
# 初始化
# ============================================================

func _ready() -> void:
	_create_building_popup()
	_configure_building_menu()

	await get_tree().process_frame

	resource_manager = get_tree().get_first_node_in_group(
		"resource_manager"
	) as ResourceManager

	if resource_manager == null:

		push_warning("HUD：没有找到 ResourceManager")

		update_resource_display()

		return

	resource_manager.resources_changed.connect(
		update_resource_display
	)
	update_resource_display()


func _configure_building_menu() -> void:
	var buttons: Array[Node] = build_buttons.get_children()
	for index in range(BUILDING_OPTIONS.size()):
		var building_data: BuildingData = BUILDING_OPTIONS[index]
		var button: Button
		if index < buttons.size():
			button = buttons[index] as Button
		else:
			button = Button.new()
			build_buttons.add_child(button)

		if button == null:
			continue
		button.text = building_data.display_name
		button.tooltip_text = ""
		if not button.pressed.is_connected(_on_building_button_pressed):
			button.pressed.connect(_on_building_button_pressed.bind(building_data))
		button.mouse_entered.connect(
			_on_building_button_mouse_entered.bind(button, building_data)
		)
		button.mouse_exited.connect(_on_building_button_mouse_exited)

	for index: int in range(BUILDING_OPTIONS.size(), buttons.size()):
		var unused_button: Button = buttons[index] as Button
		if unused_button != null:
			unused_button.hide()


func _create_building_popup() -> void:
	building_popup = PanelContainer.new()
	building_popup.name = "BuildingInfoPopup"
	building_popup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	building_popup.z_index = 20
	building_popup.custom_minimum_size = Vector2(280.0, 0.0)
	add_child(building_popup)

	var popup_box := VBoxContainer.new()
	popup_box.add_theme_constant_override("separation", 0)
	building_popup.add_child(popup_box)

	building_popup_tab = Label.new()
	building_popup_tab.custom_minimum_size = Vector2(0.0, 32.0)
	building_popup_tab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	building_popup_tab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	building_popup_tab.add_theme_color_override(
		"font_color",
		Color(0.95, 0.93, 0.82)
	)
	var tab_panel := PanelContainer.new()
	tab_panel.add_theme_stylebox_override(
		"panel",
		_create_popup_style(Color(0.18, 0.20, 0.24, 0.98), 8.0)
	)
	tab_panel.add_child(building_popup_tab)
	popup_box.add_child(tab_panel)

	building_popup_body = Label.new()
	building_popup_body.custom_minimum_size = Vector2(0.0, 90.0)
	building_popup_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	building_popup_body.add_theme_color_override(
		"font_color",
		Color(0.88, 0.88, 0.88)
	)
	var body_panel := PanelContainer.new()
	body_panel.add_theme_stylebox_override(
		"panel",
		_create_popup_style(Color(0.08, 0.09, 0.11, 0.98), 0.0)
	)
	body_panel.add_child(building_popup_body)
	popup_box.add_child(body_panel)
	building_popup.hide()


func _create_popup_style(color: Color, corner_radius: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color(0.42, 0.45, 0.52, 1.0)
	style.set_border_width_all(1)
	style.corner_radius_top_left = int(corner_radius)
	style.corner_radius_top_right = int(corner_radius)
	style.corner_radius_bottom_left = int(corner_radius)
	style.corner_radius_bottom_right = int(corner_radius)
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	return style


func _on_building_button_mouse_entered(
	button: Button,
	building_data: BuildingData
) -> void:
	if building_popup == null:
		return

	building_popup_tab.text = building_data.display_name
	building_popup_body.text = _get_building_tooltip_body(building_data)
	building_popup.show()
	await get_tree().process_frame

	var button_rect: Rect2 = button.get_global_rect()
	var popup_size: Vector2 = building_popup.get_combined_minimum_size()
	building_popup.size = popup_size
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var popup_x: float = button_rect.position.x + (button_rect.size.x - popup_size.x) * 0.5
	var popup_y: float = button_rect.position.y - popup_size.y - 8.0
	popup_x = clampf(popup_x, 6.0, maxf(6.0, viewport_size.x - popup_size.x - 6.0))
	if popup_y < 6.0:
		popup_y = button_rect.end.y + 8.0
	building_popup.position = Vector2(popup_x, popup_y)


func _on_building_button_mouse_exited() -> void:
	if building_popup != null:
		building_popup.hide()


func _on_building_button_pressed(building_data: BuildingData) -> void:
	build_requested.emit(building_data)


func _get_building_tooltip(building_data: BuildingData) -> String:
	return building_data.display_name + "\n" + _get_building_tooltip_body(building_data)


func _get_building_tooltip_body(building_data: BuildingData) -> String:
	var lines: PackedStringArray = []
	if not building_data.description.is_empty():
		lines.append("介绍：" + building_data.description)
	if not building_data.function_text.is_empty():
		lines.append("功能：" + building_data.function_text)

	var costs: PackedStringArray = []
	for resource_key: Variant in building_data.construction_cost.keys():
		var resource_id: StringName = ResourceStorage.resource_id_from_key(resource_key)
		var resource_name: String = str(resource_id)
		var resource_data: ResourceData = RESOURCE_DATABASE.get_resource_data(resource_id)
		if resource_data != null and not resource_data.display_name.is_empty():
			resource_name = resource_data.display_name
		costs.append("%s %d" % [resource_name, int(building_data.construction_cost[resource_key])])
	if not costs.is_empty():
		lines.append("所需材料：" + "、".join(costs))

	return "\n".join(lines)


func connect_building_ghost(ghost: BuildingGhost) -> void:
	if ghost != null and not build_requested.is_connected(ghost.select_building):
		build_requested.connect(ghost.select_building)


# ============================================================
# ResourceManager 信号会在资源发生变化时触发刷新。
# ============================================================


# ============================================================
# 更新资源显示
# ============================================================

func update_resource_display() -> void:

	if resource_manager == null:

		wood_label.text = "木材：0"
		stone_label.text = "石头：0"

		return


	var wood_amount: float = resource_manager.get_total(
		&"wood"
	)

	var stone_amount: float = resource_manager.get_total(
		&"stone"
	)


	wood_label.text = (
		"木材："
		+ str(int(wood_amount))
	)

	stone_label.text = (
		"石头："
		+ str(int(stone_amount))
	)


# ============================================================
# 时间控制
# ============================================================

func pause_game() -> void:

	get_tree().paused = true


func speed_1() -> void:

	get_tree().paused = false
	Engine.time_scale = 1.0


func speed_2() -> void:

	get_tree().paused = false
	Engine.time_scale = 2.0


func speed_3() -> void:

	get_tree().paused = false
	Engine.time_scale = 3.0


# ============================================================
# Button Signals
# ============================================================

func _on_pause_button_pressed() -> void:

	pause_game()


func _on_speed_1_button_pressed() -> void:

	speed_1()


func _on_speed_2_button_pressed() -> void:

	speed_2()


func _on_speed_3_button_pressed() -> void:

	speed_3()
