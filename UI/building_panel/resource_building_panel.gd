class_name ResourceBuildingPanel
extends BuildingPanelBase


# ============================================================
# UI 节点
# ============================================================

@onready var storage_label: Label = %StorageLabel
@onready var material_label: Label = %MaterialLabel
@onready var worker_label: Label = %WorkerLabel
@onready var hire_button: Button = %HireButton
@onready var fire_button: Button = %FireButton
# ============================================================
# 初始化
# ============================================================

func _ready():

	super._ready()

	print("HireButton = ", hire_button)
	print("FireButton = ", fire_button)

	hire_button.pressed.connect(_on_hire_pressed)
	fire_button.pressed.connect(_on_fire_pressed)

# ============================================================
# 刷新资源建筑信息
# ============================================================

func refresh():

	if current_building == null:
		return

	if current_building.is_in_group("bases"):
		storage_label.show()
		material_label.hide()
		worker_label.hide()
		hire_button.hide()
		fire_button.hide()
		storage_label.text = "库存：\n木材：%d\n石材：%d\n食物：%d" % [
			int(current_building.get_resource(&"wood")),
			int(current_building.get_resource(&"stone")),
			int(current_building.get_resource(&"food"))
		]
		return

	worker_label.show()
	hire_button.show()
	fire_button.show()

	if current_building.has_method("get_construction_material_text"):
		storage_label.hide()
		material_label.show()
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
