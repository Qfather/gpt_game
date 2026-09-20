extends UnitBase

signal unit_clicked(unit: UnitBase)

const RESOURCE_DATABASE: ResourceDatabase = preload(
	"res://data/resources/resource_database.tres"
)

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
	NEED_EAT,
	MOVE_TO_EAT,
	EATING,
	NEED_REST,
	MOVE_TO_REST,
	RESTING,
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
	MOVE_TO_TASK_SITE,
	WAIT_TASK_RESOURCE,
	WAIT_CONSTRUCTION_SITE,
	MOVE_TO_BUILD_SITE,
	BUILDING
}

var state: State = State.IDLE

enum Job {
	NONE,
	LUMBERJACK,
	MINER
}

enum ActivityLevel {
	RESTING,
	NORMAL,
	WORKING,
	COMBAT
}

@export_category("居民需求")
@export_range(0.0, 100.0, 0.1) var hunger: float = 0.0
@export_range(0.0, 100.0, 0.1) var fatigue: float = 0.0
@export_range(0.0, 10.0, 0.01) var hunger_rate: float = 0.6
@export_range(0.0, 10.0, 0.01) var fatigue_rate: float = 0.6
@export_range(0.0, 20.0, 0.1) var rest_recovery_rate: float = 4.0
const HUNGRY_THRESHOLD: float = 70.0
const TIRED_THRESHOLD: float = 90.0
const RESTED_THRESHOLD: float = 30.0
const ACTIVITY_MULTIPLIERS: Dictionary = {
	ActivityLevel.RESTING: 0.7,
	ActivityLevel.NORMAL: 1.0,
	ActivityLevel.WORKING: 1.5,
	ActivityLevel.COMBAT: 1.8
}

var activity_level: ActivityLevel = ActivityLevel.NORMAL
const EATING_TIME: float = 5.0
const SATIATED_HUNGER_THRESHOLD: float = 10.0
var eating_timer: float = 0.0
var resting_timer: float = 0.0
var selected_food_id: StringName = &""


func update_needs(delta: float) -> void:
	activity_level = get_activity_level()
	var multiplier: float = float(ACTIVITY_MULTIPLIERS[activity_level])
	hunger = clampf(hunger + delta * hunger_rate * multiplier, 0.0, 100.0)

	if activity_level == ActivityLevel.RESTING:
		fatigue = clampf(fatigue - delta * rest_recovery_rate, 0.0, 100.0)
	else:
		var current_fatigue_rate: float = (
			self.fatigue_rate
			if activity_level == ActivityLevel.WORKING
			else self.fatigue_rate * 0.15
		)
		fatigue = clampf(fatigue + delta * current_fatigue_rate, 0.0, 100.0)


func get_activity_level() -> ActivityLevel:
	match state:
		State.FIND_RESOURCE, State.MOVE_TO_RESOURCE, State.GATHER_RESOURCE:
			return ActivityLevel.WORKING
		State.MOVE_TO_WORKPLACE, State.DEPOSIT_TO_WORKPLACE:
			return ActivityLevel.WORKING
		State.MOVE_TO_BASE, State.DEPOSIT_TO_BASE:
			return ActivityLevel.WORKING
		State.FIND_TASK_SOURCE, State.MOVE_TO_TASK_SOURCE:
			return ActivityLevel.WORKING
		State.MOVE_TO_TASK_SITE, State.MOVE_TO_BUILD_SITE, State.BUILDING:
			return ActivityLevel.WORKING
		State.RESTING:
			return ActivityLevel.RESTING
		_:
			return ActivityLevel.NORMAL


func is_hungry() -> bool:
	return hunger >= HUNGRY_THRESHOLD


func is_tired() -> bool:
	return fatigue >= TIRED_THRESHOLD


func get_hunger() -> float:
	return hunger


func get_fatigue() -> float:
	return fatigue


func get_activity_level_name() -> String:
	return ActivityLevel.keys()[activity_level]


func find_available_food(
	storage_filter: ResourceStorage = null
) -> Array[StringName]:
	var available_food: Array[StringName] = []
	for resource_data: ResourceData in RESOURCE_DATABASE.resources:
		if resource_data == null or not resource_data.is_food():
			continue
		if storage_filter != null:
			if storage_filter.get_amount(resource_data.id) > 0.0:
				available_food.append(resource_data.id)
			continue
		for storage_node: Node in get_tree().get_nodes_in_group("resource_storages"):
			var storage: ResourceStorage = storage_node as ResourceStorage
			if storage != null and storage.get_amount(resource_data.id) > 0.0:
				available_food.append(resource_data.id)
				break
	return available_food


func choose_food(storage_filter: ResourceStorage = null) -> StringName:
	var available_food: Array[StringName] = find_available_food(storage_filter)
	return available_food[0] if not available_food.is_empty() else &""


func evaluate_needs() -> void:
	if (
		state == State.NEED_EAT
		or state == State.MOVE_TO_EAT
		or state == State.EATING
		or state == State.NEED_REST
		or state == State.MOVE_TO_REST
		or state == State.RESTING
		or is_quitting_job
	):
		return
	if carried_amount > 0.0:
		return
	if not is_hungry() and not is_tired():
		return
	if current_task != null:
		_release_current_task_for_needs()
		if current_task != null:
			return
	if target_base == null:
		return

	if is_hungry():
		if is_tired():
			begin_resting()
			return
		begin_eating()
		return

	if is_tired():
		begin_resting()


func move_to_eat() -> void:
	if target_base == null or not is_instance_valid(target_base):
		state = State.IDLE
		return
	if not navigation_agent.is_navigation_finished():
		move_along_navigation()
		return
	eating_timer = 0.0
	state = State.EATING


func begin_resting() -> void:
	if target_base == null or not is_instance_valid(target_base):
		return
	if is_instance_valid(target_resource) and target_resource.has_method("release"):
		target_resource.release(self)
	target_resource = null
	selected_food_id = &""
	if hunger > SATIATED_HUNGER_THRESHOLD:
		var base_storage: ResourceStorage = target_base.get("storage") as ResourceStorage
		if base_storage == null:
			base_storage = target_base.get_node_or_null("ResourceStorage") as ResourceStorage
		selected_food_id = choose_food(base_storage)
	eating_timer = 0.0
	var target_position: Vector3 = target_base.global_position
	if target_base.has_method("get_interaction_position"):
		target_position = target_base.get_interaction_position(self)
	navigation_agent.target_position = target_position
	state = State.NEED_REST


func begin_eating() -> bool:
	if target_base == null or not is_instance_valid(target_base):
		return false

	var base_storage: ResourceStorage = target_base.get("storage") as ResourceStorage
	if base_storage == null:
		base_storage = target_base.get_node_or_null("ResourceStorage") as ResourceStorage
	selected_food_id = choose_food(base_storage)
	if selected_food_id.is_empty():
		return false

	if is_instance_valid(target_resource) and target_resource.has_method("release"):
		target_resource.release(self)
	target_resource = null
	var target_position: Vector3 = target_base.global_position
	if target_base.has_method("get_interaction_position"):
		target_position = target_base.get_interaction_position(self)
	navigation_agent.target_position = target_position
	state = State.NEED_EAT
	return true


func move_to_rest() -> void:
	if target_base == null or not is_instance_valid(target_base):
		state = State.IDLE
		return
	if not navigation_agent.is_navigation_finished():
		move_along_navigation()
		return
	resting_timer = 0.0
	state = State.RESTING


func rest(delta: float) -> void:
	resting_timer += delta
	velocity = Vector3.ZERO
	_eat_while_resting(delta)
	if fatigue <= RESTED_THRESHOLD or resting_timer >= 20.0:
		_resume_after_rest()


func _eat_while_resting(delta: float) -> void:
	if selected_food_id.is_empty():
		return
	eating_timer += delta
	if eating_timer < EATING_TIME:
		return

	var base_storage: ResourceStorage = target_base.get("storage") as ResourceStorage
	if base_storage == null:
		base_storage = target_base.get_node_or_null("ResourceStorage") as ResourceStorage
	if base_storage == null:
		selected_food_id = &""
		return

	var consumed_amount: float = base_storage.take(selected_food_id, 1.0)
	if consumed_amount <= 0.0:
		selected_food_id = &""
		return

	var food_data: ResourceData = RESOURCE_DATABASE.get_resource_data(selected_food_id)
	if food_data != null and food_data.food_properties != null:
		hunger = clampf(
			hunger - food_data.food_properties.nutrition,
			0.0,
			100.0
		)

	if hunger > SATIATED_HUNGER_THRESHOLD:
		selected_food_id = choose_food(base_storage)
		eating_timer = 0.0
	else:
		selected_food_id = &""


func _resume_after_rest() -> void:
	resting_timer = 0.0
	if is_hungry() and begin_eating():
		return
	if job == Job.NONE:
		return_to_idle()
	else:
		start_current_job()


func eat_food(delta: float) -> void:
	eating_timer += delta
	velocity = Vector3.ZERO
	if eating_timer < EATING_TIME:
		return

	var base_storage: ResourceStorage = target_base.get("storage") as ResourceStorage
	if base_storage == null:
		base_storage = target_base.get_node_or_null("ResourceStorage") as ResourceStorage
	if base_storage == null:
		_resume_after_eating()
		return
	var consumed_amount: float = 0.0
	consumed_amount = base_storage.take(selected_food_id, 1.0)
	if consumed_amount <= 0.0:
		selected_food_id = choose_food(base_storage)
		if selected_food_id.is_empty():
			_resume_after_eating()
		else:
			eating_timer = 0.0
		return

	var food_data: ResourceData = RESOURCE_DATABASE.get_resource_data(selected_food_id)
	if food_data != null and food_data.food_properties != null:
		hunger = clampf(
			hunger - food_data.food_properties.nutrition,
			0.0,
			100.0
		)
	if hunger > SATIATED_HUNGER_THRESHOLD:
		selected_food_id = choose_food(base_storage)
		if not selected_food_id.is_empty():
			eating_timer = 0.0
			return
	_resume_after_eating()


func _resume_after_eating() -> void:
	selected_food_id = &""
	eating_timer = 0.0
	if is_tired():
		begin_resting()
		return
	if job == Job.NONE:
		return_to_idle()
	else:
		start_current_job()

func get_job_resource_id() -> StringName:

	if workplace is ResourceBuildingBase:

		return workplace.production_resource_id

	return &""


func get_job_resource_type() -> ResourceType.Type:
	return ResourceStorage.resource_type_from_id(get_job_resource_id())
var job: Job = Job.NONE
# 当前工作建筑
var workplace: Node3D = null
# 当前是否正在执行工作建筑 → Base 的运输任务
var is_transporting: bool = false

# 当前公共任务
var current_task: Object = null
var task_source: ResourceStorage = null
var task_site: Node3D = null
var task_resource_wait_timer: float = 0.0

# 当前目标树
var target_resource: ResourceBase = null

# 据点
var target_base: Node3D = null

# 当前携带的资源类型和数量
signal carried_resource_changed

var carried_resource_id: StringName = &"wood"

var carried_resource_type: ResourceType.Type:
	get:
		return ResourceStorage.resource_type_from_id(carried_resource_id)
	set(value):
		carried_resource_id = ResourceStorage.resource_id_from_key(value)
var carried_amount: float = 0.0

# 旧字段仅保留给外部兼容，不参与正式运输流程。
var carried_wood: int:
	get:
		return int(carried_amount) if carried_resource_id == &"wood" else 0
	set(value):
		carried_resource_id = &"wood"
		carried_amount = float(value)
		carried_resource_changed.emit()

# 砍树计时
var chop_timer: float = 0.0


# ============================================================
# 初始化
# ============================================================

func _ready():
	super._ready()
	input_event.connect(_on_input_event)
	call_deferred("start")
	

func _on_input_event(
	_camera: Node,
	event: InputEvent,
	_event_position: Vector3,
	_normal: Vector3,
	_shape_idx: int
) -> void:
	if not event is InputEventMouseButton:
		return

	var mouse_event: InputEventMouseButton = event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
		return

	unit_clicked.emit(self)
	get_viewport().set_input_as_handled()


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
	update_needs(delta)
	evaluate_needs()

	if (
		(
			state == State.IDLE
			or state == State.RETURN_TO_IDLE
			or state == State.WAIT_CONSTRUCTION_SITE
		)
		and current_task != null
	):
		_start_current_task()

	match state:

		State.IDLE:
			velocity = Vector3.ZERO

		State.NEED_EAT:
			state = State.MOVE_TO_EAT

		State.MOVE_TO_EAT:
			move_to_eat()

		State.EATING:
			eat_food(delta)

		State.NEED_REST:
			state = State.MOVE_TO_REST

		State.MOVE_TO_REST:
			move_to_rest()

		State.RESTING:
			rest(delta)

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

		State.WAIT_TASK_RESOURCE:
			wait_for_task_resource(delta)

		State.WAIT_CONSTRUCTION_SITE:
			if not is_instance_valid(task_site):
				return_to_idle()
			elif not _has_reached_task_site_navigation_target():
				move_along_navigation()
			else:
				velocity = Vector3.ZERO

		State.MOVE_TO_BUILD_SITE:
			move_to_build_site()

		State.BUILDING:
			velocity = Vector3.ZERO


func _start_current_task() -> void:

	var task: GameTask = current_task as GameTask
	if task == null:
		return

	if task.type == GameTask.TaskType.BUILD:
		task.state = GameTask.State.IN_PROGRESS
		task_site = task.target as Node3D
		if task_site == null:
			_release_current_task()
			return
		_set_task_site_navigation_target()
		state = State.MOVE_TO_BUILD_SITE
		print("Villager 前往施工：", task.id, " target=", task_site.name)
		return

	if task.type != GameTask.TaskType.DELIVER_CONSTRUCTION_RESOURCE:
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

	var resource_id: StringName = ResourceStorage.resource_id_from_key(
		task.data.get("resource_id", task.data.get("resource_type", &""))
	)
	var nearest: ResourceStorage = null
	var nearest_distance: float = INF

	for storage_node: Node in get_tree().get_nodes_in_group("resource_storages"):
		var storage: ResourceStorage = storage_node as ResourceStorage
		if storage == null or storage.get_amount(resource_id) <= 0.0:
			continue

		var storage_parent: Node3D = storage.get_parent() as Node3D
		if storage_parent == null:
			continue

		var distance: float = global_position.distance_to(storage_parent.global_position)
		if distance < nearest_distance:
			nearest = storage
			nearest_distance = distance

	if nearest == null:
		_fail_delivery_task_and_return_to_idle()
		return

	task_source = nearest
	var source_parent: Node3D = task_source.get_parent() as Node3D
	if source_parent == null:
		_release_current_task()
		return

	var source_position: Vector3 = source_parent.global_position
	if source_parent.has_method("get_interaction_position"):
		source_position = source_parent.get_interaction_position(self)
	navigation_agent.target_position = source_position
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

	var resource_id: StringName = ResourceStorage.resource_id_from_key(
		task.data.get("resource_id", task.data.get("resource_type", &""))
	)
	var requested_amount: float = float(task.data.get("amount", 0.0))
	var taken_amount: float = task_source.take(resource_id, minf(requested_amount, carry_capacity))
	if taken_amount <= 0.0:
		_fail_delivery_task_and_return_to_idle()
		return

	carried_resource_id = resource_id
	carried_amount += taken_amount
	task.data["resource_taken_amount"] = taken_amount
	carried_resource_changed.emit()
	print("Villager 取出资源：", resource_id, " amount=", taken_amount)

	_set_task_site_navigation_target()
	state = State.MOVE_TO_TASK_SITE


func wait_for_task_resource(delta: float) -> void:

	task_resource_wait_timer += delta
	if task_resource_wait_timer < 1.0:
		if task_site != null and not _has_reached_task_site_navigation_target():
			move_along_navigation()
		return

	task_resource_wait_timer = 0.0
	find_task_source()


func _fail_delivery_task_and_return_to_idle() -> void:
	var task: GameTask = current_task as GameTask
	var managers: Array[Node] = get_tree().get_nodes_in_group("task_manager")
	if task != null and not managers.is_empty() and managers[0].has_method("fail_task"):
		managers[0].fail_task(task)
	else:
		clear_current_task()
		return_to_idle()

	task_source = null
	task_site = null
	task_resource_wait_timer = 0.0


func wait_at_construction_site(site: Node3D) -> void:
	task_site = site
	_set_task_site_navigation_target()
	state = State.WAIT_CONSTRUCTION_SITE


func _set_task_site_navigation_target() -> void:
	if not is_instance_valid(task_site):
		return

	var target_position: Vector3 = task_site.global_position
	if task_site.has_method("get_worker_target_position"):
		var worker_target: Variant = task_site.call("get_worker_target_position", self)
		if worker_target is Vector3:
			target_position = worker_target

	var navigation_map: RID = navigation_agent.get_navigation_map()
	if navigation_map.is_valid():
		navigation_agent.target_position = NavigationServer3D.map_get_closest_point(
			navigation_map,
			target_position
		)
	else:
		navigation_agent.target_position = target_position


func _has_reached_task_site_navigation_target() -> bool:
	if navigation_agent.is_navigation_finished():
		return true

	var target_delta: Vector3 = navigation_agent.target_position - global_position
	target_delta.y = 0.0
	return target_delta.length() <= navigation_agent.target_desired_distance + 0.5


func wake_delivery_task() -> void:
	var task: GameTask = current_task as GameTask
	if task == null or task.type != GameTask.TaskType.DELIVER_CONSTRUCTION_RESOURCE:
		return
	if state != State.WAIT_TASK_RESOURCE and state != State.WAIT_CONSTRUCTION_SITE:
		return

	task_resource_wait_timer = 0.0
	state = State.FIND_TASK_SOURCE


func move_to_task_site() -> void:

	if not is_instance_valid(task_site):
		_release_current_task()
		return

	var reached_site: bool = _has_reached_task_site_navigation_target()
	if not reached_site:
		move_along_navigation()
		return

	var task: GameTask = current_task as GameTask
	if task == null:
		state = State.IDLE
		return

	var delivered_amount: float = task_site.receive_delivery(
		carried_resource_id,
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

	var completed_site: Node = task_site
	task_source = null
	task_site = null
	state = State.IDLE
	call_deferred("_return_to_idle_if_task_finished", completed_site)
	print("Villager 完成搬运任务：", task.id, " delivered=", delivered_amount)


func _return_to_idle_if_task_finished(completed_site: Node) -> void:
	if current_task != null or state != State.IDLE:
		return

	if carried_amount > 0.0:
		go_to_base()
		return

	if is_instance_valid(completed_site):
		var resource_id: StringName = &""
		if completed_site.has_method("get_delivery_resource_id"):
			resource_id = completed_site.get_delivery_resource_id()
		elif completed_site.has_method("get_delivery_resource_type"):
			resource_id = ResourceStorage.resource_id_from_key(
				completed_site.get_delivery_resource_type()
			)

		if not resource_id.is_empty():
			for storage_node: Node in get_tree().get_nodes_in_group(
				"resource_storages"
			):
				var storage: ResourceStorage = storage_node as ResourceStorage
				if storage != null and storage.get_amount(resource_id) > 0.0:
					return

	return_to_idle()


func move_to_build_site() -> void:

	if not is_instance_valid(task_site):
		_release_current_task()
		return

	var reached_site: bool = _has_reached_task_site_navigation_target()
	if not reached_site:
		move_along_navigation()
		return

	var task: GameTask = current_task as GameTask
	if task == null or not task_site.has_method("add_builder"):
		_release_current_task()
		return

	if not task_site.add_builder(self):
		_release_current_task()
		return

	state = State.BUILDING
	print("Villager 已加入施工：", task.id)


func _release_current_task() -> void:

	var task: GameTask = current_task as GameTask
	var managers: Array[Node] = get_tree().get_nodes_in_group("task_manager")
	if task != null and not managers.is_empty() and managers[0].has_method("fail_task"):
		managers[0].fail_task(task)
	else:
		clear_current_task()

	task_source = null
	task_site = null
	state = State.IDLE


func _release_current_task_for_needs() -> void:
	var task: GameTask = current_task as GameTask
	var managers: Array[Node] = get_tree().get_nodes_in_group("task_manager")
	if task != null and not managers.is_empty() and managers[0].has_method("release_task"):
		managers[0].release_task(task)
	else:
		clear_current_task()

	task_source = null
	task_site = null
	task_resource_wait_timer = 0.0

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

	var wanted_resource_id: StringName = get_job_resource_id()

	if wanted_resource_id.is_empty():

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

			if try_transport_workplace_resource(wanted_resource_id):
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

		if resource.get_resource_id() != wanted_resource_id:
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

		if try_transport_workplace_resource(wanted_resource_id):

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

		var gather_resource_id: StringName = get_job_resource_id()
		if not gather_resource_id.is_empty():
			carried_resource_id = gather_resource_id
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


	var base_position: Vector3 = target_base.global_position
	if target_base.has_method("get_interaction_position"):
		base_position = target_base.get_interaction_position(self)
	navigation_agent.target_position = base_position


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
				carried_resource_id,
				carried_amount
			)

			carried_amount -= stored_amount
			if stored_amount > 0.0:
				carried_resource_changed.emit()


	print(
		"📦 向据点卸货完成，剩余携带：",
		carried_amount,
		" | 资源类型：",
		carried_resource_id
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

				if workplace.has_resource(carried_resource_id):

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
		workplace.production_resource_id
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

	var reached_idle_position: bool = (
		navigation_agent.is_navigation_finished()
		or global_position.distance_to(navigation_agent.target_position) <= 0.8
	)
	if reached_idle_position:

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
	if workplace is ResourceBuildingBase:
		if workplace.resume_worker(self):
			print(
				"⛏️ 恢复资源建筑工作：",
				workplace.name
			)
			return

		print("❌ 资源建筑无法恢复居民工作：", workplace.name)
		job = Job.NONE
		return_to_idle()
		return

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


	var workplace_position: Vector3 = workplace.global_position
	if workplace.has_method("get_interaction_position"):
		workplace_position = workplace.get_interaction_position(self)
	navigation_agent.target_position = workplace_position

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
		carried_resource_id,
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
	resource_key: Variant
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

		if not workplace.has_resource(resource_key):
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
		resource_key,
		free_space
	)


	if taken <= 0:
		return false


	carried_resource_id = ResourceStorage.resource_id_from_key(resource_key)
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

	return try_transport_workplace_resource(&"wood")
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
	var resource_id: Variant = get_job_resource_id()
	if workplace.get("production_resource_id") != null:
		resource_id = workplace.production_resource_id

	if resource_id == null or StringName(resource_id).is_empty():
		return

	var taken: float = workplace.take_resource(
		resource_id,
		free_space
	)

	carried_resource_id = ResourceStorage.resource_id_from_key(resource_id)
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

	var managers: Array[Node] = get_tree().get_nodes_in_group("task_manager")
	if not managers.is_empty() and managers[0].has_method("request_dispatch"):
		managers[0].request_dispatch()
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
	if state == State.BUILDING:
		task_site = null
		state = State.IDLE


func return_carried_resource_to_base() -> void:
	if carried_amount <= 0.0:
		print("📦 取消任务时居民没有携带资源")
		return

	if target_base == null:
		find_base()
	if target_base == null or not target_base.has_method("add_resource"):
		print("⚠️ 取消任务时找不到据点，无法退回资源：", carried_amount)
		return

	var returned_amount: float = target_base.add_resource(
		carried_resource_id,
		carried_amount
	)
	carried_amount -= returned_amount
	if returned_amount > 0.0:
		carried_resource_changed.emit()
		print("📦 任务取消，资源退回据点：", returned_amount)


# ============================================================
# 当前携带资源查询
# ============================================================

func get_carried_amount() -> float:

	return carried_amount


func get_carried_resource_id() -> StringName:

	return carried_resource_id


func get_carried_resource_type() -> ResourceType.Type:

	return ResourceStorage.resource_type_from_id(carried_resource_id)
