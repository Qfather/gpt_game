class_name HealthBar3D
extends Node3D


@export var bar_color: Color = Color(0.25, 0.85, 0.25, 1.0)
@export var only_combat_units: bool = false
@export var bar_width: float = 0.9
@export var bar_height: float = 0.1

var screen_bar: Control
var background: ColorRect
var fill: ColorRect
var target: Node


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_priority = 100
	target = get_parent()
	_create_bar()
	if target != null and target.has_signal("health_changed"):
		target.connect("health_changed", _on_health_changed)
	if target != null and target.has_signal("visibility_changed"):
		target.connect("visibility_changed", _on_target_visibility_changed)
	_refresh()


func _exit_tree() -> void:
	if is_instance_valid(screen_bar):
		screen_bar.queue_free()


func _process(_delta: float) -> void:
	_refresh()


func refresh_display() -> void:
	_refresh()


func _create_bar() -> void:
	var pixel_size: Vector2 = Vector2(
		maxf(bar_width * 64.0, 8.0),
		maxf(bar_height * 64.0, 4.0)
	)
	screen_bar = Control.new()
	screen_bar.name = "%s_屏幕血条" % target.name
	screen_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen_bar.size = pixel_size
	screen_bar.z_index = 100
	get_tree().root.call_deferred("add_child", screen_bar)

	background = ColorRect.new()
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.color = Color(0.04, 0.04, 0.04, 0.9)
	background.size = pixel_size
	screen_bar.add_child(background)

	fill = ColorRect.new()
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fill.color = bar_color
	fill.position = Vector2.ONE
	fill.size = Vector2(pixel_size.x - 2.0, pixel_size.y - 2.0)
	screen_bar.add_child(fill)


func _on_health_changed(_current_health: float, _max_health: float) -> void:
	_refresh()


func _on_target_visibility_changed() -> void:
	_refresh()


func _refresh() -> void:
	if target == null or not is_instance_valid(screen_bar) or fill == null:
		return

	var max_health: float = _get_max_health()
	var current_health: float = _get_current_health()
	var ratio: float = 1.0
	if max_health > 0.0:
		ratio = clampf(current_health / max_health, 0.0, 1.0)

	var should_show: bool = ratio < 1.0
	if only_combat_units and not _is_combat_unit():
		should_show = false
	if target is Node3D and not (target as Node3D).is_visible_in_tree():
		should_show = false
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null or camera.is_position_behind(global_position):
		should_show = false

	screen_bar.visible = should_show
	if not should_show:
		return

	var inner_width: float = maxf(screen_bar.size.x - 2.0, 0.0)
	fill.size.x = inner_width * ratio
	var screen_position: Vector2 = camera.unproject_position(global_position)
	screen_bar.position = screen_position - screen_bar.size * 0.5


func _get_max_health() -> float:
	if target.has_method("get_max_health"):
		return float(target.get_max_health())
	return float(target.get("max_health"))


func _get_current_health() -> float:
	if target.has_method("get_health"):
		return float(target.get_health())
	return float(target.get("current_health"))


func _is_combat_unit() -> bool:
	if target == null or not target.has_method("get_combat_role"):
		return false
	return int(target.get_combat_role()) == 1
