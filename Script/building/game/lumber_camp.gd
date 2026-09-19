class_name LumberCamp
extends ResourceBuildingBase


# ============================================================
# 初始化
# ============================================================

func _ready() -> void:

	# 初始化 ResourceBuildingBase
	# 同时会继续初始化 BuildingBase 的点击功能
	super._ready()

	print("========== LumberCamp 启动 ==========")

# ============================================================
# 分配伐木工职业
# ============================================================

func assign_worker_job(worker: Node) -> void:

	worker.assign_job(
		worker.Job.LUMBERJACK,
		self
	)
# ============================================================
# 木材兼容接口
#
# 新系统正式使用：
# deposit_resource()
# take_resource()
# has_resource()
#
# 下面这些暂时保留，避免旧代码调用时报错。
# 等确认整个工程不再调用后可以删除。
# ============================================================

func deposit_wood(amount: float) -> float:

	return deposit_resource(
		ResourceType.Type.WOOD,
		amount
	)


func take_wood(amount: float) -> float:

	return take_resource(
		ResourceType.Type.WOOD,
		amount
	)


func has_stored_wood() -> bool:

	return has_resource(
		ResourceType.Type.WOOD
	)


# ============================================================
# 测试：移除第一个工人
# ============================================================

func test_remove_worker() -> void:

	if workers.is_empty():
		return

	var worker: Node = workers[0]

	remove_worker(worker)


# ============================================================
# 测试：添加第一个空闲居民
# ============================================================

func test_add_worker() -> void:

	var villagers: Array[Node] = get_tree().get_nodes_in_group(
		"villagers"
	)

	for villager: Node in villagers:

		if not villager.has_method("is_idle"):
			continue

		if not villager.is_idle():
			continue

		if not has_free_slot():
			return

		add_worker(villager)

		return


# ============================================================
# 临时测试输入
#
# Enter / Space：移除工人
# ↑：添加工人
#
# 正式 UI 完全接管以后可以删除。
# ============================================================

func _input(event: InputEvent) -> void:

	if event.is_action_pressed("ui_accept"):
		test_remove_worker()

	if event.is_action_pressed("ui_up"):
		test_add_worker()
