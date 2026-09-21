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
	MOVE_TO_TRAINING,
	TRAINING,
	MOVE_TO_BARRACKS,
	GARRISONED,
	MOVE_TO_PATROL_ASSEMBLE,
	PATROL_ASSEMBLING,
	MOVE_TO_PATROL_POINT,
	PATROLLING,
	RETURN_TO_BARRACKS,
	MOVE_TO_DEMOLITION,
	DEMOLISHING,
	MOVE_TO_DEMOLITION_BASE,
	DEPOSIT_DEMOLITION_TO_BASE,

	FIND_TASK_SOURCE,
	MOVE_TO_TASK_SOURCE,
	MOVE_TO_TASK_SITE,
	WAIT_TASK_RESOURCE,
	WAIT_CONSTRUCTION_SITE,
	MOVE_TO_BUILD_SITE,
	BUILDING,
	FIND_FIELD_WORK,
	MOVE_TO_FIELD,
	WORKING_FIELD
}

var state: State = State.IDLE
var patrol_barracks: Node = null
var patrol_resume_state: int = -1
var patrol_resume_target_position: Vector3 = Vector3.ZERO
var patrol_target_position: Vector3 = Vector3.ZERO
var patrol_last_position: Vector3 = Vector3.ZERO
var patrol_stuck_time: float = 0.0
var patrol_repath_attempt: int = 0
var patrol_collision_avoid_direction: Vector3 = Vector3.ZERO
var patrol_collision_avoid_time: float = 0.0
var patrol_route: Array[Vector3] = []
var patrol_route_index: int = -1
var patrol_queue_slot: int = 0
var patrol_queue_delay: float = 0.0
var patrol_previous_target_desired_distance: float = 1.5
var navigation_last_position: Vector3 = Vector3.ZERO
var navigation_stuck_time: float = 0.0
var garrison_resume_state: int = -1
var garrison_resume_target_position: Vector3 = Vector3.ZERO

enum Job {
	NONE,
	LUMBERJACK,
	MINER,
	FARMER
}

@export_category("军事职业")
@export_enum("无", "剑士") var combat_role: int = CombatRole.Type.NONE
@onready var body_mesh: MeshInstance3D = get_node_or_null("MeshInstance3D")


func set_combat_role(role: int) -> void:
	combat_role = role
	_update_combat_visual()


func get_combat_role() -> int:
	return combat_role


func has_combat_role() -> bool:
	return combat_role != CombatRole.Type.NONE


func _update_combat_visual() -> void:
	if body_mesh == null:
		return
	if combat_role == CombatRole.Type.SWORDSMAN:
		var swordsman_material := StandardMaterial3D.new()
		swordsman_material.albedo_color = Color(0.85, 0.05, 0.03, 1.0)
		swordsman_material.roughness = 0.8
		body_mesh.material_override = swordsman_material
	else:
		body_mesh.material_override = null

enum ActivityLevel {
	RESTING,
	NORMAL,
	WORKING,
	COMBAT
}

@export_category("居民需求")
@export_range(0.0, 100.0, 0.1) var hunger: float = 0.0
@export_range(0.0, 100.0, 0.1) var fatigue: float = 0.0
@export_range(0.0, 10.0, 0.01) var hunger_rate: float = 0.12
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
		State.MOVE_TO_DEMOLITION, State.DEMOLISHING, State.MOVE_TO_DEMOLITION_BASE, State.DEPOSIT_DEMOLITION_TO_BASE:
			return ActivityLevel.WORKING
		State.MOVE_TO_TRAINING, State.TRAINING:
			return ActivityLevel.WORKING
		State.MOVE_TO_PATROL_POINT, State.PATROLLING, State.RETURN_TO_BARRACKS:
			return ActivityLevel.WORKING
		State.GARRISONED:
			return ActivityLevel.NORMAL
		State.FIND_TASK_SOURCE, State.MOVE_TO_TASK_SOURCE:
			return ActivityLevel.WORKING
		State.MOVE_TO_TASK_SITE, State.MOVE_TO_BUILD_SITE, State.BUILDING, State.FIND_FIELD_WORK, State.MOVE_TO_FIELD, State.WORKING_FIELD:
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
	if is_instance_valid(demolition_target):
		return
	if is_instance_valid(construction_cancellation_target):
		return
	if is_instance_valid(garrisoned_in):
		return
	if (
		state == State.MOVE_TO_PATROL_POINT
		or state == State.PATROLLING
		or state == State.RETURN_TO_BARRACKS
		or state == State.MOVE_TO_TRAINING
		or state == State.TRAINING
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
	_remember_garrison_state_before_needs()
	_remember_patrol_state_before_needs()
	if is_instance_valid(target_resource) and target_resource.has_method("release"):
		target_resource.release(self)
	target_resource = null
	release_target_field()
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
	_remember_garrison_state_before_needs()
	_remember_patrol_state_before_needs()

	var base_storage: ResourceStorage = target_base.get("storage") as ResourceStorage
	if base_storage == null:
		base_storage = target_base.get_node_or_null("ResourceStorage") as ResourceStorage
	selected_food_id = choose_food(base_storage)
	if selected_food_id.is_empty():
		return false

	if is_instance_valid(target_resource) and target_resource.has_method("release"):
		target_resource.release(self)
	target_resource = null
	release_target_field()
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
	if _resume_garrison_after_needs():
		return
	if _resume_patrol_after_needs():
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
	if _resume_garrison_after_needs():
		return
	if _resume_patrol_after_needs():
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

# 当前农场田地与工作计时
var target_field: FarmField = null
var field_work_timer: float = 0.0

# 据点
var target_base: Node3D = null

# 当前训练进度。训练时间由剑士营配置，单位为秒。
var training_elapsed: float = 0.0

# 当前驻扎军营。驻军期间居民实体继续存在，但模型隐藏。
var garrisoned_in: Node = null
var garrison_target: Node = null

# 当前拆除任务。拆除材料必须由居民实际运回据点。
var demolition_target: Node = null
var construction_cancellation_target: Node = null

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
	_update_combat_visual()
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

		State.MOVE_TO_TRAINING:
			move_to_training()

		State.TRAINING:
			process_training(delta)

		State.MOVE_TO_BARRACKS:
			move_to_barracks()

		State.GARRISONED:
			velocity = Vector3.ZERO

		State.MOVE_TO_PATROL_ASSEMBLE:
			move_to_patrol_assemble()

		State.PATROL_ASSEMBLING:
			velocity = Vector3.ZERO

		State.MOVE_TO_PATROL_POINT:
			move_to_patrol_point()

		State.PATROLLING:
			velocity = Vector3.ZERO

		State.RETURN_TO_BARRACKS:
			return_to_patrol_barracks()

		State.MOVE_TO_DEMOLITION:
			move_to_demolition()

		State.DEMOLISHING:
			velocity = Vector3.ZERO

		State.MOVE_TO_DEMOLITION_BASE:
			move_to_demolition_base()

		State.DEPOSIT_DEMOLITION_TO_BASE:
			deposit_demolition_to_base()

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
				if navigation_agent.is_navigation_finished():
					_set_task_site_navigation_target()
				move_along_navigation()
			else:
				velocity = Vector3.ZERO

		State.MOVE_TO_BUILD_SITE:
			move_to_build_site()

		State.BUILDING:
			velocity = Vector3.ZERO

		State.FIND_FIELD_WORK:
			find_field_work()

		State.MOVE_TO_FIELD:
			move_to_field()

		State.WORKING_FIELD:
			work_field(delta)


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

	if task.type == GameTask.TaskType.TRAIN_SWORDSMAN:
		task.state = GameTask.State.IN_PROGRESS
		task_site = task.target as Node3D
		if task_site == null or not task_site.has_method("get_training_position"):
			_release_current_task()
			return
		navigation_agent.target_position = task_site.get_training_position(self)
		state = State.MOVE_TO_TRAINING
		print("Villager 前往训练：", task.id, " target=", task_site.name)
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


func is_waiting_at_construction_site(site: Node) -> bool:
	return (
		is_instance_valid(site)
		and task_site == site
		and state == State.WAIT_CONSTRUCTION_SITE
	)


func assign_construction_cancellation(site: Node3D) -> bool:
	if not is_instance_valid(site):
		return false
	construction_cancellation_target = site
	task_site = site
	_set_task_site_navigation_target()
	state = State.WAIT_CONSTRUCTION_SITE
	return true


func is_assigned_to_construction_cancellation(site: Node) -> bool:
	return (
		is_instance_valid(site)
		and construction_cancellation_target == site
	)


func has_reached_construction_cancellation_site(site: Node) -> bool:
	return (
		is_assigned_to_construction_cancellation(site)
		and _has_reached_task_site_navigation_target()
	)


func finish_construction_cancellation() -> void:
	construction_cancellation_target = null
	if current_task == null:
		task_site = null
		state = State.IDLE
		return_to_idle()


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


func move_to_training() -> void:
	if not is_instance_valid(task_site):
		_release_current_task()
		return
	if not navigation_agent.is_navigation_finished():
		move_along_navigation()
		return

	var task: GameTask = current_task as GameTask
	if task == null or not task_site.has_method("begin_training"):
		_release_current_task()
		return
	if not task_site.begin_training(self):
		_release_current_task()
		return
	training_elapsed = 0.0
	state = State.TRAINING
	print("Villager 开始训练：", task.id)


func process_training(delta: float) -> void:
	velocity = Vector3.ZERO
	if not is_instance_valid(task_site):
		_release_current_task()
		return
	training_elapsed += delta
	var training_time: float = 10.0
	if task_site.has_method("get_training_time"):
		training_time = task_site.get_training_time()
	if training_elapsed < training_time:
		return
	if not task_site.complete_training(self):
		_release_current_task()


func get_training_progress() -> float:
	if state != State.TRAINING or not is_instance_valid(task_site):
		return 0.0
	var training_time: float = 10.0
	if task_site.has_method("get_training_time"):
		training_time = task_site.get_training_time()
	return clampf(training_elapsed / maxf(training_time, 0.1), 0.0, 1.0)


func try_assign_to_barracks(barracks: Node) -> bool:
	if (
		barracks == null
		or combat_role != CombatRole.Type.SWORDSMAN
		or garrisoned_in != null
		or not is_idle()
		or state != State.IDLE and state != State.RETURN_TO_IDLE
	):
		return false
	if not barracks.has_method("register_garrison"):
		return false
	if not barracks.register_garrison(self):
		return false
	garrison_target = barracks
	var target_position: Vector3 = barracks.global_position
	if barracks.has_method("get_garrison_entrance_position"):
		target_position = barracks.get_garrison_entrance_position(self)
	navigation_agent.target_position = target_position
	state = State.MOVE_TO_BARRACKS
	return true


func move_to_barracks() -> void:
	if not is_instance_valid(garrison_target):
		garrison_target = null
		return_to_idle()
		return
	if not navigation_agent.is_navigation_finished():
		move_along_navigation()
		return
	if garrison_target.has_method("enter_garrison"):
		garrison_target.enter_garrison(self)
		return
	enter_garrison(garrison_target)


func enter_garrison(barracks: Node) -> void:
	garrisoned_in = barracks
	garrison_target = barracks
	garrison_resume_state = -1
	garrison_resume_target_position = Vector3.ZERO
	patrol_barracks = null
	visible = false
	collision_layer = 0
	collision_mask = 0
	state = State.GARRISONED


func is_garrisoned() -> bool:
	return is_instance_valid(garrisoned_in) and state == State.GARRISONED


func leave_garrison_for_patrol(barracks: Node, assemble_position: Vector3) -> bool:
	if garrisoned_in != barracks:
		return false
	garrisoned_in = null
	garrison_target = null
	patrol_barracks = barracks
	patrol_previous_target_desired_distance = navigation_agent.target_desired_distance
	visible = true
	collision_layer = 2
	# 巡逻队成员之间不互相阻挡，只保留与场景障碍的碰撞。
	collision_mask = 1
	navigation_agent.target_position = assemble_position
	state = State.MOVE_TO_PATROL_ASSEMBLE
	return true


func move_to_patrol_assemble() -> void:
	if not navigation_agent.is_navigation_finished():
		move_along_navigation()
		return
	velocity = Vector3.ZERO
	state = State.PATROL_ASSEMBLING
	if is_instance_valid(patrol_barracks) and patrol_barracks.has_method(
		"notify_patrol_assembled"
	):
		patrol_barracks.notify_patrol_assembled(self)


func start_patrol_point(target_position: Vector3) -> void:
	if not is_instance_valid(patrol_barracks):
		return
	patrol_target_position = target_position
	patrol_last_position = global_position
	patrol_stuck_time = 0.0
	patrol_repath_attempt = 0
	patrol_collision_avoid_direction = Vector3.ZERO
	patrol_collision_avoid_time = 0.0
	patrol_queue_delay = float(patrol_queue_slot) * 0.6
	navigation_agent.target_desired_distance = 0.25
	navigation_agent.target_position = target_position
	state = State.MOVE_TO_PATROL_POINT


func start_patrol_route(route: Array[Vector3], queue_slot: int = 0) -> void:
	if route.is_empty() or not is_instance_valid(patrol_barracks):
		return
	patrol_route = route.duplicate()
	patrol_route_index = 0
	patrol_queue_slot = maxi(queue_slot, 0)
	start_patrol_point(patrol_route[patrol_route_index])


func move_to_patrol_point() -> void:
	if patrol_queue_delay > 0.0:
		patrol_queue_delay = maxf(
			patrol_queue_delay - get_physics_process_delta_time(),
			0.0
		)
		velocity = Vector3.ZERO
		return
	if _has_reached_patrol_point():
		velocity = Vector3.ZERO
		state = State.PATROLLING
		if patrol_route_index + 1 < patrol_route.size():
			patrol_route_index += 1
			start_patrol_point(patrol_route[patrol_route_index])
		elif patrol_barracks.has_method("notify_patrol_route_completed"):
			patrol_barracks.notify_patrol_route_completed(self)
		return
	var movement_delta: float = global_position.distance_to(patrol_last_position)
	patrol_last_position = global_position
	if movement_delta < 0.02:
		patrol_stuck_time += get_physics_process_delta_time()
	else:
		patrol_stuck_time = 0.0
	if patrol_stuck_time >= 1.5:
		_repath_patrol_point()
	if not navigation_agent.is_navigation_finished():
		move_along_navigation()
		return
	# 导航提前结束但仍在到达半径外时，保留巡逻状态，避免把远处位置误判为巡逻点。
	velocity = Vector3.ZERO


func _has_reached_patrol_point() -> bool:
	if not is_instance_valid(patrol_barracks):
		return false
	var reach_radius: float = 1.5
	if patrol_barracks.has_method("get_patrol_point_reach_radius"):
		reach_radius = float(patrol_barracks.get_patrol_point_reach_radius())
	var target_position: Vector3 = patrol_target_position
	target_position.y = global_position.y
	return global_position.distance_to(target_position) <= reach_radius


func _repath_patrol_point() -> void:
	patrol_stuck_time = 0.0
	patrol_repath_attempt += 1
	patrol_last_position = global_position
	navigation_agent.target_position = patrol_target_position


func start_return_to_patrol_barracks() -> void:
	if not is_instance_valid(patrol_barracks):
		return
	patrol_collision_avoid_direction = Vector3.ZERO
	patrol_collision_avoid_time = 0.0
	navigation_agent.target_desired_distance = patrol_previous_target_desired_distance
	var target_position: Vector3 = patrol_barracks.global_position
	if patrol_barracks.has_method("get_garrison_entrance_position"):
		target_position = patrol_barracks.get_garrison_entrance_position(self)
	navigation_agent.target_position = target_position
	collision_mask = 3
	state = State.RETURN_TO_BARRACKS


func return_to_patrol_barracks() -> void:
	if not navigation_agent.is_navigation_finished():
		move_along_navigation()
		return
	velocity = Vector3.ZERO
	if patrol_barracks.has_method("receive_patrol_return"):
		patrol_barracks.receive_patrol_return(self)


func leave_garrison() -> void:
	garrisoned_in = null
	garrison_target = null
	garrison_resume_state = -1
	garrison_resume_target_position = Vector3.ZERO
	patrol_barracks = null
	patrol_target_position = Vector3.ZERO
	patrol_last_position = Vector3.ZERO
	patrol_stuck_time = 0.0
	patrol_repath_attempt = 0
	patrol_collision_avoid_direction = Vector3.ZERO
	patrol_collision_avoid_time = 0.0
	patrol_route.clear()
	patrol_route_index = -1
	patrol_queue_slot = 0
	patrol_queue_delay = 0.0
	navigation_agent.target_desired_distance = patrol_previous_target_desired_distance
	patrol_resume_state = -1
	visible = true
	collision_layer = 2
	collision_mask = 3
	return_to_idle()


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
	if workplace is Farm:
		var farm := workplace as Farm
		if carried_amount > 0.0:
			go_to_workplace()
		elif farm.should_transport_grain():
			start_farm_transport()
		else:
			start_farm_work()
		return

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

		# Farm 运输途中如果出现新的可处理田地，先结束本趟运输，
		# 不继续清空 Farm，交货后立即回去务农。
		if (
			workplace is Farm
			and workplace.has_method("has_available_field")
			and workplace.has_available_field()
		):
			is_clearing_workplace_storage = false
			is_transporting = false
			start_farm_work()
			return

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

	if state != State.MOVE_TO_PATROL_POINT:
		var movement_delta: float = global_position.distance_to(navigation_last_position)
		navigation_last_position = global_position
		if movement_delta < 0.02:
			navigation_stuck_time += get_physics_process_delta_time()
		else:
			navigation_stuck_time = 0.0
		if navigation_stuck_time >= 1.5:
			_repath_current_navigation_target()

	if (
		state == State.MOVE_TO_PATROL_POINT
		and patrol_collision_avoid_time > 0.0
		and patrol_collision_avoid_direction.length_squared() > 0.01
	):
		velocity.x = patrol_collision_avoid_direction.x * get_move_speed()
		velocity.z = patrol_collision_avoid_direction.z * get_move_speed()
		move_and_slide()
		patrol_collision_avoid_time = maxf(
			patrol_collision_avoid_time - get_physics_process_delta_time(),
			0.0
		)
		_update_patrol_collision_avoidance()
		if patrol_collision_avoid_time <= 0.0:
			patrol_collision_avoid_direction = Vector3.ZERO
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
	if state == State.MOVE_TO_PATROL_POINT:
		_update_patrol_collision_avoidance()


func _update_patrol_collision_avoidance() -> void:
	var collision_normal := Vector3.ZERO
	for collision_index in get_slide_collision_count():
		var slide_collision := get_slide_collision(collision_index)
		var current_normal: Vector3 = slide_collision.get_normal()
		current_normal.y = 0.0
		if current_normal.length_squared() > 0.01:
			collision_normal = current_normal.normalized()
			break
	if collision_normal == Vector3.ZERO:
		return

	var tangent_a := Vector3(-collision_normal.z, 0.0, collision_normal.x)
	var tangent_b := -tangent_a
	var reference_direction: Vector3 = patrol_collision_avoid_direction
	if reference_direction.length_squared() <= 0.01:
		reference_direction = patrol_target_position - global_position
		reference_direction.y = 0.0
		reference_direction = reference_direction.normalized()
	var tangent_a_score: float = tangent_a.dot(reference_direction)
	var tangent_b_score: float = tangent_b.dot(reference_direction)
	var chosen_tangent: Vector3
	if absf(tangent_a_score - tangent_b_score) <= 0.05:
		chosen_tangent = tangent_a if patrol_queue_slot % 2 == 0 else tangent_b
	else:
		chosen_tangent = tangent_a if tangent_a_score > tangent_b_score else tangent_b
	patrol_collision_avoid_direction = (
		chosen_tangent + collision_normal * 0.35
	).normalized()
	patrol_collision_avoid_time = 0.8


func _repath_current_navigation_target() -> void:
	navigation_stuck_time = 0.0
	var target_position: Vector3 = navigation_agent.target_position
	navigation_agent.target_position = global_position
	navigation_agent.target_position = target_position
# ============================================================
# 拆除建筑
# ============================================================

func assign_demolition(building: Node, take_over_current_job: bool = false) -> bool:
	if building == null:
		return false
	if not take_over_current_job and not is_idle():
		return false
	if take_over_current_job:
		current_task = null
		task_source = null
		task_site = null
		job = Job.NONE
		workplace = null
		is_quitting_job = false
		target_resource = null
		release_target_field()

	demolition_target = building
	if target_base == null:
		find_base()
	var target_position: Vector3 = building.global_position
	if building.has_method("get_interaction_position"):
		target_position = building.get_interaction_position(self)
	navigation_agent.target_position = target_position
	if global_position.distance_to(target_position) <= 1.0:
		if building.begin_demolition_work(self):
			return true
	state = State.MOVE_TO_DEMOLITION
	return true


func move_to_demolition() -> void:
	if not is_instance_valid(demolition_target):
		finish_demolition()
		return
	if not navigation_agent.is_navigation_finished():
		move_along_navigation()
		return

	velocity = Vector3.ZERO
	if not demolition_target.arrive_at_demolition_site(self):
		finish_demolition()


func set_demolition_working() -> void:
	state = State.DEMOLISHING


func begin_demolition_transport(
	building: Node,
	resource_id: StringName,
	amount: float
) -> void:
	if amount <= 0.0:
		return
	demolition_target = building
	carried_resource_id = resource_id
	carried_amount = amount
	carried_resource_changed.emit()
	if target_base == null:
		find_base()
	if target_base == null:
		return
	var target_position: Vector3 = target_base.global_position
	if target_base.has_method("get_interaction_position"):
		target_position = target_base.get_interaction_position(self)
	navigation_agent.target_position = target_position
	state = State.MOVE_TO_DEMOLITION_BASE


func return_to_demolition_site(building: Node) -> void:
	if building == null or not is_instance_valid(building):
		finish_demolition()
		return
	demolition_target = building
	var target_position: Vector3 = building.global_position
	if building.has_method("get_interaction_position"):
		target_position = building.get_interaction_position(self)
	navigation_agent.target_position = target_position
	state = State.MOVE_TO_DEMOLITION


func move_to_demolition_base() -> void:
	if not is_instance_valid(target_base):
		find_base()
	if target_base == null:
		return
	if not navigation_agent.is_navigation_finished():
		move_along_navigation()
		return
	velocity = Vector3.ZERO
	state = State.DEPOSIT_DEMOLITION_TO_BASE


func deposit_demolition_to_base() -> void:
	if target_base == null or not target_base.has_method("add_resource"):
		return
	if carried_amount <= 0.0:
		if is_instance_valid(demolition_target):
			demolition_target.demolition_delivery_completed(self)
		else:
			finish_demolition()
		return

	var stored_amount: float = target_base.add_resource(
		carried_resource_id,
		carried_amount
	)
	carried_amount -= stored_amount
	if stored_amount > 0.0:
		carried_resource_changed.emit()
	if carried_amount > 0.0:
		return

	if is_instance_valid(demolition_target):
		demolition_target.demolition_delivery_completed(self)
	else:
		finish_demolition()


func finish_demolition() -> void:
	demolition_target = null
	carried_amount = 0.0
	carried_resource_changed.emit()
	state = State.IDLE
	return_to_idle()


func finish_demolition_pickup() -> void:
	# 建筑在最后一批材料被拿起时删除，但手上的材料仍要继续运回据点。
	demolition_target = null
	if carried_amount <= 0.0:
		state = State.IDLE
		return_to_idle()


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
		release_target_field()

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
	return (
		job == Job.NONE
		and current_task == null
		and not is_quitting_job
		and garrisoned_in == null
		and not is_instance_valid(construction_cancellation_target)
		and carried_amount <= 0.0
	)
# ============================================================
# @feature 根据职业返回正确的待命地点
# ============================================================

func return_to_idle():
	if is_instance_valid(garrisoned_in):
		state = State.GARRISONED
		return

	if is_instance_valid(patrol_barracks):
		if _resume_patrol_after_needs():
			return
		return

	if combat_role == CombatRole.Type.SWORDSMAN and try_find_available_barracks():
		return

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


func _remember_patrol_state_before_needs() -> void:
	if not is_instance_valid(patrol_barracks) or patrol_resume_state >= 0:
		return
	patrol_resume_state = int(state)
	patrol_resume_target_position = navigation_agent.target_position


func _remember_garrison_state_before_needs() -> void:
	if garrison_resume_state >= 0:
		return
	if state != State.MOVE_TO_BARRACKS or not is_instance_valid(garrison_target):
		return
	garrison_resume_state = int(state)
	garrison_resume_target_position = navigation_agent.target_position


func _resume_garrison_after_needs() -> bool:
	if garrison_resume_state < 0:
		return false
	if not is_instance_valid(garrison_target):
		garrison_resume_state = -1
		garrison_resume_target_position = Vector3.ZERO
		return false
	var resume_state: int = garrison_resume_state
	var resume_target: Vector3 = garrison_resume_target_position
	garrison_resume_state = -1
	garrison_resume_target_position = Vector3.ZERO
	navigation_agent.target_position = resume_target
	state = resume_state
	return true


func _resume_patrol_after_needs() -> bool:
	if not is_instance_valid(patrol_barracks) or patrol_resume_state < 0:
		return false
	var resume_state: int = patrol_resume_state
	var resume_target: Vector3 = patrol_resume_target_position
	patrol_resume_state = -1
	patrol_resume_target_position = Vector3.ZERO
	navigation_agent.target_position = resume_target
	state = resume_state
	return true


func try_find_available_barracks() -> bool:
	if combat_role != CombatRole.Type.SWORDSMAN or garrisoned_in != null:
		return false
	for building: Node in get_tree().get_nodes_in_group("buildings"):
		if not building.has_method("has_free_garrison_slot"):
			continue
		if (
			building.has_method("is_demolition_in_progress")
			and building.is_demolition_in_progress()
		):
			continue
		if try_assign_to_barracks(building):
			return true
	return false
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


func start_farm_work() -> void:
	release_target_field()
	state = State.FIND_FIELD_WORK


func start_farm_transport() -> void:
	if not workplace is Farm:
		return_to_idle()
		return
	is_clearing_workplace_storage = true
	is_transporting = true
	if carried_amount <= 0.0:
		fill_carry_from_workplace()
	if carried_amount > 0.0:
		go_to_base()
	else:
		is_clearing_workplace_storage = false
		is_transporting = false
		start_farm_work()


func find_field_work() -> void:
	var farm := workplace as Farm
	if farm == null:
		return_to_idle()
		return

	target_field = farm.claim_next_field(self)
	if target_field == null:
		return_to_idle()
		return

	navigation_agent.target_position = target_field.global_position
	state = State.MOVE_TO_FIELD


func move_to_field() -> void:
	if not is_instance_valid(target_field):
		target_field = null
		state = State.FIND_FIELD_WORK
		return

	if not _has_reached_field_target():
		move_along_navigation()
		return

	velocity = Vector3.ZERO
	field_work_timer = 0.0
	state = State.WORKING_FIELD


func work_field(delta: float) -> void:
	velocity = Vector3.ZERO
	if not is_instance_valid(target_field) or not workplace is Farm:
		release_target_field()
		state = State.FIND_FIELD_WORK
		return

	field_work_timer += delta
	var farm := workplace as Farm
	var required_work_time: float = farm.get_field_work_time(target_field.state)
	if field_work_timer < required_work_time:
		return

	var is_harvesting: bool = target_field.state == FarmField.State.HARVESTING
	var completed: bool = target_field.complete_work(self)
	target_field = null
	field_work_timer = 0.0
	if completed and is_harvesting:
		var harvest_amount: float = minf(
			farm.grain_yield,
			carry_capacity - carried_amount
		)
		if harvest_amount > 0.0:
			carried_resource_id = &"grain"
			carried_amount += harvest_amount
			carried_resource_changed.emit()
			go_to_workplace()
			return
	state = State.FIND_FIELD_WORK


func _has_reached_field_target() -> bool:
	if navigation_agent.is_navigation_finished():
		return true
	var target_delta: Vector3 = navigation_agent.target_position - global_position
	target_delta.y = 0.0
	return target_delta.length() <= navigation_agent.target_desired_distance + 0.5


func release_target_field() -> void:
	if target_field == null:
		return
	if workplace != null and workplace.has_method("release_field"):
		workplace.release_field(self, target_field)
	target_field = null
	field_work_timer = 0.0


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
		if workplace is Farm:
			start_farm_work()
		else:
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
	if workplace is Farm and carried_amount > 0.0:
		print("⚠️ Farm 本地库存已满，Farmer 开始运输谷物")
		start_farm_transport()
		return


	# 当前先测试本地库存。
	# 如果全部卸下，就继续工作。
	if carried_amount <= 0.0:
			# 正在离职
		if is_quitting_job:
			finish_quit_job()
			return
		if workplace is Farm:
			start_farm_work()
		else:
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
		and not has_combat_role()
		and not is_instance_valid(construction_cancellation_target)
		and carried_amount <= 0.0
	)


func set_current_task(task: Object) -> void:

	current_task = task


func clear_current_task() -> void:

	var was_training: bool = (
		state == State.MOVE_TO_TRAINING or state == State.TRAINING
	)
	current_task = null
	if state == State.BUILDING or was_training:
		task_site = null
		if was_training:
			return_to_idle()
		else:
			state = State.IDLE


func return_carried_resource_to_base() -> bool:
	if carried_amount <= 0.0:
		print("📦 取消任务时居民没有携带资源")
		return false

	if target_base == null:
		find_base()
	if target_base == null or not target_base.has_method("add_resource"):
		print("⚠️ 取消任务时找不到据点，无法退回资源：", carried_amount)
		return false

	print("📦 任务取消，居民携带资源返回据点：", carried_amount)
	go_to_base()
	return true


# ============================================================
# 当前携带资源查询
# ============================================================

func get_carried_amount() -> float:

	return carried_amount


func get_carried_resource_id() -> StringName:

	return carried_resource_id


func get_carried_resource_type() -> ResourceType.Type:

	return ResourceStorage.resource_type_from_id(carried_resource_id)
