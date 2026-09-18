class_name UnitPanelBase
extends PanelContainer


# ============================================================
# 设置
# ============================================================

@export var animation_time: float = 0.25


# ============================================================
# 当前查看单位
# ============================================================

var current_unit: UnitBase = null

var opened_x: float
var closed_x: float

var move_tween: Tween = null


# ============================================================
# 节点
# ============================================================

@onready var unit_name: Label = %UnitName
@onready var close_button: Button = %CloseButton


# ============================================================
# 初始化
# ============================================================

func _ready():

	close_button.pressed.connect(_on_close_pressed)

	await get_tree().process_frame

	var viewport_size = get_viewport_rect().size

	opened_x = viewport_size.x - size.x

	position.y = (
		viewport_size.y - size.y
	) / 2.0

	closed_x = viewport_size.x

	position.x = closed_x

	hide()


# ============================================================
# 打开单位面板
# ============================================================

func open_unit(unit: UnitBase):

	if unit == null:
		return

	current_unit = unit

	unit_name.text = unit.name

	refresh()

	show()

	if move_tween != null:
		move_tween.kill()

	move_tween = create_tween()

	move_tween.set_trans(Tween.TRANS_QUAD)
	move_tween.set_ease(Tween.EASE_OUT)

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
# 关闭
# ============================================================

func close_panel():

	if move_tween != null:
		move_tween.kill()

	move_tween = create_tween()

	move_tween.set_trans(Tween.TRANS_QUAD)
	move_tween.set_ease(Tween.EASE_IN)

	move_tween.tween_property(
		self,
		"position:x",
		closed_x,
		animation_time
	)

	await move_tween.finished

	hide()

	current_unit = null


func _on_close_pressed():

	close_panel()
