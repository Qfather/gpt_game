class_name BuildingPanelBase
extends PanelContainer


# ============================================================
# 设置
# ============================================================

@export var animation_time: float = 0.25


# ============================================================
# 当前正在查看的建筑
# ============================================================

var current_building: Node = null

var opened_x: float
var closed_x: float

var move_tween: Tween = null


# ============================================================
# 节点
# ============================================================

@onready var building_name: Label = %BuildingName
@onready var close_button: Button = %CloseButton
@onready var building_health_label: Label = %HealthLabel
@onready var building_health_progress_bar: ProgressBar = %HealthProgressBar


# ============================================================
# 初始化
# ============================================================

func _ready():

	print("CloseButton = ", close_button)

	close_button.pressed.connect(_on_close_pressed)
	_configure_health_bar()

	await get_tree().process_frame

	# 获取当前屏幕尺寸
	var viewport_size = get_viewport_rect().size


	# ============================================================
	# 计算打开位置
	# ============================================================

	# 右侧完全贴住屏幕
	opened_x = viewport_size.x - size.x

	# 垂直居中
	position.y = (
		viewport_size.y - size.y
	) / 2.0


	# ============================================================
	# 计算关闭位置
	# ============================================================

	# 整个面板移动到屏幕右边
	closed_x = viewport_size.x


	# 游戏开始时藏在屏幕右侧
	position.x = closed_x

	hide()


# ============================================================
# 打开建筑面板
# ============================================================

func open_building(building: Node):
	print("📺 BuildingPanel收到打开请求：", building.name)
	if building == null:
		return

	current_building = building
	if current_building.has_signal("health_changed") and not current_building.health_changed.is_connected(_on_building_health_changed):
		current_building.health_changed.connect(_on_building_health_changed)
	_update_health_display()

	building_name.text = building.name

	refresh()

	# 必须先显示，否则看不到滑入动画
	show()

	# 如果之前的动画还没结束，停止它
	if move_tween != null:
		move_tween.kill()

	move_tween = create_tween()

	move_tween.set_trans(
		Tween.TRANS_QUAD
	)

	move_tween.set_ease(
		Tween.EASE_OUT
	)

	move_tween.tween_property(
		self,
		"position:x",
		opened_x,
		animation_time
	)


# ============================================================
# 刷新
# ============================================================

func refresh():

	pass


func _update_health_display() -> void:
	if current_building == null or not is_instance_valid(current_building):
		building_health_label.hide()
		building_health_progress_bar.hide()
		return
	if not current_building.has_method("get_health") or not current_building.has_method("get_max_health"):
		building_health_label.hide()
		building_health_progress_bar.hide()
		return
	var max_health: float = float(current_building.get_max_health())
	if max_health <= 0.0:
		building_health_label.hide()
		building_health_progress_bar.hide()
		return
	var current_health: float = clampf(float(current_building.get_health()), 0.0, max_health)
	building_health_label.text = "生命：%.0f / %.0f" % [current_health, max_health]
	building_health_progress_bar.value = current_health / max_health * 100.0
	building_health_label.show()
	building_health_progress_bar.show()


func _on_building_health_changed(_current_health: float, _max_health: float) -> void:
	_update_health_display()


func _configure_health_bar() -> void:
	building_health_label.reparent(building_health_progress_bar)
	building_health_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	building_health_label.z_index = 1
	var background: StyleBoxFlat = StyleBoxFlat.new()
	background.bg_color = Color(0.12, 0.12, 0.12, 0.95)
	background.corner_radius_top_left = 4
	background.corner_radius_top_right = 4
	background.corner_radius_bottom_left = 4
	background.corner_radius_bottom_right = 4
	building_health_progress_bar.add_theme_stylebox_override("background", background)

	var fill: StyleBoxFlat = StyleBoxFlat.new()
	fill.bg_color = Color(0.82, 0.08, 0.08, 1.0)
	fill.corner_radius_top_left = 4
	fill.corner_radius_top_right = 4
	fill.corner_radius_bottom_left = 4
	fill.corner_radius_bottom_right = 4
	building_health_progress_bar.add_theme_stylebox_override("fill", fill)
	building_health_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	building_health_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	building_health_label.mouse_filter = Control.MOUSE_FILTER_IGNORE


# ============================================================
# 关闭面板
# ============================================================

func close_panel():

	if move_tween != null:
		move_tween.kill()

	move_tween = create_tween()

	move_tween.set_trans(
		Tween.TRANS_QUAD
	)

	move_tween.set_ease(
		Tween.EASE_IN
	)

	move_tween.tween_property(
		self,
		"position:x",
		closed_x,
		animation_time
	)

	# 等滑出动画播放完
	await move_tween.finished

	hide()

	current_building = null
	building_health_label.hide()
	building_health_progress_bar.hide()


func close_panel_immediately() -> void:
	if move_tween != null:
		move_tween.kill()
	current_building = null
	building_health_label.hide()
	building_health_progress_bar.hide()
	position.x = closed_x
	hide()


# ============================================================
# 关闭按钮
# ============================================================

func _on_close_pressed():

	close_panel()
