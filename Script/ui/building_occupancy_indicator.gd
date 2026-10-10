extends Node3D

class ResidentPortrait extends Control:
	var role: StringName = &"resident"
	func _draw() -> void:
		draw_style_box(_background(), Rect2(Vector2.ZERO, size))
		draw_rect(Rect2(7, 22, 18, 12), Color("a89362"))
		draw_rect(Rect2(8, 6, 16, 18), Color("e0bf87"))
		draw_rect(Rect2(6, 3, 20, 8), Color("44392f"))
		draw_rect(Rect2(11, 14, 2, 3), Color("302b27"))
		draw_rect(Rect2(20, 14, 2, 3), Color("302b27"))
		match role:
			&"swordsman", &"militia":
				draw_rect(Rect2(6, 3, 20, 9), Color("91a5b7"))
				draw_rect(Rect2(7, 22, 18, 12), Color("657e98"))
				draw_line(Vector2(27, 30), Vector2(27, 13), Color("eef4ff"), 3)
				draw_line(Vector2(23, 27), Vector2(31, 27), Color("e3c779"), 2)
			&"archer", &"hunter":
				var clothing := Color("507d43") if role == &"archer" else Color("b97638")
				draw_rect(Rect2(6, 3, 20, 9), clothing)
				draw_rect(Rect2(7, 22, 18, 12), clothing)
				draw_arc(Vector2(24, 23), 8, -PI * 0.5, PI * 0.5, 12, Color("e3c779"), 2)
				draw_line(Vector2(24, 15), Vector2(24, 31), Color("e5e7e9"), 1)
	func _background() -> StyleBoxFlat:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("263039")
		style.set_corner_radius_all(5)
		return style

var building: BuildingBase
var panel: Control
var count_label: Label
var sleep_label: Label
const ROLE_NAMES: Dictionary = {&"resident": "居民", &"militia": "民兵", &"swordsman": "剑士", &"archer": "弓箭手", &"hunter": "猎人", &"fisher": "渔民"}
var role_cards: Dictionary = {}
var role_counts: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	building = get_parent()
	position.y = 3.8
	panel = Control.new()
	panel.name = "室内人员提示"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.size = Vector2(54, 76)
	for role: StringName in ROLE_NAMES:
		var card := Control.new()
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.size = Vector2(54, 58)
		panel.add_child(card)
		var portrait := ResidentPortrait.new()
		portrait.role = role
		portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		portrait.size = Vector2(32, 36)
		card.add_child(portrait)
		var count := Label.new()
		count.mouse_filter = Control.MOUSE_FILTER_IGNORE
		count.position = Vector2(23, 22)
		count.add_theme_font_size_override("font_size", 17)
		count.add_theme_color_override("font_shadow_color", Color.BLACK)
		count.add_theme_constant_override("shadow_offset_x", 2)
		count.add_theme_constant_override("shadow_offset_y", 2)
		card.add_child(count)
		var title := Label.new()
		title.mouse_filter = Control.MOUSE_FILTER_IGNORE
		title.text = ROLE_NAMES[role]
		title.position = Vector2(0, 37)
		title.add_theme_font_size_override("font_size", 13)
		title.add_theme_color_override("font_shadow_color", Color.BLACK)
		title.add_theme_constant_override("shadow_offset_x", 1)
		title.add_theme_constant_override("shadow_offset_y", 1)
		card.add_child(title)
		role_cards[role] = {"panel": card, "count_label": count, "training_bars": []}
	count_label = Label.new()
	count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	count_label.add_theme_font_size_override("font_size", 14)
	count_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	count_label.add_theme_constant_override("shadow_offset_x", 2)
	count_label.add_theme_constant_override("shadow_offset_y", 2)
	panel.add_child(count_label)
	sleep_label = Label.new()
	sleep_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sleep_label.text = "ZZZ"
	sleep_label.position = Vector2.ZERO
	sleep_label.add_theme_font_size_override("font_size", 18)
	sleep_label.add_theme_color_override("font_color", Color("b5dcff"))
	panel.add_child(sleep_label)
	var hud: Node = get_tree().current_scene.get_node_or_null("UI/HUD")
	(hud if hud != null else get_tree().root).add_child(panel)

func _process(_delta: float) -> void:
	var residents: Array[Node] = building.get_indoor_residents()
	var camera: Camera3D = get_viewport().get_camera_3d()
	panel.visible = not residents.is_empty() and camera != null and building.is_visible_in_tree() and not building.get_meta("fog_hidden", false)
	if not panel.visible: return
	panel.visible = not camera.is_position_behind(global_position)
	count_label.text = "×%d" % residents.size()
	sleep_label.visible = false
	role_counts.clear()
	var training_counts: Dictionary = {}
	for role: StringName in ROLE_NAMES:
		for bar: ProgressBar in role_cards[role].training_bars:
			bar.hide()
	for resident: Node in residents:
		var role: StringName = &"resident"
		match resident.get_combat_role():
			CombatRole.Type.MILITIA: role = &"militia"
			CombatRole.Type.SWORDSMAN: role = &"swordsman"
			CombatRole.Type.ARCHER: role = &"archer"
			_:
				if resident.is_hunter(): role = &"hunter"
				elif resident.job == resident.Job.FISHER: role = &"fisher"
		role_counts[role] = int(role_counts.get(role, 0)) + 1
		if resident.state == resident.State.RESTING:
			sleep_label.visible = true
		var processing: bool = resident.is_hunter() and resident.hunting.inside_processing and resident.workplace == building
		var fishing_processing: bool = resident.job == resident.Job.FISHER and resident.fishing.phase == 6 and resident.workplace == building
		if (resident.state == resident.State.TRAINING and resident.task_site == building) or processing or fishing_processing:
			var training_index: int = int(training_counts.get(role, 0))
			var bars: Array = role_cards[role].training_bars
			if training_index >= bars.size():
				var bar := ProgressBar.new()
				bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
				bar.min_value = 0.0
				bar.max_value = 1.0
				bar.step = 0.001
				bar.show_percentage = false
				bar.position = Vector2(0, 55 + training_index * 12)
				bar.size = Vector2(48, 8)
				var background := StyleBoxFlat.new()
				background.bg_color = Color("263039")
				background.set_corner_radius_all(3)
				var fill := StyleBoxFlat.new()
				fill.bg_color = Color("58c5e8")
				fill.set_corner_radius_all(3)
				bar.add_theme_stylebox_override("background", background)
				bar.add_theme_stylebox_override("fill", fill)
				role_cards[role].panel.add_child(bar)
				bars.append(bar)
			var bar: ProgressBar = bars[training_index]
			bar.value = resident.hunting.get_processing_progress() if processing else resident.get_training_progress()
			if fishing_processing: bar.value = clampf(1.0 - resident.fishing.timer / maxf(building.processing_time, 0.001), 0.0, 1.0)
			bar.show()
			training_counts[role] = training_index + 1
	var index: int = 0
	for role: StringName in ROLE_NAMES:
		var card: Control = role_cards[role].panel
		card.visible = role_counts.has(role)
		if not card.visible: continue
		card.position = Vector2(index * 54, 18)
		role_cards[role].count_label.text = "×%d" % role_counts[role]
		index += 1
	panel.size.x = index * 54
	var training_rows: int = 0
	for count: int in training_counts.values(): training_rows = maxi(training_rows, count)
	panel.size.y = 76 + training_rows * 12
	count_label.visible = index > 1
	count_label.position = Vector2(panel.size.x - 36, 0)
	panel.position = camera.unproject_position(global_position) - Vector2(panel.size.x * 0.5, panel.size.y)

func _exit_tree() -> void:
	if is_instance_valid(panel): panel.queue_free()
