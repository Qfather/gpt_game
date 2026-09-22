class_name GameHUD
extends CanvasLayer

signal build_requested(building_data: BuildingData)
signal enemy_placement_requested(enemy_data: EnemyData)
signal raid_requested()

const LUMBER_CAMP_DATA: BuildingData = preload(
	"res://data/buildings/LumberCampData.tres"
)
const QUARRY_DATA: BuildingData = preload(
	"res://data/buildings/QuarryData.tres"
)
const FARM_DATA: BuildingData = preload(
	"res://data/buildings/FarmData.tres"
)
const HOUSE_DATA: BuildingData = preload(
	"res://data/buildings/HouseData.tres"
)
const SWORDSMAN_CAMP_DATA: BuildingData = preload(
	"res://data/buildings/SwordsmanCampData.tres"
)
const BARRACKS_DATA: BuildingData = preload(
	"res://data/buildings/BarracksData.tres"
)
const RESOURCE_DATABASE: ResourceDatabase = preload(
	"res://data/resources/resource_database.tres"
)
const SLIME_DATA: EnemyData = preload("res://data/combat/SlimeData.tres")
const WOLF_DATA: EnemyData = preload("res://data/combat/WolfData.tres")
const PRODUCTION_BUILDINGS: Array[BuildingData] = [
	LUMBER_CAMP_DATA,
	QUARRY_DATA,
	FARM_DATA,
	HOUSE_DATA
]
const MILITARY_BUILDINGS: Array[BuildingData] = [
	SWORDSMAN_CAMP_DATA,
	BARRACKS_DATA
]


# ============================================================
# UI
# ============================================================

@onready var wood_label: Label = %WoodLabel
@onready var stone_label: Label = %StoneLabel
@onready var grain_label: Label = %GrainLabel
@onready var population_label: Label = %PopulationLabel
@onready var swordsman_label: Label = %SwordsmanLabel
@onready var immigration_status_label: Label = %ImmigrationStatusLabel
@onready var immigration_requirement_label: Label = %ImmigrationRequirementLabel
@onready var immigration_progress_bar: ProgressBar = %ImmigrationProgressBar
@onready var build_buttons: HBoxContainer = $BuildMenu/BuildMenuContent/BuildButtons
@onready var building_tabs: TabBar = $BuildMenu/BuildMenuContent/BuildingTabs


# ============================================================
# ResourceManager
# ============================================================

var resource_manager: ResourceManager = null
var population_manager: PopulationManager = null
var building_popup: PanelContainer = null
var building_popup_tab: Label = null
var building_popup_body: Label = null
var debug_panel: PanelContainer = null
var debug_resource_labels: Dictionary = {}
var debug_villager_section: VBoxContainer = null
var debug_villager_label: Label = null
var debug_villager: Node = null
var enemy_placement_button: Button = null
var selected_building_category: int = 0


# ============================================================
# 初始化
# ============================================================

func _ready() -> void:
	_create_debug_panel()
	_create_building_popup()
	_configure_building_menu()

	await get_tree().process_frame

	resource_manager = get_tree().get_first_node_in_group(
		"resource_manager"
	) as ResourceManager
	population_manager = get_tree().get_first_node_in_group(
		"population_manager"
	) as PopulationManager
	if population_manager != null:
		population_manager.population_changed.connect(_refresh_population_display)
		_refresh_population_display(
			population_manager.get_population(),
			population_manager.get_housing_capacity()
		)
		_refresh_immigration_display()

	if resource_manager == null:

		push_warning("HUD：没有找到 ResourceManager")

		update_resource_display()

		return

	resource_manager.resources_changed.connect(
		update_resource_display
	)
	update_resource_display()
	_refresh_debug_panel()


func _process(_delta: float) -> void:
	_refresh_debug_panel()
	if population_manager != null:
		_refresh_population_display(
			population_manager.get_population(),
			population_manager.get_housing_capacity()
		)
		_refresh_immigration_display()


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return

	match event.keycode:
		KEY_1:
			speed_1()
		KEY_2:
			speed_2()
		KEY_3:
			speed_3()
		KEY_4:
			speed_5()
		KEY_5:
			speed_10()
		KEY_SPACE:
			if get_tree().paused:
				resume_game()
			else:
				pause_game()
		_:
			return

	get_viewport().set_input_as_handled()


func _refresh_population_display(current_population: int, housing_capacity: int) -> void:
	population_label.text = "人口：%d / %d" % [current_population, housing_capacity]
	swordsman_label.text = "剑士：%d" % _get_swordsman_count()


func _get_swordsman_count() -> int:
	var count: int = 0
	for villager: Node in get_tree().get_nodes_in_group("villagers"):
		if (
			villager.has_method("get_combat_role")
			and villager.get_combat_role() == CombatRole.Type.SWORDSMAN
		):
			count += 1
	return count


func _refresh_immigration_display() -> void:
	if population_manager == null:
		return

	var status: Dictionary = population_manager.get_immigration_status()
	var countdown_active: bool = bool(status.get("countdown_active", false))
	var ready_emitted: bool = bool(status.get("ready_emitted", false))
	var group_size: int = int(status.get("group_size", 0))
	var progress: float = population_manager.get_immigration_progress()
	var required_housing: int = int(status.get("required_housing", 0))
	var free_housing: int = int(status.get("free_housing", 0))
	var required_food: float = float(status.get("required_food", 0.0))
	var available_food: float = float(status.get("available_food", 0.0))

	immigration_requirement_label.text = (
		"需要住房：%d　当前空房：%d\n需要食物：%d　当前食物：%d"
		% [
			required_housing,
			free_housing,
			int(ceil(required_food)),
			int(floor(available_food)),
		]
	)

	immigration_progress_bar.value = progress * 100.0
	if countdown_active:
		immigration_status_label.text = "移民倒计时：%d 人" % group_size
		return

	immigration_progress_bar.value = 0.0
	if ready_emitted:
		immigration_status_label.text = "移民队伍已出发：%d 人" % group_size
	elif bool(status.get("can_start", false)):
		immigration_status_label.text = "移民条件满足"
	else:
		immigration_status_label.text = "等待移民条件"


func _create_debug_panel() -> void:
	debug_panel = PanelContainer.new()
	debug_panel.name = "DebugPanel"
	debug_panel.position = Vector2(8.0, 150.0)
	debug_panel.custom_minimum_size = Vector2(245.0, 0.0)
	debug_panel.z_index = 10
	add_child(debug_panel)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 5)
	debug_panel.add_child(content)

	var title := Label.new()
	title.text = "调试工具"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(title)

	enemy_placement_button = Button.new()
	enemy_placement_button.text = "放置史莱姆"
	enemy_placement_button.pressed.connect(
		_on_debug_enemy_placement_pressed.bind(SLIME_DATA)
	)
	content.add_child(enemy_placement_button)

	var wolf_placement_button: Button = Button.new()
	wolf_placement_button.text = "放置狼"
	wolf_placement_button.pressed.connect(
		_on_debug_enemy_placement_pressed.bind(WOLF_DATA)
	)
	content.add_child(wolf_placement_button)

	var raid_button: Button = Button.new()
	raid_button.text = "生成第三方袭扰"
	raid_button.pressed.connect(func() -> void: raid_requested.emit())
	content.add_child(raid_button)

	var resource_title := Label.new()
	resource_title.text = "资源调整（据点库存）"
	content.add_child(resource_title)

	for resource_data: ResourceData in RESOURCE_DATABASE.resources:
		if resource_data == null or resource_data.id.is_empty():
			continue
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		content.add_child(row)

		var amount_label := Label.new()
		amount_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		amount_label.text = resource_data.display_name + "：0"
		row.add_child(amount_label)
		debug_resource_labels[resource_data.id] = amount_label

		var remove_button := Button.new()
		remove_button.text = "-10"
		remove_button.custom_minimum_size.x = 48.0
		remove_button.pressed.connect(
			_on_debug_resource_adjust.bind(resource_data.id, -10.0)
		)
		row.add_child(remove_button)

		var add_button := Button.new()
		add_button.text = "+10"
		add_button.custom_minimum_size.x = 48.0
		add_button.pressed.connect(
			_on_debug_resource_adjust.bind(resource_data.id, 10.0)
		)
		row.add_child(add_button)

	var separator := HSeparator.new()
	content.add_child(separator)

	debug_villager_section = VBoxContainer.new()
	debug_villager_section.add_theme_constant_override("separation", 4)
	content.add_child(debug_villager_section)
	debug_villager_section.hide()

	var villager_title := Label.new()
	villager_title.text = "选中居民需求"
	debug_villager_section.add_child(villager_title)

	debug_villager_label = Label.new()
	debug_villager_section.add_child(debug_villager_label)
	_create_debug_need_row("饥饿", "hunger", debug_villager_section)
	_create_debug_need_row("疲劳", "fatigue", debug_villager_section)


func _create_debug_need_row(
	caption: String,
	property_name: String,
	parent: Container
) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	parent.add_child(row)

	var label := Label.new()
	label.name = property_name.capitalize() + "DebugLabel"
	label.text = caption + "：0"
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)

	var remove_button := Button.new()
	remove_button.text = "-10"
	remove_button.custom_minimum_size.x = 48.0
	remove_button.pressed.connect(
		_on_debug_villager_adjust.bind(property_name, -10.0)
	)
	row.add_child(remove_button)

	var add_button := Button.new()
	add_button.text = "+10"
	add_button.custom_minimum_size.x = 48.0
	add_button.pressed.connect(
		_on_debug_villager_adjust.bind(property_name, 10.0)
	)
	row.add_child(add_button)


func set_debug_villager(villager: Node) -> void:
	debug_villager = villager
	_refresh_debug_panel()


func set_enemy_placement_active(active: bool) -> void:
	if enemy_placement_button == null:
		return
	enemy_placement_button.text = "点击地面放置史莱姆" if active else "放置史莱姆"


func _on_debug_enemy_placement_pressed(enemy_data: EnemyData) -> void:
	enemy_placement_requested.emit(enemy_data)


func _refresh_debug_panel() -> void:
	if debug_panel == null:
		return

	for resource_id: StringName in debug_resource_labels.keys():
		var label: Label = debug_resource_labels[resource_id] as Label
		if label == null:
			continue
		var resource_data: ResourceData = RESOURCE_DATABASE.get_resource_data(resource_id)
		var resource_name: String = str(resource_id)
		if resource_data != null and not resource_data.display_name.is_empty():
			resource_name = resource_data.display_name
		var amount: float = 0.0
		if resource_manager != null:
			amount = resource_manager.get_total(resource_id)
		label.text = "%s：%d" % [resource_name, int(amount)]

	var has_villager: bool = is_instance_valid(debug_villager)
	debug_villager_section.visible = has_villager
	if not has_villager:
		return

	debug_villager_label.text = "居民：%s" % debug_villager.name
	var hunger_label: Label = debug_villager_section.get_node_or_null(
		"HungerDebugLabel"
	) as Label
	var fatigue_label: Label = debug_villager_section.get_node_or_null(
		"FatigueDebugLabel"
	) as Label
	if hunger_label != null:
		hunger_label.text = "饥饿：%d" % int(float(debug_villager.get("hunger")))
	if fatigue_label != null:
		fatigue_label.text = "疲劳：%d" % int(float(debug_villager.get("fatigue")))


func _on_debug_resource_adjust(resource_id: StringName, amount: float) -> void:
	if get_tree().paused:
		var main_node: Node = get_tree().current_scene
		if main_node != null and main_node.has_method("execute_game_command"):
			main_node.execute_game_command(
				Callable(self, "_on_debug_resource_adjust").bind(
					resource_id,
					amount
				)
			)
		return
	var bases: Array[Node] = get_tree().get_nodes_in_group("bases")
	if bases.is_empty():
		return
	var base: Node = bases[0]
	if amount >= 0.0 and base.has_method("add_resource"):
		base.add_resource(resource_id, amount)
	elif amount < 0.0 and base.has_method("take_resource"):
		base.take_resource(resource_id, -amount)
	_refresh_debug_panel()


func _on_debug_villager_adjust(property_name: String, amount: float) -> void:
	if get_tree().paused:
		var main_node: Node = get_tree().current_scene
		if main_node != null and main_node.has_method("execute_game_command"):
			main_node.execute_game_command(
				Callable(self, "_apply_debug_villager_adjust").bind(
					debug_villager,
					property_name,
					amount
				)
			)
		return
	_apply_debug_villager_adjust(debug_villager, property_name, amount)


func _apply_debug_villager_adjust(
	villager: Node,
	property_name: String,
	amount: float
) -> void:
	if not is_instance_valid(villager):
		return
	var current_value: float = float(villager.get(property_name))
	villager.set(property_name, clampf(current_value + amount, 0.0, 100.0))
	_refresh_debug_panel()


func _configure_building_menu() -> void:
	building_tabs.tab_count = 2
	building_tabs.set_tab_title(0, "生产建筑")
	building_tabs.set_tab_title(1, "军事建筑")
	if not building_tabs.tab_changed.is_connected(_on_building_tab_changed):
		building_tabs.tab_changed.connect(_on_building_tab_changed)
	_refresh_building_buttons()


func _on_building_tab_changed(tab_index: int) -> void:
	selected_building_category = clampi(tab_index, 0, 1)
	_refresh_building_buttons()


func _refresh_building_buttons() -> void:
	for child: Node in build_buttons.get_children():
		child.free()

	var building_options: Array[BuildingData] = (
		PRODUCTION_BUILDINGS
		if selected_building_category == 0
		else MILITARY_BUILDINGS
	)
	for building_data: BuildingData in building_options:
		var button := Button.new()
		button.custom_minimum_size = Vector2(115.0, 48.0)
		button.text = building_data.display_name
		button.pressed.connect(_on_building_button_pressed.bind(building_data))
		button.mouse_entered.connect(
			_on_building_button_mouse_entered.bind(button, building_data)
		)
		button.mouse_exited.connect(_on_building_button_mouse_exited)
		build_buttons.add_child(button)


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
		grain_label.text = "谷物：0"

		return


	var wood_amount: float = resource_manager.get_total(
		&"wood"
	)

	var stone_amount: float = resource_manager.get_total(
		&"stone"
	)
	var grain_amount: float = resource_manager.get_total(
		&"grain"
	)


	wood_label.text = (
		"木材："
		+ str(int(wood_amount))
	)

	stone_label.text = (
		"石头："
		+ str(int(stone_amount))
	)
	grain_label.text = (
		"谷物："
		+ str(int(grain_amount))
	)


# ============================================================
# 时间控制
# ============================================================

func pause_game() -> void:

	get_tree().paused = true


func speed_1() -> void:

	Engine.time_scale = 1.0
	resume_game()


func speed_2() -> void:

	Engine.time_scale = 2.0
	resume_game()


func speed_3() -> void:

	Engine.time_scale = 3.0
	resume_game()


func speed_5() -> void:

	Engine.time_scale = 5.0
	resume_game()


func speed_10() -> void:

	Engine.time_scale = 10.0
	resume_game()


func resume_game() -> void:
	get_tree().paused = false
	var main_node: Node = get_tree().current_scene
	if main_node != null and main_node.has_method("flush_paused_game_commands"):
		main_node.flush_paused_game_commands()


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


func _on_speed_5_button_pressed() -> void:

	speed_5()


func _on_speed_10_button_pressed() -> void:

	speed_10()
