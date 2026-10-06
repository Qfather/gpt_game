extends Node3D

class ResidentPortrait extends Control:
	func _draw() -> void:
		draw_style_box(_background(), Rect2(Vector2.ZERO, size))
		draw_rect(Rect2(7, 22, 18, 12), Color("a89362"))
		draw_rect(Rect2(8, 6, 16, 18), Color("e0bf87"))
		draw_rect(Rect2(6, 3, 20, 8), Color("44392f"))
		draw_rect(Rect2(11, 14, 2, 3), Color("302b27"))
		draw_rect(Rect2(20, 14, 2, 3), Color("302b27"))
	func _background() -> StyleBoxFlat:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("263039")
		style.set_corner_radius_all(5)
		return style

var building: BuildingBase
var panel: Control
var count_label: Label
var sleep_label: Label

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	building = get_parent()
	position.y = 3.8
	panel = Control.new()
	panel.name = "室内人员提示"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.size = Vector2(72, 46)
	var portrait := ResidentPortrait.new()
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait.size = Vector2(32, 36)
	panel.add_child(portrait)
	count_label = Label.new()
	count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	count_label.position = Vector2(23, 24)
	count_label.add_theme_font_size_override("font_size", 18)
	count_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	count_label.add_theme_constant_override("shadow_offset_x", 2)
	count_label.add_theme_constant_override("shadow_offset_y", 2)
	panel.add_child(count_label)
	sleep_label = Label.new()
	sleep_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sleep_label.text = "ZZZ"
	sleep_label.position = Vector2(34, 0)
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
	panel.position = camera.unproject_position(global_position) - Vector2(32, 46)
	count_label.text = "×%d" % residents.size()
	sleep_label.visible = false
	for resident: Node in residents:
		if resident.state == resident.State.RESTING:
			sleep_label.visible = true
			break

func _exit_tree() -> void:
	if is_instance_valid(panel): panel.queue_free()
