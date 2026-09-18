extends Node3D
signal building_clicked(building)

# ============================================================
# 工作参数
# ============================================================

@export var max_workers: int = 3

@export var work_radius: float = 10.0

@export var idle_radius: float = 2.5

# ============================================================
# 当前工人
# ============================================================

var workers: Array[Node] = []


# ============================================================
# 本地库存
# ============================================================

# 伐木场最多临时储存多少木材
@export var storage_capacity: int = 20

# 当前储存的木材
var stored_wood: int = 0
# ============================================================
# 当前工人数
# ============================================================

func get_worker_count() -> int:

	return workers.size()


# ============================================================
# 是否还有空岗位
# ============================================================

func has_free_slot() -> bool:

	return workers.size() < max_workers


# ============================================================
# 添加工人
# ============================================================

func add_worker(worker: Node) -> bool:

	if not has_free_slot():

		print("🪵 伐木营地岗位已满")

		return false


	if worker in workers:

		print("这个村民已经在这个伐木营地工作")

		return false


	if not worker.has_method("assign_job"):

		print("❌ 这个节点不能成为工人")

		return false


	# 加入建筑工人列表
	workers.append(worker)


	# 告诉农民：
	# 你是伐木工，而且在我这里工作
	worker.assign_job(
		worker.Job.LUMBERJACK,
		self
	)


	print(
		"🪵 伐木营地增加工人：",
		worker.name,
		"  ",
		workers.size(),
		"/",
		max_workers
	)


	return true


# ============================================================
# 移除工人
# ============================================================

func remove_worker(worker: Node) -> bool:

	if worker not in workers:

		return false


	workers.erase(worker)


	if worker.has_method("quit_job"):
		worker.quit_job()


	

	return true
# ============================================================
# 判断位置是否处于工作范围
# ============================================================

func is_position_in_work_range(position: Vector3) -> bool:

	var distance = global_position.distance_to(position)

	return distance <= work_radius
# 开始运行一次
func _ready():
	$ClickArea.input_event.connect(_on_click_area_input_event)
	print("========== LumberCamp 启动 ==========")

	await get_tree().physics_frame
	await get_tree().physics_frame

	var villagers = get_tree().get_nodes_in_group("villagers")

	print("找到居民数量：", villagers.size())

	for villager in villagers:

		print("发现居民：", villager.name)

		if villager.has_method("is_idle"):

			print(
				"是否空闲：",
				villager.is_idle()
			)

			if villager.is_idle():
				if not has_free_slot():
					break
				
				if has_free_slot():

					print("准备分配居民：", villager.name)

					add_worker(villager)


		else:

			print("❌ 这个居民没有 is_idle()")

	print("========== LumberCamp 检查结束 ==========")
# ============================================================
# 本地库存
# ============================================================

# 还剩多少空间
func get_free_storage() -> int:
	return storage_capacity - stored_wood


# 库存是否已满
func is_storage_full() -> bool:
	return stored_wood >= storage_capacity


# 存入木材
# 返回实际成功存进去的数量
func deposit_wood(amount: int) -> int:

	var accepted = min(
		amount,
		get_free_storage()
	)

	stored_wood += accepted

	print(
		"🪵 伐木场收到木材：",
		accepted,
		"  当前库存：",
		stored_wood,
		"/",
		storage_capacity
	)

	return accepted
# ============================================================
# 从本地库存取出木材
# ============================================================

func take_wood(amount: int) -> int:

	if amount <= 0:
		return 0


	var taken = min(
		amount,
		stored_wood
	)


	stored_wood -= taken


	print(
		"📦 从伐木场取出木材：",
		taken,
		"  剩余库存：",
		stored_wood,
		"/",
		storage_capacity
	)


	return taken
# ============================================================
# 当前是否有木材可以运输
# ============================================================

func has_stored_wood() -> bool:

	return stored_wood > 0


#测试移除农民	
# ============================================================
# 测试移除农民
# ============================================================

func test_remove_worker():

	if workers.is_empty():
		return

	var worker = workers[0]



	# 正式辞退
	remove_worker(worker)



func test_add_worker():
	var villagers = get_tree().get_nodes_in_group("villagers")
	for villager in villagers:
		if villager.is_idle():
			if has_free_slot():
				add_worker(villager)
				return
		
func _input(event):

	if event.is_action_pressed("ui_accept"):
		test_remove_worker()

	if event.is_action_pressed("ui_up"):
		test_add_worker()
# ============================================================
# UI 通用接口
# ============================================================

# 当前库存
func get_storage_amount() -> int:
	return stored_wood


# 最大库存
func get_storage_capacity() -> int:
	return storage_capacity


# 最大工人数
func get_max_worker_count() -> int:
	return max_workers
# ============================================================
# 点击建筑
# ============================================================

func _on_click_area_input_event(
	camera: Node,
	event: InputEvent,
	event_position: Vector3,
	normal: Vector3,
	shape_idx: int
):

	if event is InputEventMouseButton:

		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:

			print("🏠 点击建筑：", name)

			building_clicked.emit(self)
