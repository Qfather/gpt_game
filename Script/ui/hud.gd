class_name GameHUD
extends CanvasLayer

signal build_requested(building_data: BuildingData)
signal enemy_placement_requested(enemy_data: EnemyData)
signal raid_requested()
signal road_requested(data: BuildingData)
signal unreachable_villager_clicked(villager: UnitBase)

const RESOURCE_DATABASE: ResourceDatabase = preload(
	"res://data/resources/resource_database.tres"
)
var resource_labels: Dictionary[StringName, Label] = {}
var menu_buildings: Array[BuildingData] = []
var blueprint_window: Window
var blueprint_pool_picker: OptionButton
var militia_label: Label
var blueprint_was_paused: bool = false


# ============================================================
# UI
# ============================================================

@onready var wood_label: Label = %WoodLabel
@onready var stone_label: Label = %StoneLabel
@onready var grain_label: Label = %GrainLabel
@onready var meat_label: Label = %MeatLabel
@onready var population_label: Label = %PopulationLabel
@onready var resident_label: Label = %ResidentLabel
@onready var swordsman_label: Label = %SwordsmanLabel
@onready var archer_label: Label = %ArcherLabel
@onready var immigration_status_label: Label = %ImmigrationStatusLabel
@onready var immigration_requirement_label: Label = %ImmigrationRequirementLabel
@onready var immigration_progress_bar: ProgressBar = %ImmigrationProgressBar
var immigration_refresh_button: Button
@onready var build_buttons: HBoxContainer = $BuildMenu/BuildMenuContent/BuildButtons
@onready var building_tabs: TabBar = $BuildMenu/BuildMenuContent/BuildingTabs
@onready var pause_button: Button = $PanelContainer/VBoxContainer/HBoxContainer/PauseButton


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
var selected_building_category: int = 0
var defeat_overlay: Control = null
var victory_overlay: Control = null
var threat_label: Label = null
var death_notifications: VBoxContainer
var raid_countdown_label: Label = null
var debug_scroll: ScrollContainer
var debug_toggle: Button
var game_clock: Control
var unreachable_icons: HBoxContainer
var unreachable_buttons: Dictionary = {}
var fps_label: Label
var idle_resident_label: Label
var fps_update_msec: int = 0


# ============================================================
# 初始化
# ============================================================

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_configure_status_layout()
	_create_debug_panel()
	_create_building_popup()
	_configure_building_menu()
	var catalog := BuildingCatalog.for_tree(get_tree())
	if catalog != null: catalog.blueprints_changed.connect(_configure_building_menu)
	_create_defeat_overlay()
	_create_victory_overlay()
	_create_threat_label()
	_create_raid_countdown_label()
	_create_unreachable_icons()

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
	var now: int = Time.get_ticks_msec()
	if now >= fps_update_msec:
		fps_label.text = "帧率：%d FPS" % Engine.get_frames_per_second()
		fps_update_msec = now + 500
	var director: EncounterDirector = get_tree().get_first_node_in_group("encounter_director") as EncounterDirector
	if director != null:
		game_clock.set_elapsed_time(director.elapsed_time)
	_refresh_debug_panel()
	_refresh_raid_countdown()
	_refresh_unreachable_icons()
	if population_manager != null:
		_refresh_population_display(
			population_manager.get_population(),
			population_manager.get_housing_capacity()
		)
		_refresh_immigration_display()


func _create_defeat_overlay() -> void:
	defeat_overlay = ColorRect.new()
	defeat_overlay.name = "DefeatOverlay"
	defeat_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	defeat_overlay.color = Color(0.02, 0.02, 0.02, 0.82)
	defeat_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	defeat_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	defeat_overlay.z_index = 200
	defeat_overlay.hide()
	add_child(defeat_overlay)

	var box: VBoxContainer = VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	box.position = Vector2(-140.0, -90.0)
	box.size = Vector2(280.0, 180.0)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	defeat_overlay.add_child(box)

	var title: Label = Label.new()
	title.text = "据点已被摧毁"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	box.add_child(title)

	var message: Label = Label.new()
	message.text = "游戏失败"
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(message)

	var restart_button: Button = Button.new()
	restart_button.text = "重新开始"
	restart_button.custom_minimum_size = Vector2(140.0, 36.0)
	restart_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	restart_button.pressed.connect(_on_restart_pressed)
	box.add_child(restart_button)


func show_defeat_screen() -> void:
	if defeat_overlay != null:
		defeat_overlay.show()


func _create_victory_overlay() -> void:
	victory_overlay = ColorRect.new()
	victory_overlay.name = "VictoryOverlay"
	victory_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	victory_overlay.color = Color(0.02, 0.02, 0.02, 0.82)
	victory_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	victory_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	victory_overlay.z_index = 200
	victory_overlay.hide()
	add_child(victory_overlay)
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	box.position = Vector2(-140.0, -90.0)
	box.size = Vector2(280.0, 180.0)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	victory_overlay.add_child(box)
	var title := Label.new()
	title.text = "关底BOSS已击败"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	box.add_child(title)
	var message := Label.new()
	message.text = "游戏胜利"
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(message)
	var restart_button := Button.new()
	restart_button.text = "重新开始"
	restart_button.custom_minimum_size = Vector2(140.0, 36.0)
	restart_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	restart_button.pressed.connect(_on_restart_pressed)
	box.add_child(restart_button)


func show_victory_screen() -> void:
	if victory_overlay != null:
		victory_overlay.show()


func _on_restart_pressed() -> void:
	var main_node: Node = get_tree().current_scene
	if main_node != null and main_node.has_method("restart_game"):
		main_node.restart_game()


func _create_threat_label() -> void:
	threat_label = Label.new()
	threat_label.name = "ThreatDirectionLabel"
	threat_label.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	threat_label.position = Vector2(12.0, -16.0)
	threat_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	threat_label.text = "威胁方向：暂无"
	threat_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.35, 1.0))
	threat_label.z_index = 20
	add_child(threat_label)
	death_notifications = VBoxContainer.new()
	death_notifications.name = "DeathNotifications"
	death_notifications.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	death_notifications.position = Vector2(12.0, 12.0)
	death_notifications.mouse_filter = Control.MOUSE_FILTER_IGNORE
	death_notifications.z_index = 20
	add_child(death_notifications)
	call_deferred("_connect_threat_manager")


func show_friendly_death(unit_name: String) -> void:
	var notice := Label.new()
	notice.text = "%s 已死亡" % unit_name
	notice.mouse_filter = Control.MOUSE_FILTER_IGNORE
	notice.add_theme_color_override("font_color", Color(1.0, 0.4, 0.35))
	death_notifications.add_child(notice)
	get_tree().create_timer(5.0, true, false, true).timeout.connect(notice.queue_free)


func _create_raid_countdown_label() -> void:
	raid_countdown_label = Label.new()
	raid_countdown_label.name = "RaidCountdownLabel"
	raid_countdown_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	raid_countdown_label.position = Vector2(-250.0, -72.0)
	raid_countdown_label.size = Vector2(235.0, 32.0)
	raid_countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	raid_countdown_label.add_theme_color_override("font_color", Color(1.0, 0.75, 0.35, 1.0))
	raid_countdown_label.z_index = 20
	add_child(raid_countdown_label)


func _create_unreachable_icons() -> void:
	unreachable_icons = HBoxContainer.new()
	unreachable_icons.name = "UnreachableVillagerIcons"
	unreachable_icons.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	unreachable_icons.offset_left = 12.0
	unreachable_icons.offset_right = 290.0
	unreachable_icons.offset_top = -172.0
	unreachable_icons.offset_bottom = -124.0
	unreachable_icons.z_index = 20
	unreachable_icons.hide()
	add_child(unreachable_icons)


func _refresh_unreachable_icons() -> void:
	var wanted: Dictionary = {}
	for node: Node in get_tree().get_nodes_in_group("villagers"):
		var villager: UnitBase = node as UnitBase
		if villager == null or villager.is_queued_for_deletion() or villager.is_dead():
			continue
		if not villager.has_method("has_unreachable_warning") or not villager.has_unreachable_warning():
			continue
		var key: int = villager.get_instance_id()
		wanted[key] = true
		if unreachable_buttons.has(key):
			continue
		var button := Button.new()
		button.custom_minimum_size = Vector2(42.0, 42.0)
		button.tooltip_text = "无法到达：点击定位并选择 " + villager.get_named_display_name()
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.65, 0.47, 0.18)
		style.set_border_width_all(2)
		style.border_color = Color(1.0, 0.82, 0.15)
		button.add_theme_stylebox_override("normal", style)
		button.add_theme_stylebox_override("hover", style)
		button.pressed.connect(unreachable_villager_clicked.emit.bind(villager))
		unreachable_icons.add_child(button)
		var alert := Label.new()
		alert.text = "!"
		alert.add_theme_color_override("font_color", Color(1.0, 0.95, 0.2))
		alert.position = Vector2(30.0, -5.0)
		button.add_child(alert)
		unreachable_buttons[key] = button
	for key: int in unreachable_buttons.keys():
		if wanted.has(key):
			continue
		unreachable_buttons[key].queue_free()
		unreachable_buttons.erase(key)
	unreachable_icons.visible = not unreachable_buttons.is_empty()


func _refresh_raid_countdown() -> void:
	if raid_countdown_label == null:
		return
	var director: EncounterDirector = get_tree().get_first_node_in_group("encounter_director") as EncounterDirector
	if director == null:
		raid_countdown_label.text = "支线袭扰：暂无袭扰"
		return
	var status: Dictionary = director.get_next_raid_status()
	if not bool(status.get("active", false)):
		raid_countdown_label.text = "支线袭扰：暂无袭扰"
		return
	raid_countdown_label.text = "支线袭扰：%s  %02d 秒" % [
		str(status.get("display_name", "袭扰")),
		int(ceil(float(status.get("remaining", 0.0))))
	]


func _connect_threat_manager() -> void:
	var manager: ThreatDetectionManager = get_tree().get_first_node_in_group("threat_detection") as ThreatDetectionManager
	if manager != null:
		if not manager.threat_changed.is_connected(_on_threat_changed):
			manager.threat_changed.connect(_on_threat_changed)
		_on_threat_changed(manager.has_threat, manager.threat_direction)


func _on_threat_changed(has_threat: bool, direction: String) -> void:
	if threat_label != null:
		threat_label.text = "威胁方向：%s" % (direction if has_threat else "暂无")


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.keycode == KEY_H:
		if event.pressed and not event.echo:
			var ui: CanvasLayer = get_parent()
			ui.visible = not ui.visible
			# 子画布层不继承父画布层的显隐，需要一起切换。
			for layer: CanvasLayer in ui.find_children("*", "CanvasLayer", true, false):
				layer.visible = ui.visible
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.keycode == KEY_SPACE:
		if event.pressed and not event.echo:
			if get_tree().paused: resume_game()
			else: pause_game()
		get_viewport().set_input_as_handled()


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
		_:
			return

	get_viewport().set_input_as_handled()


func _refresh_population_display(current_population: int, housing_capacity: int) -> void:
	idle_resident_label.text = str(_get_idle_resident_count())
	population_label.text = "%d / %d" % [current_population, housing_capacity]
	militia_label.text = str(_get_combat_role_count(CombatRole.Type.MILITIA))
	resident_label.text = str(_get_combat_role_count(CombatRole.Type.NONE))
	swordsman_label.text = str(_get_swordsman_count())
	archer_label.text = str(_get_combat_role_count(CombatRole.Type.ARCHER))


func _get_swordsman_count() -> int:
	return _get_combat_role_count(CombatRole.Type.SWORDSMAN)


func _get_idle_resident_count() -> int:
	var count: int = 0
	for villager: Node in get_tree().get_nodes_in_group("villagers"):
		if is_instance_valid(villager) and villager.has_method("is_idle_resident") and villager.is_idle_resident():
			count += 1
	return count


func _get_combat_role_count(role: int) -> int:
	var count: int = 0
	for villager: Node in get_tree().get_nodes_in_group("villagers"):
		if (
			villager.has_method("get_combat_role")
			and villager.get_combat_role() == role
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
	if status.has("group_name"):
		immigration_requirement_label.text = "%s\n住房：%d / %d　%s：%d / %d" % [status.group_name, maxi(free_housing, 0), required_housing, status.food_name, int(floor(available_food)), int(ceil(required_food))]
		if not status.building_requirements.is_empty():
			immigration_requirement_label.text += "\n建筑：" + status.building_requirements
		if not status.trait_names.is_empty():
			immigration_requirement_label.text += "\n来者标签：" + status.trait_names
	var cooldown: float = population_manager.refresh_cooldown_remaining
	immigration_refresh_button.disabled = cooldown > 0.0 or not status.has("group_name")
	immigration_refresh_button.text = "刷新需求（%d 秒）" % int(ceil(cooldown)) if cooldown > 0.0 else "刷新移民需求"

	immigration_progress_bar.value = progress * 100.0
	if countdown_active:
		immigration_status_label.text = "移民倒计时：%d 人" % group_size
		return

	immigration_progress_bar.value = 0.0
	if ready_emitted:
		immigration_status_label.text = "移民队伍已出发：%d 人" % int(status.get("pending_migrant_count", group_size))
	elif bool(status.get("can_start", false)):
		immigration_status_label.text = "移民条件满足"
	else:
		immigration_status_label.text = "等待移民条件"


func _create_debug_panel() -> void:
	debug_panel = PanelContainer.new()
	debug_panel.name = "DebugPanel"
	debug_panel.position = Vector2(8.0, 120.0)
	debug_panel.custom_minimum_size = Vector2(245.0, 0.0)
	debug_panel.z_index = 10
	add_child(debug_panel)

	var box := VBoxContainer.new()
	debug_panel.add_child(box)
	var header := HBoxContainer.new()
	box.add_child(header)

	var title := Label.new()
	title.text = "调试工具"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	debug_toggle = Button.new()
	debug_toggle.text = "▶"
	debug_toggle.tooltip_text = "展开调试工具"
	header.add_child(debug_toggle)
	debug_toggle.pressed.connect(_toggle_debug_panel)
	debug_scroll = ScrollContainer.new()
	debug_scroll.custom_minimum_size = Vector2(270, 240)
	debug_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(debug_scroll)
	debug_scroll.hide()
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 5)
	debug_scroll.add_child(content)

	blueprint_pool_picker = OptionButton.new()
	var catalog := BuildingCatalog.for_tree(get_tree())
	var pools: Array[StringName] = []
	if catalog != null:
		for data: BuildingData in catalog.buildings.values():
			if data.requires_blueprint and not pools.has(data.blueprint_pool): pools.append(data.blueprint_pool)
	pools.sort()
	for pool: StringName in pools:
		blueprint_pool_picker.add_item(str(pool))
		blueprint_pool_picker.set_item_metadata(blueprint_pool_picker.item_count - 1, pool)
		if pool == &"standard": blueprint_pool_picker.select(blueprint_pool_picker.item_count - 1)
	content.add_child(blueprint_pool_picker)
	var draw_button := Button.new()
	draw_button.name = "DrawBlueprintButton"
	draw_button.text = "测试：抽取建筑蓝图（三选一）"
	draw_button.pressed.connect(show_blueprint_choices)
	content.add_child(draw_button)
	var navigation_toggle := CheckButton.new()
	navigation_toggle.name = "NavigationDebugToggle"
	navigation_toggle.text = "显示寻路地图"
	get_tree().debug_navigation_hint = false
	NavigationServer3D.set_debug_enabled(false)
	navigation_toggle.button_pressed = false
	navigation_toggle.toggled.connect(func(enabled: bool) -> void:
		var runtime: MapGenerateRuntime = get_tree().get_first_node_in_group("map_generate_runtime") as MapGenerateRuntime
		if runtime != null:
			runtime.set_navigation_debug_visible(enabled)
	)
	content.add_child(navigation_toggle)

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


func _toggle_debug_panel() -> void:
	debug_scroll.visible = not debug_scroll.visible
	debug_toggle.text = "▼" if debug_scroll.visible else "▶"
	debug_toggle.tooltip_text = "收起调试工具" if debug_scroll.visible else "展开调试工具"
	debug_panel.reset_size()


func _configure_status_layout() -> void:
	# 两侧各自贴近中央计时器，帧率独立保留在右上角。
	$PanelContainer.position = Vector2(8, 8)
	var materials := _create_status_row("ResourceStatus", true)
	var original_labels := {&"wood": wood_label, &"stone": stone_label, &"grain": grain_label, &"meat": meat_label}
	for data: ResourceData in RESOURCE_DATABASE.resources:
		var label: Label = original_labels[data.id] if original_labels.has(data.id) else Label.new()
		resource_labels[data.id] = label
		_add_status_item(materials, label, data.icon, data.display_name)
	var population := _create_status_row("PopulationStatus", false)
	militia_label = Label.new()
	for item: Array in [
		[resident_label, "ResidentData"], [militia_label, "MilitiaData"],
		[swordsman_label, "SwordsmanData"], [archer_label, "ArcherData"]
	]:
		var data: UnitData = load("res://data/units/%s.tres" % item[1])
		var entry := _add_status_item(population, item[0], data.icon, data.display_name)
		if item[0] == resident_label:
			idle_resident_label = Label.new()
			idle_resident_label.text = "0"
			idle_resident_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			idle_resident_label.add_theme_font_size_override("font_size", 12)
			idle_resident_label.tooltip_text = "空闲居民：没有岗位和任务、正在待命；不包含休息、进食、撤退和军事单位"
			idle_resident_label.mouse_filter = Control.MOUSE_FILTER_STOP
			entry.add_child(idle_resident_label)
	_add_status_item(population, population_label, preload("res://assets/icons/population.svg"), "总人口 / 住房容量")
	fps_label = Label.new()
	fps_label.name = "FPSLabel"
	add_child(fps_label)
	fps_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	fps_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	fps_label.offset_left = -130
	fps_label.offset_right = -12
	fps_label.offset_top = 12
	fps_label.offset_bottom = 36
	$PanelContainer.reset_size()
	var immigration: Control = $ImmigrationPanel
	immigration.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	immigration.grow_vertical = Control.GROW_DIRECTION_BEGIN
	immigration.offset_left = 12
	immigration.offset_right = 370
	immigration.offset_top = -210
	immigration.offset_bottom = -12
	immigration_requirement_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	immigration_refresh_button = Button.new()
	immigration_refresh_button.name = "RefreshImmigrationButton"
	immigration_refresh_button.tooltip_text = "重新抽取当前阶段需求，冷却60秒游戏时间；已出发的队伍保留"
	$ImmigrationPanel/VBoxContainer.add_child(immigration_refresh_button)
	immigration_refresh_button.pressed.connect(func() -> void:
		if population_manager != null and population_manager.refresh_immigration_requirements():
			_refresh_immigration_display()
	)
	game_clock = Control.new()
	game_clock.name = "GameClock"
	game_clock.set_script(preload("res://Script/ui/game_clock.gd"))
	add_child(game_clock)
	game_clock.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	game_clock.offset_left = -48
	game_clock.offset_right = 48
	game_clock.offset_top = 12
	game_clock.offset_bottom = 108


func _create_status_row(row_name: String, left: bool) -> HBoxContainer:
	var panel := PanelContainer.new()
	panel.name = row_name
	add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN if left else Control.GROW_DIRECTION_END
	panel.offset_left = -60 if left else 60
	panel.offset_right = -60 if left else 60
	panel.offset_top = 16
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	panel.add_child(row)
	return row


func _add_status_item(parent: HBoxContainer, label: Label, texture: Texture2D, title: String) -> VBoxContainer:
	var entry := VBoxContainer.new()
	entry.custom_minimum_size.x = 44
	entry.tooltip_text = title
	entry.mouse_filter = Control.MOUSE_FILTER_STOP
	parent.add_child(entry)
	var icon := TextureRect.new()
	icon.texture = texture if texture != null else preload("res://assets/icons/placeholder.svg")
	icon.custom_minimum_size = Vector2(32, 32)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	entry.add_child(icon)
	if label.get_parent() != null:
		label.reparent(entry)
	else:
		entry.add_child(label)
	label.text = "0"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return entry


func set_debug_villager(villager: Node) -> void:
	debug_villager = villager
	_refresh_debug_panel()


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
	menu_buildings.clear()
	for file: String in DirAccess.get_files_at("res://data/buildings/"):
		if not file.ends_with(".tres"): continue
		var data: BuildingData = load("res://data/buildings/" + file) as BuildingData
		if data != null and data.id not in [&"base", &"wall", &"gate", &"wall_tower"]:
			var catalog := BuildingCatalog.for_tree(get_tree())
			if catalog == null or catalog.can_build(data): menu_buildings.append(data)
	menu_buildings.sort_custom(BuildingData.menu_less)
	building_tabs.tab_count = BuildingData.CATEGORY_NAMES.size()
	for index: int in range(building_tabs.tab_count):
		building_tabs.set_tab_title(index, BuildingData.CATEGORY_NAMES[index])
	if not building_tabs.tab_changed.is_connected(_on_building_tab_changed):
		building_tabs.tab_changed.connect(_on_building_tab_changed)
	_refresh_building_buttons()


func _on_building_tab_changed(tab_index: int) -> void:
	selected_building_category = clampi(tab_index, 0, BuildingData.CATEGORY_NAMES.size() - 1)
	_refresh_building_buttons()


func _refresh_building_buttons() -> void:
	for child: Node in build_buttons.get_children():
		child.free()

	for building_data: BuildingData in menu_buildings:
		if building_data.category != selected_building_category: continue
		var button := Button.new()
		button.focus_mode = Control.FOCUS_NONE
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
	if building_data.road_kind > 0:
		road_requested.emit(building_data)
		return
	build_requested.emit(building_data)


func _get_building_tooltip(building_data: BuildingData) -> String:
	return building_data.display_name + "\n" + _get_building_tooltip_body(building_data)


func _get_building_tooltip_body(building_data: BuildingData) -> String:
	var lines: PackedStringArray = []
	if not building_data.description.is_empty():
		lines.append("介绍：" + building_data.description)

	var costs: PackedStringArray = []
	for resource_key: Variant in building_data.construction_cost.keys():
		var resource_id: StringName = ResourceStorage.resource_id_from_key(resource_key)
		var resource_name: String = str(resource_id)
		var resource_data: ResourceData = RESOURCE_DATABASE.get_resource_data(resource_id)
		if resource_data != null and not resource_data.display_name.is_empty():
			resource_name = resource_data.display_name
		costs.append("%s %s" % [resource_name, str(building_data.construction_cost[resource_key])])
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
	for resource_id: StringName in resource_labels:
		var amount: float = resource_manager.get_total(resource_id) if resource_manager != null else 0.0
		resource_labels[resource_id].text = str(int(amount))


# ============================================================
# 时间控制
# ============================================================

func pause_game() -> void:

	get_tree().paused = true
	if pause_button != null:
		pause_button.text = "继续"


func speed_1() -> void:

	Engine.time_scale = 1.0
	resume_game()


func speed_2() -> void:

	Engine.time_scale = 2.0
	resume_game()


func speed_3() -> void:

	Engine.time_scale = 3.0
	resume_game()


func resume_game() -> void:
	get_tree().paused = false
	if pause_button != null:
		pause_button.text = "暂停"
	var main_node: Node = get_tree().current_scene
	if main_node != null and main_node.has_method("flush_paused_game_commands"):
		main_node.flush_paused_game_commands()


# ============================================================
# Button Signals
# ============================================================

func _on_pause_button_pressed() -> void:
	if get_tree().paused:
		resume_game()
	else:
		pause_game()


func _on_speed_1_button_pressed() -> void:

	speed_1()


func _on_speed_2_button_pressed() -> void:

	speed_2()


func _on_speed_3_button_pressed() -> void:

	speed_3()


func show_blueprint_choices() -> void:
	var catalog := BuildingCatalog.for_tree(get_tree())
	if catalog == null: return
	if is_instance_valid(blueprint_window) and blueprint_window.visible: return
	var pool_id: StringName = &"standard"
	if blueprint_pool_picker != null and blueprint_pool_picker.selected >= 0:
		pool_id = blueprint_pool_picker.get_item_metadata(blueprint_pool_picker.selected)
	var choices := catalog.draw_blueprints(pool_id)
	if is_instance_valid(blueprint_window):
		blueprint_window.queue_free()
	blueprint_window = Window.new()
	blueprint_window.title = "建筑蓝图 · 三选一"
	blueprint_window.size = Vector2i(900, 320)
	blueprint_window.unresizable = true
	blueprint_window.exclusive = true
	blueprint_window.transient = true
	blueprint_window.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(blueprint_window)
	blueprint_was_paused = get_tree().paused
	get_tree().paused = true
	blueprint_window.close_requested.connect(_close_blueprint_choices)
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.add_theme_constant_override("separation", 18)
	blueprint_window.add_child(box)
	var title := Label.new()
	title.text = "选择一张蓝图，本局永久解锁，可重复建造／升级" if not choices.is_empty() else "此随机池暂无可抽蓝图：可能已全部获得，或前置蓝图尚未解锁。"
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(title)
	var cards := HBoxContainer.new()
	cards.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(cards)
	for data: BuildingData in choices:
		var button := Button.new()
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size = Vector2(260, 190)
		var parent: BuildingData = catalog.buildings.get(data.upgrade_from_id)
		button.text = "T%d %s\n\n%s\n\n%s" % [data.tier, data.display_name, "由%s升级" % parent.display_name if parent != null and not data.allow_direct_build else "解锁后直接建造", data.description]
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.pressed.connect(func() -> void:
			if catalog.choose_blueprint(data.id): _close_blueprint_choices()
		)
		cards.add_child(button)
	blueprint_window.popup_centered()


func _close_blueprint_choices() -> void:
	blueprint_window.hide()
	get_tree().paused = blueprint_was_paused
