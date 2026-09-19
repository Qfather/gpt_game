extends CanvasLayer


# ============================================================
# UI
# ============================================================

@onready var wood_label: Label = (
	$PanelContainer/VBoxContainer/WoodLabel
)


# ============================================================
# 当前据点
# ============================================================

var current_base: Node = null


# ============================================================
# 初始化
# ============================================================

func _ready():

	# Base 与 HUD 是同级节点，HUD 可能先于 Base 完成 _ready。
	# 等一帧，确保 Base 的 ResourceStorage 已经初始化。
	await get_tree().process_frame

	# 找到据点
	var bases: Array[Node] = get_tree().get_nodes_in_group("bases")

	if bases.is_empty():

		update_wood(0.0)

		print("HUD：没有找到 Base")

		return


	current_base = bases[0]


	# ========================================================
	# 连接新的通用资源变化信号
	# ========================================================

	current_base.resource_changed.connect(
		_on_resource_changed
	)


	# ========================================================
	# 初始化木材显示
	# ========================================================

	var wood_amount: float = current_base.get_resource(
		ResourceType.Type.WOOD
	)

	update_wood(wood_amount)


# ============================================================
# 资源变化
# ============================================================

func _on_resource_changed(
	resource_type: ResourceType.Type,
	new_amount: float
):

	match resource_type:

		ResourceType.Type.WOOD:

			update_wood(new_amount)


# ============================================================
# 更新木材
# ============================================================

func update_wood(amount: float):

	wood_label.text = (
		"木材："
		+ str(int(amount))
	)


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
