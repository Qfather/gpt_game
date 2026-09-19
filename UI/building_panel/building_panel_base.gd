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


# ============================================================
# 初始化
# ============================================================

func _ready():

	print("CloseButton = ", close_button)

	close_button.pressed.connect(_on_close_pressed)

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


func close_panel_immediately() -> void:
	if move_tween != null:
		move_tween.kill()
	current_building = null
	position.x = closed_x
	hide()


# ============================================================
# 关闭按钮
# ============================================================

func _on_close_pressed():

	close_panel()
