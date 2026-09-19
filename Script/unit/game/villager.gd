extends UnitBase

# ============================================================
# 参数
# ============================================================

# 每次采集多少资源
@export var chop_amount: int = 1

# 每隔多少秒砍一次
@export var chop_interval: float = 1.0

# 最多携带多少资源
@export var carry_capacity: float = 5.0
#当前是否正在退出工作
var is_quitting_job: bool = false
#正在清仓
var is_clearing_workplace_storage: bool = false
# ============================================================
# 节点
# ============================================================

@onready var navigation_agent: NavigationAgent3D = $NavigationAgent3D


# ============================================================
# 状态
# ============================================================

enum State {
	IDLE,
	RETURN_TO_IDLE,

	FIND_RESOURCE,#寻找当前职业需要的资源
	MOVE_TO_RESOURCE,#前往目标资源
	GATHER_RESOURCE,#采集目标资源

	MOVE_TO_WORKPLACE,
	DEPOSIT_TO_WORKPLACE,
	
	MOVE_TO_BASE,
	DEPOSIT_TO_BASE,

	FIND_TASK_SOURCE,
	MOVE_TO_TASK_SOURCE,
	MOVE_TO_TASK_SITE
}

var state: State = State.IDLE

enum Job {
	NONE,
	LUMBERJACK,
	MINER
}

func get_job_resource_type() -> Variant:

	if workplace is ResourceBuildingBase:

		return workplace.production_resource_type

	return null
var job: Job = Job.NONE
# 当前工作建筑
var workplace: Node3D = null
# 当前是否正在执行工作建筑 → Base 的运输任务
var is_transporting: bool = false

# 当前公共任务
var current_task: Object = null
var task_source: ResourceStorage = null
var task_site: Node3D = null

# 当前目标树
var target_resource: ResourceBase = null

# 据点
var target_base: Node3D = null

# 当前携带的资源类型和数量
signal carried_resource_changed

var carried_resource_type: ResourceType.Type = ResourceType.Type.WOOD
var carried_amount: float = 0.0

# 旧字段仅保留给外部兼容，不参与正式运输流程。
var carried_wood: int:
	get:
		return int(carried_amount) if carried_resource_type == ResourceType.Type.WOOD else 0
	set(value):
		carried_resource_type = ResourceType.Type.WOOD
		carried_amount = float(value)
		carried_resource_changed.emit()

# 砍树计时
var chop_timer: float = 0.0


# ============================================================
# 初始化
# ============================================================

func _ready():
	super._ready()
	call_deferred("start")
	


func start():

	# 等待 NavigationServer 完成第一次同步
	await get_tree().physics_frame

	while NavigationServer3D.map_get_iteration_id(
		navigation_agent.get_navigation_map()
	) == 0:
		await get_tree().physics_frame


	find_base()

	# 如果仍然无业，才进入 Base 待命
	if job == Job.NONE:
		return_to_idle()
# ============================================================
# 主循环
# ============================================================

func _physics_process(delta):

	if state == State.IDLE and current_task != null:
		_start_current_task()

	match state:

		State.IDLE:
			velocity = Vector3.ZERO

		State.RETURN_TO_IDLE:
			move_to_idle_area()

		State.FIND_RESOURCE:
			find_nearest_resource()

		State.MOVE_TO_RESOURCE:
			move_to_resource()

		State.GATHER_RESOURCE:
			gather_resource(delta)

		State.MOVE_TO_WORKPLACE:
			move_to_workplace()

		State.DEPOSIT_TO_WORKPLACE:
			deposit_to_workplace()

		State.MOVE_TO_BASE:
			move_to_base()

		State.DEPOSIT_TO_BASE:
			deposit_to_base()

		State.FIND_TASK_SOURCE:
			find_task_source()

		State.MOVE_TO_TASK_SOURCE:
			move_to_task_source()

		State.MOVE_TO_TASK_SITE:
			move_to_task_site()


func _start_current_task() -> void:

	var task: GameTask = current_task as GameTask
	if task == null or task.type != GameTask.TaskType.DELIVER_CONSTRUCTION_RESOURCE:
		return

	task.state = GameTask.State.IN_PROGRESS
	task_site = task.target as Node3D
	if task_site == null:
		_release_current_task()
		return

	state = State.FIND_TASK_SOURCE
	print("Villager 开始搬运任务：", task.id, " target=", task_site.name)


func find_task_source() -> void:

	var task: GameTask = current_task as GameTask
	if task == null:
		state = State.IDLE
		return

	var resource_type: int = int(task.data.get("resource_type", -1))
	var nearest: ResourceStorage = null
	var nearest_distance: float = INF

	for storage_node: Node in get_tree().get_nodes_in_group("resource_storages"):
		var storage: ResourceStorage = storage_node as ResourceStorage
		if storage == null or storage.get_amount(resource_type) <= 0.0:
			continue

		var storage_parent: Node3D = storage.get_parent() as Node3D
		if storage_parent == null:
			continue

		var distance: float = global_position.distance_to(storage_parent.global_position)
		if distance < nearest_distance:
			nearest = storage
			nearest_distance = distance

	if nearest == null:
		_release_current_task()
		return

	task_source = nearest
	var source_parent: Node3D = task_source.get_parent() as Node3D
	if source_parent == null:
		_release_current_task()
		return

	navigation_agent.target_position = source_parent.global_position
	state = State.MOVE_TO_TASK_SOURCE


func move_to_task_source() -> void:

	if not is_instance_valid(task_source):
		_release_current_task()
		return

	if not navigation_agent.is_navigation_finished():
		move_along_navigation()
		return

	var task: GameTask = current_task as GameTask
	if task == null or task_site == null:
		_release_current_task()
		return

	var resource_type: int = int(task.data.get("resource_type", -1))
	var requested_amount: float = float(task.data.get("amount", 0.0))
	var taken_amount: float = task_source.take(resource_type, minf(requested_amount, carry_capacity))
	if taken_amount <= 0.0:
		_release_current_task()
		return

	carried_resource_type = resource_type
	carried_amount += taken_amount
	carried_resource_changed.emit()
	print("Villager 取出资源：", resource_type, " amount=", taken_amount)

	navigation_agent.target_position = task_site.global_position
	state = State.MOVE_TO_TASK_SITE


func move_to_task_site() -> void:

	if not is_instance_valid(task_site):
		_release_current_task()
		return

	if not navigation_agent.is_navigation_finished():
		move_along_navigation()
		return

	var task: GameTask = current_task as GameTask
	if task == null:
		state = State.IDLE
		return

	var delivered_amount: float = task_site.receive_delivery(
		carried_resource_type,
		carried_amount
	)
	carried_amount -= delivered_amount
	if delivered_amount > 0.0:
		carried_resource_changed.emit()

	var managers: Array[Node] = get_tree().get_nodes_in_group("task_manager")
	if not managers.is_empty() and managers[0].has_method("complete_task"):
		managers[0].complete_task(task)
	else:
		clear_current_task()

	task_source = null
	task_site = null
	state = State.IDLE
	print("Villager 完成搬运任务：", task.id, " delivered=", delivered_amount)


func _release_current_task() -> void:

	var task: GameTask = current_task as GameTask
	var managers: Array[Node] = get_tree().get_nodes_in_group("task_manager")
	if task != null and not managers.is_empty() and managers[0].has_method("release_task"):
		managers[0].release_task(task)
	else:
		clear_current_task()

	task_source = null
	task_site = null
	state = State.IDLE

# ============================================================
# 找据点
# ============================================================

func find_base():

	var bases = get_tree().get_nodes_in_group("bases")

	if bases.is_empty():
		print("❌ 没有找到据点，请检查 bases 分组")
		return

	target_base = bases[0]

	print("🏠 找到据点：", target_base.name)




# ============================================================
# 在工作建筑范围内寻找最近的树
# ============================================================

func find_nearest_resource():

	# --------------------------------------------------------
	# 获取当前职业需要的资源类型
	# --------------------------------------------------------

	var wanted_type: Variant = get_job_resource_type()

	if wanted_type == null:

		return_to_idle()
		return


	# --------------------------------------------------------
	# 必须有工作建筑
	# --------------------------------------------------------

	if workplace == null:

		print("❌ 当前职业没有工作建筑")

		job = Job.NONE

		return_to_idle()

		return


	# ============================================================
	# 工作建筑满仓时，生产让位给运输
	# ============================================================

	if workplace.has_method("is_storage_full"):

		if workplace.is_storage_full():
			# 满仓以后进入“清仓模式”
			is_clearing_workplace_storage = true
			print("📦 工作建筑已满，优先处理运输")

			if try_transport_workplace_resource(wanted_type):
				return


	# --------------------------------------------------------
	# 获取地图上的所有资源
	# --------------------------------------------------------

	var resources = get_tree().get_nodes_in_group("resources")

	var nearest_resource: ResourceBase = null

	var nearest_distance: float = INF


	# --------------------------------------------------------
	# 筛选当前职业需要的资源
	# --------------------------------------------------------

	for resource in resources:

		# 必须是 ResourceBase
		if not resource is ResourceBase:
			continue


		# ----------------------------------------------------
		# 必须是当前职业需要的资源类型
		# ----------------------------------------------------

		if resource.resource_type != wanted_type:
			continue


		# ----------------------------------------------------
		# 必须在工作建筑范围
		# ----------------------------------------------------

		if not workplace.is_position_in_work_range(
			resource.global_position
		):
			continue


		# ----------------------------------------------------
		# 已经被其他居民预约
		# ----------------------------------------------------

		if resource.is_reserved() and resource.reserved_by != self:
			continue


		# ----------------------------------------------------
		# 计算距离
		# ----------------------------------------------------

		var distance = global_position.distance_to(
			resource.global_position
		)


		# ----------------------------------------------------
		# 保存目前最近的资源
		# ----------------------------------------------------

		if distance < nearest_distance:

			nearest_distance = distance
			nearest_resource = resource




	# ============================================================
	# @feature 工作范围内没有树时处理剩余工作
	# ============================================================
	if nearest_resource == null:

		print(
			"🌳 ",
			workplace.name,
			" 工作范围内已经没有树"
		)


		# --------------------------------------------------------
		# 1. 身上还有采集到的木材
		# 先送回自己的工作建筑
		# --------------------------------------------------------

		if carried_amount > 0.0:


			go_to_workplace()

			return


		# --------------------------------------------------------
		# 2. 身上没木材
		# 看工作建筑还有没有库存需要运输
		# --------------------------------------------------------

		if try_transport_workplace_resource(wanted_type):

			print("📦 没有生产任务，改为运输库存")

			return


		# --------------------------------------------------------
		# 3. 没树、身上没木材、工作建筑也没库存
		# 回自己的工作地点待命
		# --------------------------------------------------------

		print(
			"💤 ",
			workplace.name,
			" 当前没有生产任务和运输任务"
		)

		return_to_idle()

		return
	# ============================================================
	# 就写在这里：正式预定最终选中的树
	# ============================================================

	if nearest_resource.has_method("reserve"):

		if not nearest_resource.reserve(self):
			state = State.FIND_RESOURCE
			return
	
	
	# --------------------------------------------------------
	# 找到了
	# --------------------------------------------------------

	target_resource = nearest_resource

	print(
		"🌳 ",
		workplace.name,
		" 范围内找到：",
		target_resource.name
	)

	navigation_agent.target_position = (
		target_resource.global_position
	)

	state = State.MOVE_TO_RESOURCE
# ============================================================
# 移动到树
# ============================================================

func move_to_resource():

	# 树已经不存在
	if not is_instance_valid(target_resource):

		target_resource = null
		state = State.FIND_RESOURCE

		return


	# 已经到达树旁边
	if navigation_agent.is_navigation_finished():

		velocity = Vector3.ZERO

		chop_timer = 0.0

		print("🪓 开始砍：", target_resource.name)

		state = State.GATHER_RESOURCE

		return


	move_along_navigation()


# ============================================================
# 砍树
# ============================================================

# ============================================================
# 砍树
# ============================================================

func gather_resource(delta):

	velocity = Vector3.ZERO


	# ========================================================
	# 目标树已经不存在
	# ========================================================

	if not is_instance_valid(target_resource):

		target_resource = null

		# 背包满了
		if carried_amount >= carry_capacity:

			print("🎒 背包已满，返回伐木场")

			go_to_workplace()

		# 背包没满
		else:

			print(
				"🌳 目标树已经不存在，背包未满，继续寻找树"
			)

			state = State.FIND_RESOURCE

		return


	# ========================================================
	# 砍树计时
	# ========================================================

	chop_timer += delta

	if chop_timer < chop_interval:
		return

	chop_timer = 0.0


	# ========================================================
	# 从树获得木材
	# ========================================================

	if target_resource.has_method("gather"):

		var free_space: float = carry_capacity - carried_amount

		var amount_to_gather: int = mini(
			chop_amount,
			int(free_space)
		)

		var gathered_amount = target_resource.gather(
			amount_to_gather
		)

		var gather_type: Variant = get_job_resource_type()
		if gather_type != null:
			carried_resource_type = gather_type
		carried_amount += float(gathered_amount)
		if gathered_amount > 0:
			carried_resource_changed.emit()


	# ========================================================
	# 背包满
	# ========================================================

	if carried_amount >= carry_capacity:

		print("🎒 背包已满，返回伐木场")

		# 离开当前树之前先解除预定
		if is_instance_valid(target_resource):

			if target_resource.has_method("release"):
				target_resource.release(self)

		target_resource = null

		go_to_workplace()

		return


	# ========================================================
	# 当前树已经被砍光
	# ========================================================

	if is_instance_valid(target_resource):

		if target_resource.is_queued_for_deletion():

			print(
				"🌳 ",
				target_resource.name,
				" 已经砍完"
			)

			# 先解除预定
			if target_resource.has_method("release"):
				target_resource.release(self)

			# 再清空目标
			target_resource = null

			# ------------------------------------------------
			# 背包没满 → 继续寻找下一棵树
			# ------------------------------------------------

			print(
				"🌳 树砍完了，但背包未满：",
				carried_amount,
				"/",
				carry_capacity,
				"，继续寻找下一棵树"
			)

			state = State.FIND_RESOURCE

			return
# ============================================================
# 返回据点
# ============================================================

func go_to_base():

	if target_base == null:
		find_base()


	if target_base == null:

		print("❌ 无法返回：没有据点")

		state = State.IDLE

		return


	navigation_agent.target_position = (
		target_base.global_position
	)


	state = State.MOVE_TO_BASE

# ============================================================
# 移动到据点
# ============================================================

func move_to_base():

	if target_base == null:

		print("❌ 据点不存在")

		state = State.IDLE

		return


	# 已经到达据点
	if navigation_agent.is_navigation_finished():

		velocity = Vector3.ZERO

		state = State.DEPOSIT_TO_BASE

		return


	# 继续沿导航移动
	move_along_navigation()

# ============================================================
# 存入 Base
# ============================================================
func deposit_to_base():

	if carried_amount <= 0.0:
		start_current_job()
		return


	# ========================================================
	# 向据点卸货
	# ========================================================

	if target_base != null:

		if target_base.has_method("add_resource"):

			var stored_amount: float = target_base.add_resource(
				carried_resource_type,
				carried_amount
			)

			carried_amount -= stored_amount
			if stored_amount > 0.0:
				carried_resource_changed.emit()


	print(
		"📦 向据点卸货完成，剩余携带：",
		carried_amount,
		" | 资源类型：",
		carried_resource_type
	)

	# Base 满仓时只扣除实际存入的数量，剩余资源继续保留。
	if carried_amount > 0.0:
		print("⚠️ Base 已满，居民仍携带：", carried_amount)
		return


	# ========================================================
	# 离职处理优先
	# ========================================================

	if is_quitting_job:

		is_transporting = false

		finish_quit_job()

		return


	# ========================================================
	# 正在执行“清空工作建筑库存”
	# ========================================================

	if is_clearing_workplace_storage:

		# 工作建筑还有库存
		if workplace != null:

			if workplace.has_method("has_resource"):

				if workplace.has_resource(carried_resource_type):

					print("📦 仓库还有库存，继续回去搬运")

					is_transporting = true

					go_to_workplace()

					return


		# ====================================================
		# 仓库已经彻底搬空
		# ====================================================

		print("✅ 工作建筑库存已经清空，恢复生产")

		is_clearing_workplace_storage = false
		is_transporting = false

		state = State.FIND_RESOURCE

		return


	# ========================================================
	# 普通运输完成
	# ========================================================

	is_transporting = false


	# ========================================================
	# 资源工人继续下一轮工作
	# ========================================================

	if workplace is ResourceBuildingBase:

		state = State.FIND_RESOURCE

		return


	# ========================================================
	# 无职业居民恢复空闲
	# ========================================================

	if job == Job.NONE:

		return_to_idle()

		return
# ============================================================
# 通用导航移动
# ============================================================

func move_along_navigation():

	if navigation_agent.is_navigation_finished():

		velocity = Vector3.ZERO

		return


	var next_position = (
		navigation_agent.get_next_path_position()
	)


	var direction = (
		next_position - global_position
	)


	# 只允许水平移动
	direction.y = 0.0


	if direction.length() > 0.01:

		direction = direction.normalized()

		velocity.x = direction.x * get_move_speed()
		velocity.z = direction.z * get_move_speed()

	else:

		velocity.x = 0.0
		velocity.z = 0.0


	move_and_slide()
# ============================================================
# 分配工作
# ============================================================

func assign_job(
	new_job: Job,
	new_workplace: Node3D = null
) -> void:

	job = new_job
	workplace = new_workplace


	# ========================================================
	# 失去工作
	# ========================================================

	if job == Job.NONE:

		print("👨 村民失去工作")

		# 如果当前预约了资源，解除预约
		if is_instance_valid(target_resource):

			if target_resource.has_method("release"):
				target_resource.release(self)

		workplace = null
		target_resource = null

		return_to_idle()

		return


	# ========================================================
	# 工作地点检查
	# ========================================================

	if workplace == null:

		print("❌ 村民获得职业，但没有工作建筑")

		job = Job.NONE
		target_resource = null

		return_to_idle()

		return


	# ========================================================
	# 资源采集职业
	# ========================================================

	if workplace is ResourceBuildingBase:

		print(
			"⛏️ 村民开始资源采集工作：",
			workplace.name,
			" | 职业：",
			job,
			" | 资源：",
			workplace.production_resource_type
		)

		state = State.FIND_RESOURCE

		return


	# ========================================================
	# 未实现的其他职业
	# ========================================================

	print(
		"⚠️ 当前职业暂时没有对应的工作逻辑：",
		job
	)
# ============================================================
# 是否空闲
# ============================================================

func is_idle() -> bool:
	#没有职业，并且也没有处于离职处理中，才算真正空闲。
	return job == Job.NONE and current_task == null and not is_quitting_job
# ============================================================
# @feature 根据职业返回正确的待命地点
# ============================================================

func return_to_idle():

	# ============================================================
	# 有工作：回工作建筑附近待命
	# ============================================================

	if job != Job.NONE and workplace != null:

		print(
			"💤 当前没有任务，返回工作地点待命：",
			workplace.name
		)

		navigation_agent.target_position = get_random_idle_position(
			workplace.global_position,workplace.idle_radius
		)

		state = State.RETURN_TO_IDLE

		return


	# ============================================================
	# 无业：回 Base 附近待命
	# ============================================================

	if target_base == null:
		find_base()

	if target_base != null:

		print("👨 无业居民返回据点附近待命")

		navigation_agent.target_position = get_random_idle_position(
			target_base.global_position,target_base.idle_radius
		)

		state = State.RETURN_TO_IDLE

	else:

		state = State.IDLE
# ============================================================
# 走回据点待命
# ============================================================
func move_to_idle_area():

	if navigation_agent.is_navigation_finished():

		velocity = Vector3.ZERO
		state = State.IDLE

		if job == Job.NONE:
			print("👨 已回到据点附近待命")
		else:
			print("💤 已回到工作地点附近待命：", workplace.name)

		return


	move_along_navigation()
# ============================================================
# 根据当前职业开始工作
# ============================================================

func start_current_job():

	match job:

		Job.LUMBERJACK:

			if workplace == null:
				print("❌ 伐木工没有工作建筑")
				job = Job.NONE
				return_to_idle()
				return

			print(
				"🪓 开始当前工作：",
				workplace.name
			)

			state = State.FIND_RESOURCE

		Job.NONE:

			return_to_idle()
# ============================================================
# 返回工作建筑
# ============================================================

func go_to_workplace():

	if workplace == null:

		print("❌ 没有工作建筑，无法运送木材")

		return_to_idle()

		return


	navigation_agent.target_position = (
		workplace.global_position
	)

	state = State.MOVE_TO_WORKPLACE

	print(
		"👨 携带木材返回：",
		workplace.name
	)
# ============================================================
# 移动到工作建筑
# ============================================================

func move_to_workplace():

	if workplace == null:

		return_to_idle()

		return


	if navigation_agent.is_navigation_finished():

		velocity = Vector3.ZERO


		# --------------------------------------------
		# 当前是运输任务
		# 到伐木场以后不是卸货，而是取货
		# --------------------------------------------

		if is_transporting:

			take_resource_for_transport()

			return


		# --------------------------------------------
		# 正常生产任务
		# 回伐木场是为了卸货
		# --------------------------------------------

		state = State.DEPOSIT_TO_WORKPLACE

		return


	move_along_navigation()
# ============================================================
# 把资源存入工作建筑
# ============================================================

func deposit_to_workplace():

	if carried_amount <= 0.0:

		state = State.FIND_RESOURCE

		return


	if workplace == null:

		return_to_idle()

		return


	if not workplace.has_method("deposit_resource"):

		print("❌ 工作建筑不能储存资源")

		return


	var deposited: float = workplace.deposit_resource(
		carried_resource_type,
		carried_amount
	)

	carried_amount -= deposited
	if deposited > 0.0:
		carried_resource_changed.emit()


	print(
		"🎒 居民剩余携带资源：",
		carried_amount
	)


	# 当前先测试本地库存。
	# 如果全部卸下，就继续工作。
	if carried_amount <= 0.0:
			# 正在离职
		if is_quitting_job:
			finish_quit_job()
			return
		state = State.FIND_RESOURCE

	else:

		print(
			"⚠️ 工作建筑已满，居民身上还有资源：",
			carried_amount
		)
		# 进入清仓模式
		is_clearing_workplace_storage = true
		# 现在转为运输任务
		is_transporting = true

		# 尽量从伐木场补满背包
		fill_carry_from_workplace()

		# 然后再去据点
		go_to_base()

# ============================================================
# 尝试运输工作建筑里的木材
# ============================================================

func try_transport_workplace_resource(
	resource_type: ResourceType.Type
) -> bool:

	# --------------------------------------------------------
	# 必须有工作建筑
	# --------------------------------------------------------

	if workplace == null:
		return false


	# --------------------------------------------------------
	# 工作建筑必须支持取货
	# --------------------------------------------------------

	if not workplace.has_method("take_resource"):
		return false


	# --------------------------------------------------------
	# 自己身上已经有木材
	# 直接运往据点
	# --------------------------------------------------------

	if carried_amount > 0.0:

		print(
			"📦 身上已有资源，开始运往据点：",
			carried_amount
		)

		go_to_base()

		return true


	# --------------------------------------------------------
	# 工作建筑没有库存
	# --------------------------------------------------------

	if workplace.has_method("has_resource"):

		if not workplace.has_resource(resource_type):
			return false


	# --------------------------------------------------------
	# 如果人不在工作建筑附近
	# 先回工作建筑
	# --------------------------------------------------------

	var distance = global_position.distance_to(
		workplace.global_position
	)


	if distance > 1.5:

		is_transporting = true

		print("📦 准备运输，先返回工作建筑取货")

		navigation_agent.target_position = (
			workplace.global_position
		)

		state = State.MOVE_TO_WORKPLACE

		return true


	# --------------------------------------------------------
	# 已经在工作建筑附近
	# 直接取货
	# --------------------------------------------------------

	var free_space: float = carry_capacity - carried_amount

	is_transporting = true

	var taken: float = workplace.take_resource(
		resource_type,
		free_space
	)


	if taken <= 0:
		return false


	carried_resource_type = resource_type
	carried_amount += taken
	carried_resource_changed.emit()


	print(
		"📦 居民开始运输资源：",
		carried_amount,
		"/",
		carry_capacity
	)


	go_to_base()


	return true


func try_transport_workplace_wood() -> bool:

	return try_transport_workplace_resource(ResourceType.Type.WOOD)
# ============================================================
# 从工作建筑取货并运输到据点
# ============================================================

func take_resource_for_transport():

	if workplace == null:

		is_transporting = false
		return_to_idle()
		return


	if not workplace.has_method("take_resource"):

		is_transporting = false
		state = State.FIND_RESOURCE
		return


	# 尽量把背包装满
	fill_carry_from_workplace()


	# 成功拿到货
	if carried_amount > 0.0:

		go_to_base()

		return


	# 没有货
	print("📦 工作建筑已经没有需要运输的资源")

	is_transporting = false
	state = State.FIND_RESOURCE
# ============================================================
# 从工作建筑补满背包
# ============================================================

func fill_carry_from_workplace():

	if workplace == null:
		return


	if not workplace.has_method("take_resource"):
		return


	# 背包还能装多少
	var free_space: float = carry_capacity - carried_amount


	# 已经满了
	if free_space <= 0:
		return


	# 从伐木场补货
	var resource_type: Variant = get_job_resource_type()
	if workplace.get("production_resource_type") != null:
		resource_type = workplace.production_resource_type

	if resource_type == null:
		return

	var taken: float = workplace.take_resource(
		resource_type,
		free_space
	)

	carried_resource_type = resource_type
	carried_amount += taken
	if taken > 0.0:
		carried_resource_changed.emit()


func take_wood_for_transport():

	take_resource_for_transport()


# ============================================================
# 获取随机待命位置
# ============================================================
# villager.gd

func get_random_idle_position(center: Vector3,radius: float) -> Vector3:

	var angle = randf_range(0.0, TAU)

	var direction = Vector2.from_angle(angle)

	var distance = randf_range(2.0, radius)

	var offset = direction * distance

	var random_position = center + Vector3(
		offset.x,
		0.0,
		offset.y
	)



	return random_position
#离职
func quit_job():

	if job == Job.NONE:
		return

	print("👋 开始退出当前工作：", workplace.name)

	is_quitting_job = true

	# 先释放正在处理的资源
	if is_instance_valid(target_resource):
		if target_resource.has_method("release"):
			target_resource.release(self)

	target_resource = null

	# 身上还有木材
	# 不能马上清空 workplace，因为还要知道送到哪里
	if state == State.MOVE_TO_BASE:
		return
	if carried_amount > 0.0:
		print("🎒 离职前先把携带资源送回工作建筑：", carried_amount)
		go_to_workplace()
		return

	# 身上没东西，可以直接完成离职
	finish_quit_job()
#正式离职
func finish_quit_job():

	print("👨 村民完成离职")

	is_quitting_job = false

	job = Job.NONE
	workplace = null
	target_resource = null

	return_to_idle()
# ============================================================
# 公共任务资格
# ============================================================

func can_take_task(_task: Object) -> bool:

	return (
		job == Job.NONE
		and current_task == null
		and not is_quitting_job
	)


func set_current_task(task: Object) -> void:

	current_task = task


func clear_current_task() -> void:

	current_task = null


# ============================================================
# 当前携带资源查询
# ============================================================

func get_carried_amount() -> float:

	return carried_amount


func get_carried_resource_type() -> ResourceType.Type:

	return carried_resource_type
