class_name ResourceBuildingPanel
extends BuildingPanelBase

signal move_requested(building: BuildingBase)

var move_button: Button
var upgrade_choices: VBoxContainer
var upgrade_choices_key: String = ""
var training_choices: VBoxContainer
var training_choices_key: String = ""
var upgrade_button: Button

var priority_row: HBoxContainer
var priority_value: Label

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
@onready var barracks_food_button: Button = $Vbox/Content/WorkerButtons/BarracksFoodButton
@onready var demolition_progress_bar: ProgressBar = %DemolitionProgressBar
# ============================================================
# 初始化
# ============================================================

func _ready():

	super._ready()

	print("HireButton = ", hire_button)
	print("FireButton = ", fire_button)
	barracks_food_button.mouse_filter = Control.MOUSE_FILTER_STOP
	barracks_food_button.focus_mode = Control.FOCUS_ALL
	barracks_food_button.z_index = 10

	hire_button.pressed.connect(_on_hire_pressed)
	fire_button.pressed.connect(_on_fire_pressed)
	demolish_button.pressed.connect(_on_demolish_pressed)
	move_button = Button.new()
	move_button.text = "移动"
	move_button.focus_mode = Control.FOCUS_NONE
	$Vbox.add_child(move_button)
	$Vbox.move_child(move_button, close_button.get_index())
	move_button.pressed.connect(_on_move_pressed)
	upgrade_button = Button.new()
	upgrade_button.focus_mode = Control.FOCUS_NONE
	$Vbox.add_child(upgrade_button)
	$Vbox.move_child(upgrade_button, close_button.get_index())
	upgrade_button.pressed.connect(_on_upgrade_pressed)
	upgrade_choices = VBoxContainer.new()
	$Vbox.add_child(upgrade_choices)
	$Vbox.move_child(upgrade_choices, close_button.get_index())
	training_choices = VBoxContainer.new()
	$Vbox/Content.add_child(training_choices)
	patrol_button.pressed.connect(_on_patrol_pressed)
	priority_row = HBoxContainer.new()
	priority_row.name = "ConstructionPriority"
	$Vbox/Content.add_child(priority_row)
	$Vbox/Content.move_child(priority_row, worker_label.get_index())
	var title := Label.new()
	title.text = "优先级"
	priority_row.add_child(title)
	priority_value = Label.new()
	priority_value.custom_minimum_size.x = 32
	priority_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	priority_row.add_child(priority_value)
	var buttons := VBoxContainer.new()
	priority_row.add_child(buttons)
	for step: int in [1, -1]:
		var button := Button.new()
		button.text = "▲" if step > 0 else "▼"
		button.pressed.connect(_change_construction_priority.bind(step))
		buttons.add_child(button)
	priority_row.hide()


func _change_construction_priority(step: int) -> void:
	if is_instance_valid(current_building) and current_building is ConstructionSite:
		current_building.set_construction_priority(current_building.construction_priority + step)
		refresh()


func _on_move_pressed() -> void:
	if is_instance_valid(current_building) and current_building.can_be_moved():
		move_requested.emit(current_building)


func _on_upgrade_pressed() -> void:
	for building: BuildingBase in _get_upgrade_selection():
		building.request_upgrade()
	refresh()


func _get_upgrade_selection() -> Array[BuildingBase]:
	var result: Array[BuildingBase] = []
	var main: Node = get_tree().current_scene
	if main != null and main.get("selected_objects") != null:
		for object: Variant in main.selected_objects:
			if is_instance_valid(object) and object is BuildingBase and object.can_upgrade(): result.append(object)
	elif is_instance_valid(current_building) and current_building.can_upgrade(): result.append(current_building)
	return result

# ============================================================
# 刷新资源建筑信息
# ============================================================

func refresh():

	if not is_instance_valid(current_building):
		close_panel_immediately()
		return
	move_button.visible = current_building is BuildingBase and current_building.can_be_moved()
	upgrade_button.visible = current_building is BuildingBase and current_building.get_upgrade_data() != null
	if upgrade_button.visible:
		var selection: Array[BuildingBase] = _get_upgrade_selection()
		var costs: Dictionary[StringName, float] = {}
		for building: BuildingBase in selection:
			for resource_id: StringName in building.get_upgrade_cost(): costs[resource_id] = costs.get(resource_id, 0.0) + building.get_upgrade_cost()[resource_id]
		upgrade_button.disabled = selection.is_empty()
		upgrade_button.text = "升级为%s（%d个 · %s）" % [current_building.get_upgrade_data().display_name, selection.size(), _format_resource_dictionary(costs)]
	_refresh_configured_actions()
	priority_row.visible = current_building is ConstructionSite and current_building.can_cancel_construction()
	if priority_row.visible:
		priority_value.text = str(current_building.construction_priority)
	_update_health_display()
	hire_button.disabled = false
	fire_button.disabled = false
	demolition_progress_bar.hide()
	if not current_building.has_method("get_garrison_capacity"):
		barracks_food_button.hide()
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
		storage_label.text = "库存：\n木材：%d\n石材：%d\n谷物：%d\n肉类：%d\n食物：%d" % [
			int(current_building.get_resource(&"wood")),
			int(current_building.get_resource(&"stone")),
			int(current_building.get_resource(&"grain")),
			int(current_building.get_resource(&"meat")),
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

	if current_building.has_method("get_lifetime_ratio"):
		storage_label.hide()
		material_label.show()
		worker_label.hide()
		hire_button.hide()
		fire_button.hide()
		demolition_progress_bar.show()
		demolition_progress_bar.value = current_building.get_lifetime_ratio() * 100.0
		material_label.text = "剩余时间：%d / %d 秒\n视野半径：%.1f 米" % [
			ceili(current_building.get_remaining_lifetime()),
			int(current_building.lifetime),
			current_building.get_sight_radius()
		]
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
		storage_label.text = "军营\n军粮：%d / %d" % [
			int(current_building.get_food_amount()),
			int(current_building.get_food_capacity())
		]
		if current_building.has_method("allows_garrison_attacks"):
			storage_label.text = "箭塔\n粮食：%d / %d\n视野：%.1f米\n射程倍率：%.1f" % [current_building.get_food_amount(), current_building.get_food_capacity(), current_building.get_sight_radius(), current_building.attack_range_multiplier]
			storage_label.text += "\n警戒：%.1f米（%s）" % [current_building.alarm_radius, "有人侦察" if current_building.is_staffed() else "无人暂停"]
		material_label.hide()
		worker_label.show()
		hire_button.hide()
		fire_button.hide()
		if not barracks_food_button.visible:
			barracks_food_button.show()
		barracks_food_button.disabled = false
		barracks_food_button.text = "军粮 +10"
		worker_label.text = "驻军：%d / %d" % [
			int(current_building.get_garrison_count()),
			int(current_building.get_garrison_capacity())
		]
		if current_building.has_method("allows_garrison_attacks"):
			worker_label.text += "\n塔上：%d人，补粮：%d人" % [current_building.garrisoned_units.size(), current_building.resupply_workers.size()]
			barracks_food_button.hide()
			patrol_button.hide()
			return
		patrol_button.show()
		patrol_button.disabled = (
			current_building.has_method("can_start_patrol")
			and not current_building.can_start_patrol()
		)
		if current_building.has_method("is_patrol_in_progress") and current_building.is_patrol_in_progress():
			patrol_button.text = "巡逻进行中"
		elif current_building.get_food_amount() < current_building.resupply_trigger:
			patrol_button.text = "等待军粮"
		elif patrol_button.disabled:
			patrol_button.text = "等待战备"
		else:
			patrol_button.text = "开始巡逻"
		return

	if current_building.has_method("get_training_slots"):
		storage_label.show()
		storage_label.text = current_building.building_data.display_name if current_building.building_data != null else "训练营"
		material_label.hide()
		worker_label.show()
		hire_button.visible = current_building.building_data == null or current_building.building_data.training_recipes.is_empty()
		fire_button.hide()
		worker_label.text = "训练位：%d / %d" % [
			int(current_building.get_training_worker_count()),
			int(current_building.get_training_slots())
		]
		if current_building.has_method("get_training_slot_status_text"):
			worker_label.text += "\n" + current_building.get_training_slot_status_text()
		hire_button.text = "训练" + current_building.get_training_name()
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
	elif current_building.has_method("get_storage_amount") and current_building.has_method("get_storage_capacity"):
		# 兼容尚未迁移到通用接口的资源建筑。
		storage_amount = float(current_building.get_storage_amount())
		storage_capacity = float(current_building.get_storage_capacity())
	else:
		storage_label.hide()
		material_label.hide()
		worker_label.hide()
		hire_button.hide()
		fire_button.hide()
		return

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
	if current_building.has_method("is_demolition_in_progress") and current_building.is_demolition_in_progress():
		current_building.cancel_one_demolition_worker()
		refresh()
		return

	if current_building.has_method("cancel_one_worker"):
		current_building.cancel_one_worker()
		refresh()
		return


	if current_building.get_worker_count() == 0:
		print("❌ 当前建筑没有工人")
		return


	# 暂时解雇 workers 中第一个工人
	var worker = current_building.workers[0]


	if current_building.remove_worker(worker):

		refresh()


func _on_demolish_pressed() -> void:
	if current_building == null:
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
	if current_building.request_patrol():
		refresh()


func _on_barracks_food_button_pressed() -> void:
	if current_building == null:
		return
	if current_building.has_method("debug_add_food"):
		var added_amount: float = current_building.debug_add_food(10.0)
		print("军营调试增加军粮：", added_amount)
		refresh()


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


func _refresh_configured_actions() -> void:
	var targets: Array[BuildingData] = current_building.get_upgrade_targets()
	upgrade_choices.visible = not targets.is_empty()
	if not targets.is_empty(): upgrade_button.hide()
	var key := str(current_building.get_instance_id())
	for target: BuildingData in targets: key += ":" + str(target.id)
	if upgrade_choices_key != key:
		upgrade_choices_key = key
		for child: Node in upgrade_choices.get_children(): child.free()
		for target: BuildingData in targets:
			var button := Button.new()
			button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			button.set_meta("target", target)
			button.pressed.connect(func() -> void:
				if is_instance_valid(current_building): current_building.request_upgrade(target.id)
				refresh()
			)
			upgrade_choices.add_child(button)
	var catalog := BuildingCatalog.for_tree(get_tree())
	for button: Button in upgrade_choices.get_children():
		var target: BuildingData = button.get_meta("target")
		var locked: bool = catalog == null or not catalog.is_unlocked(target)
		button.text = "升级为%s%s\n%s · %s秒" % [target.display_name, "（需要蓝图）" if locked else "", _format_resource_dictionary(target.upgrade_cost), target.upgrade_time]
		button.disabled = not current_building.can_upgrade(target.id)
	var data: BuildingData = current_building.building_data
	training_choices.visible = data != null and not data.training_recipes.is_empty() and not current_building is ConstructionSite and current_building.has_method("request_training") and not current_building.is_demolition_in_progress()
	if not training_choices.visible: return
	var recipe_key := str(current_building.get_instance_id()) + ":" + str(data.training_recipes.size())
	if training_choices_key != recipe_key:
		training_choices_key = recipe_key
		for child: Node in training_choices.get_children(): child.free()
		for index: int in range(data.training_recipes.size()):
			var button := Button.new()
			button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			button.set_meta("index", index)
			button.pressed.connect(func() -> void:
				if is_instance_valid(current_building): current_building.request_training(index)
				refresh()
			)
			training_choices.add_child(button)
	for button: Button in training_choices.get_children():
		var index: int = button.get_meta("index")
		var recipe: TrainingRecipe = data.training_recipes[index]
		button.text = "训练%s\n%s · %s秒" % [current_building.get_training_name(index), _format_resource_dictionary(recipe.cost), recipe.time_seconds]
		button.disabled = not current_building.can_request_training(index)
