class_name ResourceBuildingPanel
extends BuildingPanelBase


# ============================================================
# UI 节点
# ============================================================

@onready var storage_label: Label = %StorageLabel
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


	# --------------------------------------------------------
	# 库存
	# --------------------------------------------------------

	var resource_type: Variant = current_building.get("production_resource_type")
	var storage_amount: float
	var storage_capacity: float

	if resource_type != null and current_building.has_method("get_resource_amount"):
		storage_amount = current_building.get_resource_amount(resource_type)
		storage_capacity = current_building.get_resource_capacity(resource_type)
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
	if current_building == null:
		return

	refresh()
