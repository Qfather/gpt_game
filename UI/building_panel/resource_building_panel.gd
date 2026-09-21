class_name ResourceBuildingPanel
extends BuildingPanelBase

const RESOURCE_DATABASE: ResourceDatabase = preload(
	"res://data/resources/resource_database.tres"
)

# ============================================================
# UI 节点
# ============================================================

@onready var storage_label: Label = %StorageLabel
@onready var material_label: Label = %MaterialLabel
@onready var worker_label: Label = %WorkerLabel
@onready var hire_button: Button = %HireButton
@onready var fire_button: Button = %FireButton
@onready var demolish_button: Button = %DemolishButton
@onready var patrol_button: Button = $Vbox/Content/PatrolButton
@onready var demolition_progress_bar: ProgressBar = %DemolitionProgressBar
# ============================================================
# 初始化
# ============================================================

func _ready():

	super._ready()

	print("HireButton = ", hire_button)
	print("FireButton = ", fire_button)

	hire_button.pressed.connect(_on_hire_pressed)
	fire_button.pressed.connect(_on_fire_pressed)
	demolish_button.pressed.connect(_on_demolish_pressed)
	patrol_button.pressed.connect(_on_patrol_pressed)

# ============================================================
# 刷新资源建筑信息
# ============================================================

func refresh():

	if current_building == null:
		return
	hire_button.disabled = false
	fire_button.disabled = false
	demolition_progress_bar.hide()
	var demolition_in_progress: bool = (
		current_building.has_method("is_demolition_in_progress")
		and current_building.is_demolition_in_progress()
	)
	var can_cancel_demolition: bool = (
		demolition_in_progress
		and current_building.has_method("can_cancel_demolition")
		and current_building.can_cancel_demolition()
	)
	var construction_cancellation_in_progress: bool = (
		current_building.has_method("is_construction_cancellation_in_progress")
		and current_building.is_construction_cancellation_in_progress()
	)
	var can_cancel_construction: bool = (
		current_building.has_method("can_cancel_construction")
		and current_building.can_cancel_construction()
	)
	patrol_button.visible = (
		current_building.has_method("get_garrison_capacity")
		and not demolition_in_progress
	)

	demolish_button.visible = (
		(
			current_building.has_method("can_be_demolished")
			and current_building.can_be_demolished()
		)
		or can_cancel_construction
		or construction_cancellation_in_progress
		or (
			current_building.has_method("is_demolition_in_progress")
			and current_building.is_demolition_in_progress()
		)
	)
	demolish_button.disabled = (
		(demolition_in_progress and not can_cancel_demolition)
		or construction_cancellation_in_progress
	)
	if construction_cancellation_in_progress:
		demolish_button.text = current_building.get_construction_cancellation_status_text()
	elif can_cancel_construction:
		demolish_button.text = "取消建造"
	elif (
		current_building.has_method("get_demolition_status_text")
		and demolition_in_progress
	):
		demolish_button.text = (
			"取消拆除"
			if can_cancel_demolition
			else current_building.get_demolition_status_text()
		)
	else:
		var refund_resources: Dictionary = {}
		if current_building.has_method("get_demolition_refund_resources"):
			refund_resources = current_building.get_demolition_refund_resources()
		demolish_button.text = "拆除（返还：%s）" % _format_resource_dictionary(
			refund_resources
		)

	if current_building.is_in_group("bases"):
		storage_label.show()
		material_label.hide()
		worker_label.hide()
		hire_button.hide()
		fire_button.hide()
		storage_label.text = "库存：\n木材：%d\n石材：%d\n谷物：%d\n食物：%d" % [
			int(current_building.get_resource(&"wood")),
			int(current_building.get_resource(&"stone")),
			int(current_building.get_resource(&"grain")),
			int(current_building.get_resource(&"food"))
		]
		return

	if construction_cancellation_in_progress:
		storage_label.hide()
		material_label.show()
		worker_label.show()
		hire_button.hide()
		fire_button.hide()
		demolition_progress_bar.show()
		if current_building.has_method("get_construction_cancellation_progress_ratio"):
			demolition_progress_bar.value = (
				current_building.get_construction_cancellation_progress_ratio() * 100.0
			)
		var cancellation_remaining: Dictionary = {}
		if current_building.has_method("get_cancellation_remaining_resources"):
			cancellation_remaining = (
				current_building.get_cancellation_remaining_resources()
			)
		material_label.text = "尚未搬运：%s" % _format_resource_dictionary(
			cancellation_remaining
		)
		material_label.text += "\n" + current_building.get_construction_cancellation_status_text()
		if current_building.has_method("get_cancellation_worker_count"):
			worker_label.text = "取消居民：%d / %d" % [
				int(current_building.get_cancellation_worker_count()),
				int(current_building.get_max_cancellation_workers())
			]
		else:
			worker_label.text = "取消建造中"
		return

	if (
		current_building.has_method("is_demolition_in_progress")
		and current_building.is_demolition_in_progress()
	):
		storage_label.hide()
		material_label.show()
		worker_label.show()
		hire_button.show()
		fire_button.show()
		demolition_progress_bar.show()
		if current_building.has_method("get_demolition_progress_ratio"):
			demolition_progress_bar.value = (
				current_building.get_demolition_progress_ratio() * 100.0
			)
		hire_button.text = "增加拆除人员"
		fire_button.text = "减少拆除人员"
		worker_label.text = "拆除人员：%d / %d" % [
			int(current_building.get_demolition_worker_count()),
			int(current_building.get_max_demolition_workers())
		]
		var remaining: Dictionary = (
			current_building.get_demolition_remaining_resources()
		)
		var remaining_text: String = _format_resource_dictionary(remaining)
		if remaining_text.is_empty():
			remaining_text = "拆除完成后生成"
		material_label.text = (
			"返还材料：%s\n尚未搬运：%s"
			% [
				_format_resource_dictionary(
					current_building.get_demolition_refund_resources()
				),
				remaining_text
			]
		)
		return

	worker_label.show()
	hire_button.show()
	fire_button.show()

	if current_building.has_method("get_construction_material_text"):
		storage_label.hide()
		material_label.show()
		demolition_progress_bar.show()
		if current_building.has_method("get_construction_progress_ratio"):
			demolition_progress_bar.value = (
				current_building.get_construction_progress_ratio() * 100.0
			)
		material_label.text = current_building.get_construction_material_text()
		if current_building.has_method("get_construction_progress_text"):
			material_label.text += "\n" + current_building.get_construction_progress_text()
		worker_label.text = (
			"施工居民："
			+ str(current_building.get_worker_count())
			+ " / "
			+ str(current_building.get_max_worker_count())
		)
		hire_button.text = "增加居民"
		fire_button.text = "取消居民"
		return

	if current_building.has_method("get_housing_capacity"):
		storage_label.show()
		material_label.hide()
		worker_label.hide()
		hire_button.hide()
		fire_button.hide()
		storage_label.text = "住户：0 / %d\n住房容量：+%d" % [
			int(current_building.get_housing_capacity()),
			int(current_building.get_housing_capacity())
		]
		return

	if current_building.has_method("get_garrison_capacity"):
		storage_label.show()
		storage_label.text = "军营"
		material_label.hide()
		worker_label.show()
		hire_button.hide()
		fire_button.hide()
		worker_label.text = "驻军：%d / %d" % [
			int(current_building.get_garrison_count()),
			int(current_building.get_garrison_capacity())
		]
		patrol_button.disabled = (
			current_building.has_method("can_start_patrol")
			and not current_building.can_start_patrol()
		)
		patrol_button.text = (
			"开始巡逻"
			if not patrol_button.disabled
			else "巡逻进行中"
		)
		return

	if current_building.has_method("get_training_slots"):
		storage_label.show()
		storage_label.text = "剑士营"
		material_label.hide()
		worker_label.show()
		hire_button.show()
		fire_button.hide()
		worker_label.text = "训练位：%d / %d" % [
			int(current_building.get_training_worker_count()),
			int(current_building.get_training_slots())
		]
		if current_building.has_method("get_training_slot_status_text"):
			worker_label.text += "\n" + current_building.get_training_slot_status_text()
		hire_button.text = "训练剑士"
		if current_building.has_method("get_training_cost"):
			hire_button.text += "（%s）" % _format_resource_dictionary(
				current_building.get_training_cost()
			)
		hire_button.disabled = (
			current_building.has_method("can_request_training")
			and not current_building.can_request_training()
		)
		return

	storage_label.show()
	material_label.hide()
	hire_button.text = "招募"
	fire_button.text = "解雇"


	# --------------------------------------------------------
	# 库存
	# --------------------------------------------------------

	var resource_id: Variant = current_building.get("production_resource_id")
	var storage_amount: float
	var storage_capacity: float

	if resource_id != null and current_building.has_method("get_resource_amount"):
		storage_amount = current_building.get_resource_amount(resource_id)
		storage_capacity = current_building.get_resource_capacity(resource_id)
	else:
		# 兼容尚未迁移到通用接口的资源建筑。
		storage_amount = float(current_building.get_storage_amount())
		storage_capacity = float(current_building.get_storage_capacity())

	storage_label.text = (
		"库存："
		+ str(int(storage_amount))
		+ " / "
		+ str(int(storage_capacity))
	)
	if current_building.has_method("get_field_status_text"):
		storage_label.text += "\n" + current_building.get_field_status_text()


	# --------------------------------------------------------
	# 工人数
	# --------------------------------------------------------

	var worker_count = current_building.get_worker_count()
	var max_worker_count = current_building.get_max_worker_count()

	worker_label.text = (
		"工人："
		+ str(worker_count)
		+ " / "
		+ str(max_worker_count)
	)


# ============================================================
# 招募
# ============================================================

func _on_hire_pressed():

	if current_building == null:
		return
	if _queue_building_panel_action("_on_hire_pressed"):
		return
	if current_building.has_method("request_training"):
		current_building.request_training()
		refresh()
		return
	if current_building.has_method("is_demolition_in_progress") and current_building.is_demolition_in_progress():
		current_building.request_additional_demolition_worker()
		refresh()
		return

	if current_building.has_method("request_additional_worker"):
		current_building.request_additional_worker()
		refresh()
		return

	# 岗位已经满了
	if not current_building.has_free_slot():
		print("❌ 当前建筑岗位已满")
		return


	# 找所有居民
	var villagers = get_tree().get_nodes_in_group("villagers")


	# 找第一个空闲居民
	for villager in villagers:

		if not villager.has_method("is_idle"):
			continue

		if not villager.is_idle():
			continue


		# 找到以后交给建筑处理
		if current_building.add_worker(villager):

			refresh()

			return


	print("❌ 当前没有空闲居民")


# ============================================================
# 解雇
# ============================================================

func _on_fire_pressed():

	if current_building == null:
		return
	if _queue_building_panel_action("_on_fire_pressed"):
		return
	if current_building.has_method("is_demolition_in_progress") and current_building.is_demolition_in_progress():
		current_building.cancel_one_demolition_worker()
		refresh()
		return

	if current_building.has_method("cancel_one_worker"):
		current_building.cancel_one_worker()
		refresh()
		return


	if current_building.workers.is_empty():
		print("❌ 当前建筑没有工人")
		return


	# 暂时解雇 workers 中第一个工人
	var worker = current_building.workers[0]


	if current_building.remove_worker(worker):

		refresh()


func _on_demolish_pressed() -> void:
	if current_building == null:
		return
	if _queue_building_panel_action("_on_demolish_pressed"):
		return
	if (
		current_building.has_method("is_construction_cancellation_in_progress")
		and current_building.is_construction_cancellation_in_progress()
	):
		return
	if (
		current_building.has_method("can_cancel_construction")
		and current_building.can_cancel_construction()
	):
		var cancelled: bool = current_building.cancel_construction()
		print("取消建造按钮结果：", cancelled)
		refresh()
		return
	if (
		current_building.has_method("is_demolition_in_progress")
		and current_building.is_demolition_in_progress()
	):
		var cancelled: bool = false
		if current_building.has_method("cancel_demolition"):
			cancelled = current_building.cancel_demolition()
		print("取消拆除按钮结果：", cancelled)
		refresh()
		return

	if not current_building.has_method("demolish"):
		return

	if not current_building.demolish():
		return
	refresh()


func _on_patrol_pressed() -> void:
	if current_building == null or not current_building.has_method("request_patrol"):
		return
	if _queue_building_panel_action("_on_patrol_pressed"):
		return
	if current_building.request_patrol():
		refresh()


func _queue_building_panel_action(method_name: String) -> bool:
	if not get_tree().paused:
		return false
	var main_node: Node = get_tree().current_scene
	if main_node == null or not main_node.has_method("execute_game_command"):
		return false
	var target: Node = current_building
	main_node.execute_game_command(
		Callable(self, "_execute_queued_building_panel_action").bind(
			method_name,
			target
		)
	)
	return true


func _execute_queued_building_panel_action(
	method_name: String,
	target: Node
) -> void:
	if not is_instance_valid(target):
		return
	var previous_building: Node = current_building
	current_building = target
	call(method_name)
	current_building = previous_building


func _format_resource_dictionary(resources: Dictionary) -> String:
	var parts: PackedStringArray = []
	for resource_key: Variant in resources.keys():
		var resource_id: StringName = ResourceStorage.resource_id_from_key(
			resource_key
		)
		var resource_name: String = str(resource_id)
		var resource_data: ResourceData = RESOURCE_DATABASE.get_resource_data(
			resource_id
		)
		if resource_data != null and not resource_data.display_name.is_empty():
			resource_name = resource_data.display_name
		var amount: float = float(resources[resource_key])
		var amount_text: String = (
			str(int(round(amount)))
			if is_equal_approx(amount, round(amount))
			else "%.1f" % amount
		)
		parts.append("%s %s" % [resource_name, amount_text])
	return "、".join(parts)
# ============================================================
# 面板打开期间实时刷新
# ============================================================

func _process(_delta):

	# 面板没打开，不需要刷新
	if not visible:
		return

	# 没有正在查看的建筑
	if current_building == null or not is_instance_valid(current_building):
		current_building = null
		hide()
		return

	refresh()
