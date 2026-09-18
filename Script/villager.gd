extends UnitBase

# ============================================================
# 参数
# ============================================================

# 每次砍多少木材
@export var chop_amount: int = 1

# 每隔多少秒砍一次
@export var chop_interval: float = 1.0

# 最多携带多少木材
@export var carry_capacity: int = 5
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
	DEPOSIT_TO_BASE
}

var state: State = State.IDLE

enum Job {
	NONE,
	LUMBERJACK,
	MINER
}

func get_job_resource_type():

	match job:

		Job.LUMBERJACK:
			return ResourceBase.ResourceType.WOOD

		Job.MINER:
			return ResourceBase.ResourceType.STONE

		Job.NONE:
			return null
var job: Job = Job.NONE
# 当前工作建筑
var workplace: Node3D = null
# 当前是否正在执行工作建筑 → Base 的运输任务
var is_transporting: bool = false

# 当前目标树
var target_resource: ResourceBase = null

# 据点
var target_base: Node3D = null

# 当前携带木材
var carried_wood: int = 0

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

	var wanted_type = get_job_resource_type()

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

			if try_transport_workplace_wood():
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

		if carried_wood > 0:


			go_to_workplace()

			return


		# --------------------------------------------------------
		# 2. 身上没木材
		# 看工作建筑还有没有库存需要运输
		# --------------------------------------------------------

		if try_transport_workplace_wood():

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
		if carried_wood >= carry_capacity:

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

		var free_space = carry_capacity - carried_wood

		var amount_to_gather = min(
			chop_amount,
			free_space
		)

		var gathered_amount = target_resource.gather(
			amount_to_gather
		)

		carried_wood += gathered_amount


	# ========================================================
	# 背包满
	# ========================================================

	if carried_wood >= carry_capacity:

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
				carried_wood,
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
# 存木材
# ============================================================
func deposit_to_base():

	if carried_wood <= 0:
		start_current_job()
		return


	# ========================================================
	# 向据点卸货
	# ========================================================

	if target_base != null:

		if target_base.has_method("deposit_wood"):

			target_base.deposit_wood(
				carried_wood
			)


	print(
		"📦 向据点卸下木材：",
		carried_wood
	)


	carried_wood = 0


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

			if workplace.has_method("has_stored_wood"):

				if workplace.has_stored_wood():

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


	match job:

		Job.LUMBERJACK:

			state = State.FIND_RESOURCE


		Job.MINER:

			state = State.FIND_RESOURCE


		Job.NONE:

			return_to_idle()

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

func assign_job(new_job: Job, new_workplace: Node3D = null):

	job = new_job
	workplace = new_workplace


	match job:

		Job.NONE:

			print("👨 村民失去工作")
			# 如果当前有目标树，先解除预约
			if is_instance_valid(target_resource):

				if target_resource.has_method("release"):
					target_resource.release(self)

			workplace = null
			target_resource = null

			return_to_idle()


		Job.LUMBERJACK:

			if workplace == null:

				print("❌ 伐木工没有工作建筑")

				job = Job.NONE
				return_to_idle()

				return


			print(
				"🪓 村民成为伐木工，工作地点：",
				workplace.name
			)

			state = State.FIND_RESOURCE

# ============================================================
# 是否空闲
# ============================================================

func is_idle() -> bool:
	#没有职业，并且也没有处于离职处理中，才算真正空闲。
	return job == Job.NONE and not is_quitting_job
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

			take_wood_for_transport()

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

	if carried_wood <= 0:

		state = State.FIND_RESOURCE

		return


	if workplace == null:

		return_to_idle()

		return


	if not workplace.has_method("deposit_wood"):

		print("❌ 工作建筑不能储存木材")

		return


	var deposited = workplace.deposit_wood(
		carried_wood
	)

	carried_wood -= deposited


	print(
		"🎒 农民剩余携带木材：",
		carried_wood
	)


	# 当前先测试本地库存。
	# 如果全部卸下，就继续工作。
	if carried_wood <= 0:
			# 正在离职
		if is_quitting_job:
			finish_quit_job()
			return
		state = State.FIND_RESOURCE

	else:

		print(
			"⚠️ 伐木场已满，农民身上还有木材：",
			carried_wood
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

func try_transport_workplace_wood() -> bool:

	# --------------------------------------------------------
	# 必须有工作建筑
	# --------------------------------------------------------

	if workplace == null:
		return false


	# --------------------------------------------------------
	# 工作建筑必须支持取货
	# --------------------------------------------------------

	if not workplace.has_method("take_wood"):
		return false


	# --------------------------------------------------------
	# 自己身上已经有木材
	# 直接运往据点
	# --------------------------------------------------------

	if carried_wood > 0:

		print(
			"📦 身上已有木材，开始运往据点：",
			carried_wood
		)

		go_to_base()

		return true


	# --------------------------------------------------------
	# 工作建筑没有库存
	# --------------------------------------------------------

	if workplace.has_method("has_stored_wood"):

		if not workplace.has_stored_wood():
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

	var free_space = carry_capacity - carried_wood
	
	is_transporting = true

	var taken = workplace.take_wood(
		free_space
	)


	if taken <= 0:
		return false


	carried_wood += taken


	print(
		"📦 伐木工开始兼职运输：",
		carried_wood,
		"/",
		carry_capacity
	)


	go_to_base()


	return true
# ============================================================
# 从工作建筑取货并运输到据点
# ============================================================

func take_wood_for_transport():

	if workplace == null:

		is_transporting = false
		return_to_idle()
		return


	if not workplace.has_method("take_wood"):

		is_transporting = false
		state = State.FIND_RESOURCE
		return


	# 尽量把背包装满
	fill_carry_from_workplace()


	# 成功拿到货
	if carried_wood > 0:

		go_to_base()

		return


	# 没有货
	print("📦 伐木场已经没有需要运输的木材")

	is_transporting = false
	state = State.FIND_RESOURCE
# ============================================================
# 从工作建筑补满背包
# ============================================================

func fill_carry_from_workplace():

	if workplace == null:
		return


	if not workplace.has_method("take_wood"):
		return


	# 背包还能装多少
	var free_space = carry_capacity - carried_wood


	# 已经满了
	if free_space <= 0:
		return


	# 从伐木场补货
	var taken = workplace.take_wood(
		free_space
	)


	carried_wood += taken


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
	if carried_wood > 0:
		print("🎒 离职前先把携带资源送回工作建筑：", carried_wood)
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
