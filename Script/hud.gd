extends CanvasLayer


@onready var wood_label: Label = $PanelContainer/VBoxContainer/WoodLabel


func _ready():

	# 找到据点
	var bases = get_tree().get_nodes_in_group("bases")

	if not bases.is_empty():

		var base = bases[0]

		# 连接据点的木材变化信号
		base.wood_changed.connect(update_wood)

		# 初始化显示
		update_wood(base.wood)

	else:

		update_wood(0)

		print("HUD：没有找到 Base")


# ============================================================
# 更新木材
# ============================================================

func update_wood(amount: int):

	wood_label.text = "木材：" + str(amount)


# ============================================================
# 时间控制
# ============================================================

func pause_game():

	get_tree().paused = true


func speed_1():

	get_tree().paused = false

	Engine.time_scale = 1.0


func speed_2():

	get_tree().paused = false

	Engine.time_scale = 2.0


func speed_3():

	get_tree().paused = false

	Engine.time_scale = 3.0


# ============================================================
# Button Signals
# ============================================================

func _on_pause_button_pressed():

	pause_game()


func _on_speed_1_button_pressed():

	speed_1()


func _on_speed_2_button_pressed():

	speed_2()


func _on_speed_3_button_pressed():

	speed_3()
