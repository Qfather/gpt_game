extends CanvasLayer


# ============================================================
# UI
# ============================================================

@onready var wood_label: Label = %WoodLabel
@onready var stone_label: Label = %StoneLabel


# ============================================================
# ResourceManager
# ============================================================

var resource_manager: ResourceManager = null


# ============================================================
# 初始化
# ============================================================

func _ready() -> void:

	await get_tree().process_frame

	resource_manager = get_tree().get_first_node_in_group(
		"resource_manager"
	) as ResourceManager

	if resource_manager == null:

		push_warning("HUD：没有找到 ResourceManager")

		update_resource_display()

		return

	update_resource_display()


# ============================================================
# 实时刷新资源
#
# 当前属于第一版验证方案。
# 后面再改成 Signal 驱动。
# ============================================================

func _process(_delta: float) -> void:

	update_resource_display()


# ============================================================
# 更新资源显示
# ============================================================

func update_resource_display() -> void:

	if resource_manager == null:

		wood_label.text = "木材：0"
		stone_label.text = "石头：0"

		return


	var wood_amount: float = resource_manager.get_total(
		ResourceType.Type.WOOD
	)

	var stone_amount: float = resource_manager.get_total(
		ResourceType.Type.STONE
	)


	wood_label.text = (
		"木材："
		+ str(int(wood_amount))
	)

	stone_label.text = (
		"石头："
		+ str(int(stone_amount))
	)


# ============================================================
# 时间控制
# ============================================================

func pause_game() -> void:

	get_tree().paused = true


func speed_1() -> void:

	get_tree().paused = false
	Engine.time_scale = 1.0


func speed_2() -> void:

	get_tree().paused = false
	Engine.time_scale = 2.0


func speed_3() -> void:

	get_tree().paused = false
	Engine.time_scale = 3.0


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
