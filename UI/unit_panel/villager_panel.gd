class_name VillagerPanel
extends UnitPanelBase


@onready var health_label: Label = %HealthLabel
@onready var move_speed_label: Label = %MoveSpeedLabel
@onready var food_label: Label = %FoodLabel
@onready var work_speed_label: Label = %WorkSpeedLabel
@onready var gather_speed_label: Label = %GatherSpeedLabel
@onready var job_label: Label = %JobLabel

@onready var trait_container: VBoxContainer = %TraitContainer


func _ready():

	super._ready()


func refresh():

	if current_unit == null:
		return


	# ========================================================
	# 基础状态
	# ========================================================

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

	if current_unit.has_method("get_job_display_name"):
		job_label.text = (
			"职业："
			+ current_unit.get_job_display_name()
		)
	else:
		job_label.text = "职业：居民"


	# ========================================================
	# Trait
	# ========================================================

	_refresh_traits()


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
