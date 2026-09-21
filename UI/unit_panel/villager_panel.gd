class_name VillagerPanel
extends UnitPanelBase

const RESOURCE_DATABASE: ResourceDatabase = preload(
	"res://data/resources/resource_database.tres"
)
const JOB_DISPLAY_NAMES: PackedStringArray = ["无业", "伐木工", "矿工", "农夫"]
const STATE_DISPLAY_NAMES: PackedStringArray = [
	"待命",
	"需要进食",
	"前往吃饭",
	"正在吃饭",
	"需要休息",
	"前往休息",
	"正在休息",
	"返回待命",
	"寻找资源",
	"前往资源",
	"正在采集",
	"前往工作地点",
	"存入工作建筑",
	"返回据点",
	"存入据点",
	"前往训练",
	"正在训练",
	"前往军营",
	"已驻扎军营",
	"军营内吃饭",
	"军营内休息",
	"前往巡逻集合点",
	"等待巡逻队集合",
	"前往巡逻点",
	"巡逻中",
	"返回军营",
	"前往拆除",
	"正在拆除",
	"运送拆除材料",
	"在据点存入拆除材料",
	"寻找任务材料",
	"前往取货",
	"前往工地",
	"等待任务材料",
	"前往工地等待",
	"前往施工",
	"正在施工",
	"寻找田地",
	"前往田地",
	"正在处理田地"
]
const TASK_DISPLAY_NAMES: PackedStringArray = ["运输建造材料", "建筑施工", "训练剑士"]

@onready var health_label: Label = %HealthLabel
@onready var move_speed_label: Label = %MoveSpeedLabel
@onready var work_speed_label: Label = %WorkSpeedLabel
@onready var gather_speed_label: Label = %GatherSpeedLabel
@onready var job_label: Label = %JobLabel
@onready var combat_role_label: Label = %CombatRoleLabel
@onready var state_label: Label = %StateLabel
@onready var task_label: Label = %TaskLabel
@onready var workplace_label: Label = %WorkplaceLabel
@onready var carry_label: Label = %CarryLabel
@onready var hunger_bar: ProgressBar = %HungerBar
@onready var fatigue_bar: ProgressBar = %FatigueBar
@onready var remove_button: Button = %RemoveButton

@onready var trait_container: VBoxContainer = %TraitContainer


func _ready():

	super._ready()
	remove_button.pressed.connect(_on_remove_pressed)
	_configure_needs_bars()


func _on_remove_pressed() -> void:
	if current_unit == null or not is_instance_valid(current_unit):
		return
	var population_manager := get_tree().get_first_node_in_group(
		"population_manager"
	) as PopulationManager
	if population_manager == null:
		return
	if population_manager.remove_villager(current_unit):
		close_panel_immediately()


func refresh():

	if current_unit == null:
		return

	var villager: UnitBase = current_unit


	# ========================================================
	# 基础状态
	# ========================================================

	unit_name.text = "%s  #%d" % [villager.name, villager.get_instance_id()]
	health_label.text = (
		"生命："
		+ str(round(current_unit.get_health()))
		+ " / "
		+ str(round(current_unit.get_max_health()))
	)

	move_speed_label.text = (
		"移动速度："
		+ str(current_unit.get_move_speed())
	)

	work_speed_label.text = (
		"工作效率："
		+ str(current_unit.get_work_speed())
	)

	gather_speed_label.text = (
		"采集效率："
		+ str(current_unit.get_gather_speed())
	)


	# ========================================================
	# 职业
	# ========================================================

	var job_index: int = int(villager.get("job"))
	var combat_role_index: int = int(villager.get("combat_role"))
	var state_index: int = int(villager.get("state"))
	job_label.text = "职业：" + _get_display_name(JOB_DISPLAY_NAMES, job_index)
	combat_role_label.text = "军事职业：" + CombatRole.get_display_name(combat_role_index)
	state_label.text = "状态：" + _get_display_name(STATE_DISPLAY_NAMES, state_index)
	task_label.text = "当前任务：" + _get_task_text(villager)
	workplace_label.text = "工作地点：" + _get_node_name(villager.get("workplace") as Node)
	_update_needs_bar(hunger_bar, float(villager.call("get_hunger")))
	_update_needs_bar(fatigue_bar, float(villager.call("get_fatigue")))

	var carried_amount: float = float(villager.call("get_carried_amount"))
	if carried_amount <= 0.0:
		carry_label.text = "携带：无"
	else:
		var carried_resource_id: StringName = StringName(
			villager.call("get_carried_resource_id")
		)
		carry_label.text = "携带：%s %.1f / %.1f" % [
			_get_resource_display_name(carried_resource_id),
			carried_amount,
			float(villager.get("carry_capacity"))
		]


	# ========================================================
	# Trait
	# ========================================================

	_refresh_traits()


func _configure_needs_bars() -> void:
	for bar: ProgressBar in [hunger_bar, fatigue_bar]:
		bar.min_value = 0.0
		bar.max_value = 100.0
		bar.show_percentage = true
		bar.custom_minimum_size.y = 18.0
		_update_needs_bar(bar, 0.0)


func _update_needs_bar(bar: ProgressBar, value: float) -> void:
	bar.value = value
	var progress_style := StyleBoxFlat.new()
	progress_style.bg_color = _get_needs_color(value)
	progress_style.corner_radius_top_left = 4
	progress_style.corner_radius_top_right = 4
	progress_style.corner_radius_bottom_left = 4
	progress_style.corner_radius_bottom_right = 4
	bar.add_theme_stylebox_override("fill", progress_style)


func _get_needs_color(value: float) -> Color:
	if value >= 75.0:
		return Color(0.82, 0.20, 0.18)
	if value >= 50.0:
		return Color(0.92, 0.68, 0.16)
	return Color(0.25, 0.78, 0.32)


func _get_task_text(villager: UnitBase) -> String:
	var task: GameTask = villager.get("current_task") as GameTask
	if task == null:
		return "无"
	return _get_display_name(TASK_DISPLAY_NAMES, task.type)


func _get_display_name(names: PackedStringArray, index: int) -> String:
	if index < 0 or index >= names.size():
		return "未知"
	return names[index]


func _get_node_name(node: Node) -> String:
	return node.name if is_instance_valid(node) else "无"


func _get_resource_display_name(resource_id: StringName) -> String:
	var resource_data: ResourceData = RESOURCE_DATABASE.get_resource_data(resource_id)
	if resource_data == null or resource_data.display_name.is_empty():
		return str(resource_id)
	return resource_data.display_name


func _refresh_traits():

	for child in trait_container.get_children():
		child.queue_free()


	for unit_trait in current_unit.traits:

		if unit_trait == null:
			continue

		if unit_trait.trait_data == null:
			continue


		var trait_data = unit_trait.trait_data

		var label = Label.new()

		# 只有多个等级才显示 Lv.
		if trait_data.levels.size() > 1:

			label.text = (
				trait_data.trait_name
				+ " Lv."
				+ str(unit_trait.level)
			)

		else:

			label.text = trait_data.trait_name


		trait_container.add_child(label)


func _process(_delta):

	if not visible:
		return

	if current_unit == null:
		return

	refresh()
