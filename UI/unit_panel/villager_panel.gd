class_name VillagerPanel
extends UnitPanelBase

const RESOURCE_DATABASE: ResourceDatabase = preload(
	"res://data/resources/resource_database.tres"
)
const JOB_NAMES: PackedStringArray = ["NONE", "LUMBERJACK", "MINER"]
const STATE_NAMES: PackedStringArray = [
	"IDLE",
	"RETURN_TO_IDLE",
	"FIND_RESOURCE",
	"MOVE_TO_RESOURCE",
	"GATHER_RESOURCE",
	"MOVE_TO_WORKPLACE",
	"DEPOSIT_TO_WORKPLACE",
	"MOVE_TO_BASE",
	"DEPOSIT_TO_BASE",
	"FIND_TASK_SOURCE",
	"MOVE_TO_TASK_SOURCE",
	"MOVE_TO_TASK_SITE",
	"WAIT_TASK_RESOURCE",
	"WAIT_CONSTRUCTION_SITE",
	"MOVE_TO_BUILD_SITE",
	"BUILDING"
]

@onready var health_label: Label = %HealthLabel
@onready var move_speed_label: Label = %MoveSpeedLabel
@onready var food_label: Label = %FoodLabel
@onready var work_speed_label: Label = %WorkSpeedLabel
@onready var gather_speed_label: Label = %GatherSpeedLabel
@onready var job_label: Label = %JobLabel
@onready var state_label: Label = %StateLabel
@onready var task_label: Label = %TaskLabel
@onready var workplace_label: Label = %WorkplaceLabel
@onready var carry_label: Label = %CarryLabel

@onready var trait_container: VBoxContainer = %TraitContainer


func _ready():

	super._ready()


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

	food_label.text = (
		"食物消耗："
		+ str(current_unit.get_food_consumption())
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
	var state_index: int = int(villager.get("state"))
	job_label.text = "职业：" + JOB_NAMES[job_index]
	state_label.text = "状态：" + STATE_NAMES[state_index]
	task_label.text = "当前任务：" + _get_task_text(villager)
	workplace_label.text = "工作地点：" + _get_node_name(villager.get("workplace") as Node)

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


func _get_task_text(villager: UnitBase) -> String:
	var task: GameTask = villager.get("current_task") as GameTask
	if task == null:
		return "无"
	return GameTask.TaskType.keys()[task.type]


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
