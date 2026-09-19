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

	# 等待场景初始化完成
	await get_tree().physics_frame
	await get_tree().physics_frame

	# --------------------------------------------------------
	# 当前测试逻辑：
	# 游戏开始后自动寻找空闲居民并填充岗位
	# 以后有正式招募系统后可以删除这一段
	# --------------------------------------------------------

	var villagers: Array[Node] = get_tree().get_nodes_in_group(
		"villagers"
	)

	print("找到居民数量：", villagers.size())

	for villager: Node in villagers:

		print("发现居民：", villager.name)

		if not villager.has_method("is_idle"):
			print("❌ 这个居民没有 is_idle()")
			continue

		print(
			"是否空闲：",
			villager.is_idle()
		)

		if not villager.is_idle():
			continue

		if not has_free_slot():
			break

		print(
			"准备分配居民：",
			villager.name
		)

		add_worker(villager)

	print("========== LumberCamp 检查结束 ==========")

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
