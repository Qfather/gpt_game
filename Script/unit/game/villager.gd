extends UnitBase

signal unit_clicked(unit: UnitBase)

const UnitDataResource = preload("res://Script/unit/unit_data.gd")

@export var unit_data: UnitDataResource
var character_name: String = ""
const RESIDENT_DATA: UnitDataResource = preload("res://data/units/ResidentData.tres")
const SWORDSMAN_DATA: UnitDataResource = preload("res://data/units/SwordsmanData.tres")
const ARCHER_DATA: UnitDataResource = preload("res://data/units/ArcherData.tres")
const HUNTER_DATA: UnitDataResource = preload("res://data/units/HunterData.tres")
const ARROW_SCRIPT: Script = preload("res://Script/combat/arrow.gd")
var hunting: RefCounted = preload("res://Script/unit/hunting_behavior.gd").new()
var ranged_shot_remaining: float = 0.0
var visual_instance: Node3D
var visual_root: Node3D

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
	GARRISON_EATING,
	GARRISON_RESTING,
	MOVE_TO_PATROL_ASSEMBLE,
	PATROL_ASSEMBLING,
	MOVE_TO_PATROL_POINT,
	PATROLLING,
	RETURN_TO_BARRACKS,
	COMBAT_MOVE,
	COMBAT_ATTACK,
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
	WORKING_FIELD,
	MOVE_TO_LOOT,
	HUNTING,
	MOVE_TO_REPAIR,
	REPAIRING,
	RETREAT_TO_BASE,
	MOVE_TO_RELOCATED_BUILDING,
	MOVE_TO_ROAD,
	BUILD_ROAD,
	SHELTERED,
	WATCHING
}

var relocated_building: BuildingBase
var relocation_resumes_training: bool = false

var gather_previous_target_desired_distance: float = 1.5
var gather_previous_path_desired_distance: float = 0.5
var state: State = State.IDLE:
	set(value):
		if state == value:
			return
		if navigation_agent != null:
			if state in [State.MOVE_TO_RESOURCE, State.MOVE_TO_FIELD, State.MOVE_TO_TASK_SITE, State.MOVE_TO_BUILD_SITE, State.WAIT_CONSTRUCTION_SITE, State.RETURN_TO_IDLE, State.HUNTING, State.MOVE_TO_TRAINING, State.MOVE_TO_BARRACKS, State.RETURN_TO_BARRACKS, State.RETREAT_TO_BASE, State.MOVE_TO_WORKPLACE]:
				navigation_agent.target_desired_distance = gather_previous_target_desired_distance
				navigation_agent.path_desired_distance = gather_previous_path_desired_distance
			if value in [State.MOVE_TO_RESOURCE, State.MOVE_TO_FIELD, State.MOVE_TO_TASK_SITE, State.MOVE_TO_BUILD_SITE, State.WAIT_CONSTRUCTION_SITE, State.RETURN_TO_IDLE, State.HUNTING, State.MOVE_TO_TRAINING, State.MOVE_TO_BARRACKS, State.RETURN_TO_BARRACKS, State.RETREAT_TO_BASE, State.MOVE_TO_WORKPLACE]:
				gather_previous_target_desired_distance = navigation_agent.target_desired_distance
				gather_previous_path_desired_distance = navigation_agent.path_desired_distance
				navigation_agent.target_desired_distance = 0.2
				navigation_agent.path_desired_distance = 0.2
		state = value
		idle_warning_elapsed = 0.0
		if value != State.RETURN_TO_IDLE: initial_idle_position_pending = false
		_set_unreachable_warning(false)
var treasure_camp: Node3D
var treasure_resume: Dictionary = {}
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
var unreachable_time: float = 0.0
var unreachable_last_position: Vector3 = Vector3.ZERO
var unreachable_target_position: Vector3 = Vector3.ZERO
var unreachable_state: State = State.IDLE
var unreachable_warning: bool = false
var unreachable_marker: Label3D
var abandoning_work: bool = false
var workplace_repath_msec: int = 0
var abandoned_work_target_id: int = 0
var garrison_resume_state: int = -1
var garrison_resume_target_position: Vector3 = Vector3.ZERO
var resupply_barracks: Node = null
var resupply_food_id: StringName = &""
var returning_resupply_surplus: bool = false
var idle_reposition_timer: float = 0.0
var idle_warning_elapsed: float = 0.0
var initial_idle_position_pending: bool = false
var unit_avoidance = preload("res://Script/unit/unit_avoidance.gd").new()
var yield_cooldown: float = 0.0
var tower_look_timer: float = 0.0
var shelter_target: BuildingBase
var shelter_repath_msec: int = 0
var shelter_exit_position: Vector3
var passing_door: bool = false
var door_building: BuildingBase
var construction_repositioning: bool = false
var retreat_threat: Node3D
var retreat_safe_at_msec: int = 0
var settlement_alarm: Node
var leaving_immigration_base: bool = false

@export_category("剑士战斗")
@export var combat_damage: float = 10.0
@export var combat_attack_range: float = 1.5
@export var combat_attack_interval: float = 1.0
@export var combat_detection_range: float = 10.0

var combat_target: Node3D = null
var combat_resume_state: int = -1
var combat_resume_target_position: Vector3 = Vector3.ZERO
var combat_resume_navigation_target: Vector3 = Vector3.ZERO
var combat_attack_cooldown: float = 0.0
var stun_remaining: float = 0.0

enum Job {
	NONE,
	LUMBERJACK,
	MINER,
	FARMER,
	HUNTER,
	WATCHER
}

const JOB_CLOTHING_COLORS: Dictionary = {
	Job.LUMBERJACK: Color(0.2, 0.65, 0.3),
	Job.MINER: Color(0.25, 0.5, 0.9),
	Job.FARMER: Color(0.95, 0.75, 0.2),
	Job.HUNTER: Color(0.9, 0.35, 0.15),
}

@export_category("军事职业")
@export_enum("无", "剑士", "弓箭手") var combat_role: int = CombatRole.Type.NONE
var road_navigation = preload("res://Script/unit/road_navigation.gd").new()
var road_previous_target_distance: float = 1.5

@onready var body_mesh: MeshInstance3D = get_node_or_null("MeshInstance3D")


func set_combat_role(role: int) -> void:
	combat_role = role
	set_unit_data(ARCHER_DATA if role == CombatRole.Type.ARCHER else (SWORDSMAN_DATA if role == CombatRole.Type.SWORDSMAN else RESIDENT_DATA))


func set_unit_data(data: UnitDataResource) -> void:
	var health_ratio: float = get_health() / maxf(get_max_health(), 1.0) if is_node_ready() else 1.0
	unit_data = data
	_apply_unit_parameters()
	if is_node_ready():
		health_component.max_health = get_max_health()
		health_component.current_health = health_component.max_health * health_ratio
		_on_health_component_changed(health_component.current_health, health_component.max_health)
		var range_display: Node = get_node_or_null("SwordsmanAggroRange")
		if range_display != null: range_display.set_radius(combat_detection_range)
		_update_combat_visual()


func _apply_unit_parameters() -> void:
	for key: String in UnitDataResource.PARAMETERS:
		set(UnitDataResource.PARAMETERS[key], unit_data.get(key))
	base_attack_damage = unit_data.damage


func get_display_name() -> String:
	return unit_data.display_name if unit_data != null else String(name)


func get_named_display_name() -> String:
	return "%s · %s" % [character_name, get_display_name()] if not character_name.is_empty() else get_display_name()


func get_move_speed() -> float:
	return road_navigation.move_speed(self, super.get_move_speed())


func get_combat_role() -> int:
	return combat_role


func has_combat_role() -> bool:
	return combat_role != CombatRole.Type.NONE


func _face_direction(direction: Vector3) -> void:
	var visual: Node3D = visual_root if is_instance_valid(visual_instance) else body_mesh
	preload("res://Script/unit/unit_facing.gd").face_direction(visual, direction)


func _update_combat_visual() -> void:
	if has_combat_role():
		add_to_group("combat_units")
	elif is_in_group("combat_units"):
		remove_from_group("combat_units")
	if body_mesh == null or unit_data == null:
		return
	if not is_instance_valid(visual_root):
		visual_root = Node3D.new()
		visual_root.name = "VisualRoot"
		add_child(visual_root)
	if is_instance_valid(visual_instance):
		visual_root.remove_child(visual_instance)
		visual_instance.queue_free()
		visual_instance = null
	body_mesh.visible = unit_data.visual_scene == null
	if unit_data.visual_scene != null:
		visual_instance = unit_data.visual_scene.instantiate() as Node3D
		visual_root.add_child(visual_instance)
	_apply_visual_tint(visual_instance if visual_instance != null else body_mesh)
	_update_work_clothing()


func _update_work_clothing() -> void:
	if not is_instance_valid(visual_instance): return
	var color: Color = JOB_CLOTHING_COLORS.get(job, Color.WHITE) if not has_combat_role() else Color.WHITE
	for part: String in ["Body", "Tunic", "LeftArm", "RightArm"]:
		var mesh: MeshInstance3D = visual_instance.get_node_or_null(part) as MeshInstance3D
		if mesh == null: continue
		if not mesh.has_meta("original_clothing_material"):
			mesh.set_meta("original_clothing_material", mesh.get_active_material(0))
		var original: Material = mesh.get_meta("original_clothing_material")
		if color == Color.WHITE:
			mesh.material_override = original
		elif original is StandardMaterial3D:
			var material: StandardMaterial3D = original.duplicate()
			material.albedo_color = color
			mesh.material_override = material


func _apply_visual_tint(node: Node) -> void:
	if node is MeshInstance3D:
		if unit_data.visual_tint == Color.WHITE:
			if node == body_mesh: node.material_override = null
		else:
			var material := StandardMaterial3D.new()
			material.albedo_color = unit_data.visual_tint
			material.roughness = 0.8
			node.material_override = material
	for child: Node in node.get_children(): _apply_visual_tint(child)

enum ActivityLevel {
	RESTING,
	NORMAL,
	WORKING,
	COMBAT
}

@export_category("居民需求")
@export_range(0.0, 100.0, 0.1) var hunger: float = 0.0
@export_range(0.0, 100.0, 0.1) var fatigue: float = 0.0
@export_range(0.0, 10.0, 0.01) var hunger_rate: float = 0.3
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
const SATIATED_HUNGER_THRESHOLD: float = 30.0
var eating_timer: float = 0.0
var resting_timer: float = 0.0
var home_building: BuildingBase
var indoor_building: BuildingBase
var indoor_idle: bool = false
var idle_entrance_target: BuildingBase
var rest_home: BuildingBase
var rest_previous_target_distance: float = 1.5
var selected_food_id: StringName = &""
var preferred_food_effect_remaining: float = 0.0
var preferred_food_hunger_multiplier: float = 1.0


func update_needs(delta: float) -> void:
	activity_level = get_activity_level()
	var multiplier: float = float(ACTIVITY_MULTIPLIERS[activity_level])
	var effect_delta: float = minf(delta, preferred_food_effect_remaining)
	var hunger_delta: float = delta - effect_delta + effect_delta * preferred_food_hunger_multiplier
	preferred_food_effect_remaining = maxf(preferred_food_effect_remaining - delta, 0.0)
	hunger = clampf(hunger + hunger_delta * hunger_rate * multiplier, 0.0, 100.0)

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
		State.HUNTING, State.RETREAT_TO_BASE:
			return ActivityLevel.WORKING
		State.FIND_RESOURCE, State.MOVE_TO_RESOURCE, State.GATHER_RESOURCE:
			return ActivityLevel.WORKING
		State.MOVE_TO_WORKPLACE, State.DEPOSIT_TO_WORKPLACE:
			return ActivityLevel.WORKING
		State.MOVE_TO_BASE, State.DEPOSIT_TO_BASE:
			return ActivityLevel.WORKING
		State.MOVE_TO_DEMOLITION, State.DEMOLISHING, State.MOVE_TO_DEMOLITION_BASE, State.DEPOSIT_DEMOLITION_TO_BASE, State.MOVE_TO_LOOT:
			return ActivityLevel.WORKING
		State.MOVE_TO_TRAINING, State.TRAINING:
			return ActivityLevel.WORKING
		State.MOVE_TO_PATROL_POINT, State.PATROLLING, State.RETURN_TO_BARRACKS:
			return ActivityLevel.WORKING
		State.GARRISONED:
			return ActivityLevel.NORMAL
		State.GARRISON_EATING:
			return ActivityLevel.NORMAL
		State.GARRISON_RESTING:
			return ActivityLevel.RESTING
		State.FIND_TASK_SOURCE, State.MOVE_TO_TASK_SOURCE:
			return ActivityLevel.WORKING
		State.MOVE_TO_TASK_SITE, State.MOVE_TO_BUILD_SITE, State.BUILDING, State.MOVE_TO_ROAD, State.BUILD_ROAD, State.FIND_FIELD_WORK, State.MOVE_TO_FIELD, State.WORKING_FIELD, State.MOVE_TO_REPAIR, State.REPAIRING:
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


func choose_food(storage_filter: ResourceStorage = null, resupply_target: Barracks = null) -> StringName:
	var available_food: Array[StringName] = find_available_food(storage_filter)
	if resupply_target != null:
		available_food = available_food.filter(func(id: StringName) -> bool: return resupply_target.get_food_free_space(id) > 0.0)
	for food_id: StringName in available_food:
		if not _get_food_preferences(RESOURCE_DATABASE.get_resource_data(food_id)).is_empty():
			return food_id
	return available_food[0] if not available_food.is_empty() else &""


func _get_food_preferences(food: ResourceData) -> Array[TraitData]:
	var result: Array[TraitData] = []
	if food == null:
		return result
	for entry: UnitTrait in traits:
		if entry == null or entry.trait_data == null:
			continue
		for tag: StringName in entry.trait_data.preferred_food_tags:
			if food.has_tag(tag):
				result.append(entry.trait_data)
				break
	return result


func _apply_food_nutrition(food: ResourceData) -> void:
	if food == null or food.food_properties == null:
		return
	var nutrition_multiplier: float = 1.0
	for preference: TraitData in _get_food_preferences(food):
		nutrition_multiplier = maxf(nutrition_multiplier, preference.preferred_nutrition_multiplier)
		if preference.preferred_effect_duration > 0.0:
			if preferred_food_effect_remaining <= 0.0 or preference.preferred_hunger_multiplier < preferred_food_hunger_multiplier:
				preferred_food_hunger_multiplier = preference.preferred_hunger_multiplier
				preferred_food_effect_remaining = preference.preferred_effect_duration
			elif preference.preferred_hunger_multiplier == preferred_food_hunger_multiplier:
				preferred_food_effect_remaining = maxf(preferred_food_effect_remaining, preference.preferred_effect_duration)
	hunger = clampf(hunger - food.food_properties.nutrition * nutrition_multiplier, 0.0, 100.0)


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
	if is_instance_valid(garrisoned_in) or is_instance_valid(patrol_barracks) or is_instance_valid(resupply_barracks):
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
	rest_home = home_building if is_instance_valid(home_building) and not home_building.is_queued_for_deletion() and not home_building.is_demolition_in_progress() else target_base
	if is_instance_valid(indoor_building) and indoor_building != rest_home:
		await _leave_idle_building()
		if is_dead(): return
	indoor_idle = false
	idle_entrance_target = null
	if job == Job.HUNTER: hunting.release_target(self)
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
	var target_position: Vector3 = rest_home.get_entrance_position()
	navigation_agent.target_position = target_position
	state = State.NEED_REST
	rest_previous_target_distance = navigation_agent.target_desired_distance
	navigation_agent.target_desired_distance = 0.2


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
	if indoor_building is Watchtower:
		_leave_watch_to_eat()
		return true
	if job == Job.HUNTER: hunting.release_target(self)

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


func _leave_watch_to_eat() -> void:
	await _leave_idle_building()
	if is_dead(): return
	if not begin_eating() and is_instance_valid(workplace): workplace.resume_worker(self)

func move_to_rest() -> void:
	if not is_instance_valid(rest_home) or rest_home.is_queued_for_deletion():
		return_to_idle()
		return
	if indoor_building != rest_home and not rest_home.is_at_entrance_front(global_position):
		navigation_agent.target_desired_distance = 0.2
		move_along_navigation()
		return
	if indoor_building != rest_home:
		if not await _pass_building_door(rest_home, true):
			return_to_idle()
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
	_apply_food_nutrition(food_data)

	if hunger > SATIATED_HUNGER_THRESHOLD:
		selected_food_id = choose_food(base_storage)
		eating_timer = 0.0
	else:
		selected_food_id = &""


func _resume_after_rest() -> void:
	resting_timer = 0.0
	await _leave_idle_building()
	if is_dead(): return
	rest_home = null
	navigation_agent.target_desired_distance = rest_previous_target_distance
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
	_apply_food_nutrition(food_data)
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
var job: Job = Job.NONE:
	set(value):
		job = value
		_update_work_clothing()
# 当前工作建筑
var workplace: Node3D = null
# 当前是否正在执行工作建筑 → Base 的运输任务
var is_transporting: bool = false

# 当前公共任务
var current_task: Object = null
var loot_bundle_target: Node3D = null
var loot_pickup_position: Vector3 = Vector3.INF
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
	if unit_data == null:
		unit_data = ARCHER_DATA if combat_role == CombatRole.Type.ARCHER else (SWORDSMAN_DATA if combat_role == CombatRole.Type.SWORDSMAN else RESIDENT_DATA)
	_apply_unit_parameters()
	super._ready()
	if character_name.is_empty():
		var names = preload("res://Script/unit/character_names.gd")
		character_name = names.assign(self, names.HUMAN_POOL, unit_data.fixed_name)
	idle_reposition_timer = randf_range(3.0, 10.0)
	_update_combat_visual()
	_create_aggro_range_display()
	_create_unreachable_marker()
	input_event.connect(_on_input_event)
	call_deferred("start")


func _create_aggro_range_display() -> void:
	var range_display: MeshInstance3D = MeshInstance3D.new()
	range_display.name = "SwordsmanAggroRange"
	range_display.set_script(preload("res://Script/combat/aggro_range_3d.gd"))
	range_display.set("radius", combat_detection_range)
	range_display.set("ring_color", Color(0.1, 1.0, 0.2, 0.45))
	range_display.set("combat_only", true)
	range_display.position.y = 0.03
	add_child(range_display)


func _create_unreachable_marker() -> void:
	unreachable_marker = Label3D.new()
	unreachable_marker.name = "UnreachableMarker"
	unreachable_marker.text = "!"
	unreachable_marker.modulate = Color(1.0, 0.85, 0.1)
	unreachable_marker.outline_modulate = Color(0.2, 0.15, 0.02)
	unreachable_marker.outline_size = 12
	unreachable_marker.font_size = 128
	unreachable_marker.pixel_size = 0.008
	unreachable_marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	unreachable_marker.no_depth_test = true
	unreachable_marker.position.y = 2.5
	unreachable_marker.visible = false
	add_child(unreachable_marker)


func _on_unit_died(_source: Node) -> void:
	if is_instance_valid(door_building): door_building.release_door(self)
	if is_instance_valid(shelter_target): shelter_target.release_shelter(self)
	hunting.release_target(self)
	hunting.clear_bundle()
	_set_unreachable_warning(false)
	remove_from_group("villagers")
	remove_from_group("combat_units")
	var population_manager: Node = get_tree().get_first_node_in_group(
		"population_manager"
	)
	if population_manager != null and population_manager.has_method(
		"refresh_population"
	):
		population_manager.refresh_population()
	for building: Node in get_tree().get_nodes_in_group("buildings"):
		if building.has_method("remove_unit_from_rosters"):
			building.remove_unit_from_rosters(self)
	

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

	set_meta("selection_double_click", mouse_event.double_click)
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
	if job == Job.NONE and not leaving_immigration_base:
		return_to_idle()
# ============================================================
# 主循环
# ============================================================

func _physics_process(delta):
	yield_cooldown = maxf(yield_cooldown - delta, 0.0)
	preload("res://Script/unit/unit_facing.gd").update(visual_root if is_instance_valid(visual_instance) else body_mesh, delta)
	if passing_door or construction_repositioning:
		velocity = Vector3.ZERO
		return
	if state == State.WATCHING:
		velocity = Vector3.ZERO
		update_needs(delta)
		evaluate_needs()
		return
	if hunting.inside_processing:
		update_needs(delta)
		if is_instance_valid(workplace) and _civilian_alarm_required():
			hunting.inside_processing = false
			_pass_building_door(workplace, false)
			return
		hunting.process(self, delta)
		return
	if leaving_immigration_base:
		velocity = Vector3.ZERO
		return
	if indoor_idle and is_instance_valid(indoor_building):
		velocity = Vector3.ZERO
		update_needs(delta)
		if current_task != null:
			_start_current_task()
		elif job != Job.NONE:
			_leave_idle_for_job()
		elif state not in [State.IDLE, State.RETURN_TO_IDLE] or has_combat_role() and _find_nearest_hostile() != null:
			_leave_idle_building()
		elif is_tired():
			begin_resting()
		elif is_hungry():
			_leave_idle_for_food()
		else:
			idle_reposition_timer -= delta
			if idle_reposition_timer <= 0.0:
				idle_reposition_timer = 3.0
				target_base.idle_space.refresh(target_base)
				if not target_base.idle_space.indoors:
					_leave_idle_and_reposition()
		return
	if indoor_building != null and (not is_instance_valid(indoor_building) or indoor_building.is_queued_for_deletion()):
		indoor_building = null
		indoor_idle = false
		visible = true
		collision_layer = 2
		collision_mask = 3
		return_to_idle()
	if state == State.RESTING and is_instance_valid(indoor_building):
		update_needs(delta)
		rest(delta)
		return
	if is_stunned():
		stun_remaining = maxf(stun_remaining - delta, 0.0)
		velocity = Vector3.ZERO
		update_needs(delta)
		return
	if external_force.length_squared() > 0.01:
		velocity = external_force
		move_and_slide()
		external_force = external_force.move_toward(Vector3.ZERO, 20.0 * delta)
		return
	if ranged_shot_remaining > 0.0:
		ranged_shot_remaining = maxf(ranged_shot_remaining - delta, 0.0)
		combat_attack_cooldown = maxf(combat_attack_cooldown - delta, 0.0)
		velocity = Vector3.ZERO
		update_needs(delta)
		return
	if _process_civilian_retreat(delta):
		return
	if _process_combat(delta):
		return
	if is_instance_valid(treasure_camp):
		update_needs(delta)
		_process_treasure_hunt()
		return
	if is_instance_valid(relocated_building) and state not in [State.MOVE_TO_BASE, State.DEPOSIT_TO_BASE, State.NEED_EAT, State.MOVE_TO_EAT, State.EATING, State.NEED_REST, State.MOVE_TO_REST, State.RESTING]:
		update_needs(delta)
		_process_building_relocation()
		return
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
		State.MOVE_TO_ROAD, State.BUILD_ROAD:
			_process_road_construction(delta)
		State.MOVE_TO_REPAIR, State.REPAIRING:
			_process_building_repair(delta)
		State.HUNTING:
			hunting.process(self, delta)

		State.IDLE:
			velocity = Vector3.ZERO
			process_idle_reposition(delta)

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
			process_garrison_needs()

		State.GARRISON_EATING:
			process_garrison_eating(delta)

		State.GARRISON_RESTING:
			process_garrison_resting(delta)

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

		State.COMBAT_MOVE, State.COMBAT_ATTACK:
			_process_combat(delta)

		State.MOVE_TO_DEMOLITION:
			move_to_demolition()

		State.DEMOLISHING:
			velocity = Vector3.ZERO

		State.MOVE_TO_DEMOLITION_BASE:
			move_to_demolition_base()

		State.DEPOSIT_DEMOLITION_TO_BASE:
			deposit_demolition_to_base()

		State.MOVE_TO_LOOT:
			move_to_loot_bundle()

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

	_update_unreachable_warning(delta)


func _update_unreachable_warning(delta: float) -> void:
	idle_warning_elapsed = idle_warning_elapsed + delta if _needs_idle_warning() else 0.0
	if state == State.RETURN_TO_IDLE and job == Job.NONE:
		unreachable_time = 0.0
		_set_unreachable_warning(false)
		return
	if state != unreachable_state:
		unreachable_state = state
		unreachable_time = 0.0
		_set_unreachable_warning(false)
	var moving_to_work: bool = state in [
		State.MOVE_TO_TASK_SOURCE, State.MOVE_TO_TASK_SITE,
		State.MOVE_TO_BUILD_SITE, State.MOVE_TO_ROAD, State.WAIT_CONSTRUCTION_SITE,
		State.MOVE_TO_DEMOLITION, State.MOVE_TO_WORKPLACE,
		State.MOVE_TO_RESOURCE, State.MOVE_TO_FIELD,
		State.MOVE_TO_BASE, State.MOVE_TO_DEMOLITION_BASE,
		State.MOVE_TO_TRAINING, State.MOVE_TO_BARRACKS,
		State.MOVE_TO_LOOT, State.RETURN_TO_IDLE, State.MOVE_TO_REPAIR
	]
	if not moving_to_work or is_dead():
		_set_unreachable_warning(false)
		unreachable_time = 0.0
		return
	var target: Vector3 = navigation_agent.target_position
	if target.distance_to(unreachable_target_position) > 0.5:
		unreachable_target_position = target
		unreachable_last_position = global_position
		unreachable_time = 0.0
		_set_unreachable_warning(false)
		return
	if global_position.distance_to(unreachable_last_position) >= 0.2:
		unreachable_last_position = global_position
		unreachable_time = 0.0
		_set_unreachable_warning(false)
		return
	var remaining: Vector3 = target - global_position
	remaining.y = 0.0
	if remaining.length() <= navigation_agent.target_desired_distance + 0.5:
		unreachable_time = 0.0
		_set_unreachable_warning(false)
		return
	unreachable_time += delta
	if unreachable_time >= 5.0:
		_set_unreachable_warning(true)


func _set_unreachable_warning(active: bool) -> void:
	unreachable_warning = active
	if unreachable_marker != null:
		var attention: bool = active or has_idle_warning()
		if bool(unreachable_marker.get_meta("fog_visible", false)) != attention:
			unreachable_marker.set_meta("fog_visible", attention)
		unreachable_marker.visible = attention and not bool(get_meta("fog_hidden", false))


func has_idle_warning() -> bool:
	return idle_warning_elapsed >= 5.0 and _needs_idle_warning()


func _needs_idle_warning() -> bool:
	if indoor_idle or state in [State.NEED_REST, State.MOVE_TO_REST, State.RESTING]: return false
	if is_dead() or is_queued_for_deletion(): return false
	if state == State.WAIT_CONSTRUCTION_SITE:
		if task_site is ConstructionSite and task_site.state == ConstructionSite.State.WAITING_RESOURCES:
			return false
		return _has_reached_task_site_navigation_target()
	if state == State.WAIT_TASK_RESOURCE: return true
	if state != State.IDLE: return false
	# 有职业或任务却没有实际工作时，需要提醒；据点普通待命除外。
	if job != Job.NONE or is_instance_valid(workplace) or current_task != null: return true
	if not is_instance_valid(target_base): return true
	return (
		Vector2(global_position.x - target_base.global_position.x, global_position.z - target_base.global_position.z).length() > target_base.idle_radius
		or absf(global_position.y - target_base.global_position.y) > 1.0
	)


func has_unreachable_warning() -> bool:
	return unreachable_warning


func is_waiting_for_crop() -> bool:
	if state != State.IDLE or job != Job.FARMER or not workplace is Farm:
		return false
	if workplace.has_available_field() or workplace.should_transport_grain():
		return false
	for child: Node in workplace.get_children():
		if child is FarmField and child.state == FarmField.State.GROWING:
			return true
	return false


func _process_combat(delta: float) -> bool:
	# 箭塔补粮员完成往返，由留在塔上的弓箭手负责射击。
	if is_instance_valid(resupply_barracks) and resupply_barracks.has_method("allows_garrison_attacks"):
		return false
	if not has_combat_role() and not is_hunter():
		return false
	if is_dead():
		return false
	if is_instance_valid(garrisoned_in):
		if garrisoned_in.has_method("allows_garrison_attacks"):
			_process_tower_combat(delta)
			return false
		# 驻军在建筑内部保持隐藏和战备，不能隔着军营搜索并攻击敌人。
		# 同时修复旧逻辑留下的“仍属于军营但状态变成 IDLE”的幽灵剑士。
		if (
			state != State.GARRISONED
			and state != State.GARRISON_EATING
			and state != State.GARRISON_RESTING
		):
			state = State.GARRISONED
		visible = false
		collision_layer = 0
		collision_mask = 0
		combat_target = null
		combat_resume_state = -1
		combat_resume_target_position = Vector3.ZERO
		combat_resume_navigation_target = Vector3.ZERO
		velocity = Vector3.ZERO
		return false
	var combat_state: bool = (
		state == State.COMBAT_MOVE
		or state == State.COMBAT_ATTACK
	)

	if (
		combat_target == null
		or not is_instance_valid(combat_target)
		or combat_target.is_queued_for_deletion()
		or not combat_target.is_visible_in_tree()
		or combat_target.has_method("is_dead") and combat_target.is_dead()
		or unit_data.uses_arrows and Vector2(global_position.x - combat_target.global_position.x, global_position.z - combat_target.global_position.z).length() > combat_detection_range
	):
		combat_target = _find_retreat_threat()
		if combat_target == null: combat_target = _find_nearest_hostile()
		if combat_target == null:
			if combat_state:
				_finish_combat()
			return false
		if combat_resume_state < 0:
			combat_resume_state = int(state)
			combat_resume_target_position = patrol_target_position
			combat_resume_navigation_target = navigation_agent.target_position
		combat_attack_cooldown = 0.0
		print("⚔️ 战斗：剑士切换目标：", combat_target.name)

	var target_position: Vector3 = combat_target.global_position
	var flat_target: Vector3 = Vector3(
		target_position.x,
		global_position.y,
		target_position.z
	)
	var distance: float = global_position.distance_to(flat_target)
	if unit_data.uses_arrows:
		return _process_ranged_retreat(delta, distance)
	if distance > combat_attack_range:
		state = State.COMBAT_MOVE
		if navigation_agent.target_position.distance_squared_to(target_position) > 0.25:
			navigation_agent.target_position = target_position
		var next_position: Vector3 = road_navigation.next_position(self, navigation_agent)
		velocity = global_position.direction_to(next_position) * get_move_speed()
		_face_direction(velocity)
		move_and_slide()
		return true

	state = State.COMBAT_ATTACK
	velocity = Vector3.ZERO
	_face_direction(target_position - global_position)
	combat_attack_cooldown = maxf(combat_attack_cooldown - delta, 0.0)
	if combat_attack_cooldown > 0.0:
		return true
	if combat_target.has_method("take_damage"):
		var actual_damage: float = float(
			combat_target.take_damage(combat_damage, self)
		)
		print(
			"⚔️ 战斗：剑士攻击 %s，造成 %.1f 伤害"
			% [combat_target.name, actual_damage]
		)
	combat_attack_cooldown = combat_attack_interval
	return true


func _process_ranged_retreat(delta: float, distance: float) -> bool:
	combat_attack_cooldown = maxf(combat_attack_cooldown - delta, 0.0)
	if distance <= combat_attack_range and combat_attack_cooldown <= 0.0:
		state = State.COMBAT_ATTACK
		fire_arrow(combat_target)
		combat_attack_cooldown = combat_attack_interval
		return true
	if not is_instance_valid(target_base): find_base()
	state = State.COMBAT_MOVE
	if not is_instance_valid(target_base):
		velocity = Vector3.ZERO
		return true
	var destination: Vector3 = NavigationServer3D.map_get_closest_point(navigation_agent.get_navigation_map(), target_base.get_interaction_position(self))
	if navigation_agent.target_position.distance_squared_to(destination) > 0.25:
		navigation_agent.target_position = destination
	var offset: Vector3 = destination - global_position
	offset.y = 0.0
	if offset.length() > navigation_agent.target_desired_distance + 0.5:
		move_along_navigation()
	else:
		velocity = Vector3.ZERO
	return true


func _find_retreat_threat() -> Node3D:
	if combat_role != CombatRole.Type.SWORDSMAN: return null
	var nearest: Node3D
	var distance: float = combat_detection_range
	for resident: Node in get_tree().get_nodes_in_group("villagers"):
		if resident == self or resident.state != State.RETREAT_TO_BASE or not resident.is_visible_in_tree(): continue
		if not is_instance_valid(resident.retreat_threat): continue
		var threat: Node3D = resident.retreat_threat
		if threat.is_queued_for_deletion() or threat.is_dead() or not threat.is_visible_in_tree(): continue
		if not EnemyData.are_factions_hostile(get_faction(), threat.get_faction()): continue
		var candidate_distance: float = Vector2(resident.global_position.x - global_position.x, resident.global_position.z - global_position.z).length()
		if candidate_distance < distance:
			distance = candidate_distance
			nearest = threat
	return nearest


func _find_nearest_hostile(search_range: float = -1.0) -> Node3D:
	var nearest: Node3D = null
	var nearest_distance: float = combat_detection_range if search_range < 0.0 else search_range
	for candidate: Node in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(candidate) or not candidate is Node3D or candidate.is_queued_for_deletion():
			continue
		if candidate.has_method("is_dead") and candidate.is_dead():
			continue
		if not candidate.is_visible_in_tree():
			continue
		if candidate.has_method("get_faction") and not EnemyData.are_factions_hostile(get_faction(), int(candidate.get_faction())):
			continue
		var candidate_node: Node3D = candidate as Node3D
		var distance: float = Vector2(global_position.x, global_position.z).distance_to(Vector2(candidate_node.global_position.x, candidate_node.global_position.z))
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = candidate_node
	return nearest


func fire_arrow(target: Node3D) -> void:
	velocity = Vector3.ZERO
	ranged_shot_remaining = 0.3
	_face_direction(target.global_position - global_position)
	var damage: float = ARCHER_DATA.damage * 0.5 if is_hunter() and target.is_in_group("enemies") else combat_damage
	ARROW_SCRIPT.launch(self, target, global_position + Vector3.UP, damage, unit_data.arrow_speed)


func is_hunter() -> bool:
	return job == Job.HUNTER


func get_damage_protector() -> Node3D:
	if state == State.WATCHING and indoor_building is Watchtower and not indoor_building.is_destroyed(): return indoor_building
	if state == State.SHELTERED and not visible and is_instance_valid(shelter_target) and not shelter_target.is_destroyed() and not shelter_target.is_queued_for_deletion():
		return shelter_target
	if (
		is_instance_valid(garrisoned_in)
		and not garrisoned_in.is_queued_for_deletion()
		and not garrisoned_in.is_destroyed()
		and garrisoned_in.has_method("allows_garrison_attacks")
		and garrisoned_in.allows_garrison_attacks()
	):
		return garrisoned_in as Node3D
	return null


func take_damage(amount: float, source: Node = null) -> float:
	if get_damage_protector() != null:
		return 0.0
	var damage: float = super.take_damage(amount, source)
	if damage > 0.0 and not is_dead() and not has_combat_role() and job != Job.WATCHER:
		retreat_safe_at_msec = Time.get_ticks_msec() + 5000
		_begin_civilian_retreat(source as Node3D)
	return damage


func _begin_civilian_retreat(threat: Node3D = null) -> void:
	if is_instance_valid(threat): retreat_threat = threat
	if state == State.RETREAT_TO_BASE:
		return
	if state == State.SHELTERED: return
	find_base()
	var previous_site: Node = task_site
	_release_current_task_for_needs()
	if is_instance_valid(previous_site) and previous_site.has_method("remove_construction_worker"):
		previous_site.remove_construction_worker(self)
	if is_instance_valid(construction_cancellation_target) and not construction_cancellation_target.cancellation_carriers.has(self):
		construction_cancellation_target.cancellation_workers.erase(self)
		construction_cancellation_target.returning_cancellation_workers.erase(self)
		construction_cancellation_target = null
	if is_instance_valid(demolition_target):
		# 已装载的拆除返料保留归属，回到据点后继续原来的卸货流程。
		var is_carrier: bool = demolition_target.cancellation_carriers.has(self) if demolition_target is ConstructionSite else demolition_target.demolition_carrier == self
		if not is_carrier:
			demolition_target.demolition_workers.erase(self)
			demolition_target = null
	if is_instance_valid(target_resource):
		target_resource.release(self)
		target_resource = null
	release_target_field()
	hunting.release_target(self)
	loot_bundle_target = null
	_select_retreat_destination()
	state = State.RETREAT_TO_BASE


func _select_retreat_destination(excluded: BuildingBase = null) -> void:
	if is_instance_valid(shelter_target): shelter_target.release_shelter(self)
	shelter_target = null
	if not is_instance_valid(target_base): find_base()
	var home: BuildingBase = home_building
	if not is_instance_valid(home) or home == excluded or home.is_destroyed() or home.is_queued_for_deletion() or home.is_demolition_in_progress(): home = target_base
	if not is_instance_valid(home) or home.is_destroyed() or home.is_queued_for_deletion(): return
	shelter_target = home
	if not home.shelter_residents.has(self): home.shelter_residents.append(self)
	navigation_agent.target_position = _get_reachable_building_entrance(home)


func _pass_building_door(building: BuildingBase, entering: bool) -> bool:
	passing_door = true
	door_building = building
	building.join_door_queue(self)
	while is_instance_valid(building) and not building.is_queued_for_deletion() and not building.has_door_turn(self):
		await get_tree().physics_frame
		if is_dead():
			building.release_door(self)
			passing_door = false
			return false
	if not is_instance_valid(building) or building.is_queued_for_deletion():
		passing_door = false
		visible = true
		collision_layer = 2
		collision_mask = 3
		return false
	collision_layer = 0
	collision_mask = 0
	visible = true
	var destination: Vector3 = building.get_interior_position() if entering else building.get_entrance_position()
	_face_direction(destination - global_position)
	var tween: Tween = create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	if entering:
		var entrance: Vector3 = building.get_entrance_position()
		tween.tween_property(self, "global_position", entrance, maxf(global_position.distance_to(entrance) / get_move_speed(), 0.05))
	if building is Watchtower:
		var foot: Vector3 = building.get_node("ClimbFoot").global_position
		tween.tween_property(self, "global_position", foot, maxf(global_position.distance_to(foot) / get_move_speed(), 0.2))
	tween.tween_property(self, "global_position", destination, maxf(global_position.distance_to(destination) / get_move_speed(), 0.2))
	await tween.finished
	if is_instance_valid(building): building.release_door(self)
	door_building = null
	passing_door = false
	if is_dead(): return false
	var survived: bool = is_instance_valid(building) and not building.is_queued_for_deletion()
	visible = not entering or not survived or building is Watchtower
	collision_layer = 0 if entering and survived else 2
	collision_mask = 0 if entering and survived else 3
	if entering and survived:
		indoor_building = building
		building.add_indoor_resident(self)
	else:
		if is_instance_valid(indoor_building): indoor_building.remove_indoor_resident(self)
		indoor_building = null
	_refresh_health_bar_display()
	return survived


func _leave_shelter() -> void:
	var building: BuildingBase = shelter_target
	if is_instance_valid(building) and not building.is_queued_for_deletion():
		await _pass_building_door(building, false)
	if is_dead(): return
	if is_instance_valid(shelter_target): shelter_target.release_shelter(self)
	shelter_target = null
	visible = true
	collision_layer = 2
	collision_mask = 3
	_refresh_health_bar_display()
	state = State.RETREAT_TO_BASE


func _exit_shelter_and_resume(reselect: bool = false) -> void:
	await _leave_shelter()
	if is_dead(): return
	if reselect: _select_retreat_destination()
	else: _resume_after_retreat()


func _enter_shelter() -> void:
	state = State.SHELTERED
	if not await _pass_building_door(shelter_target, true):
		if not is_dead():
			state = State.RETREAT_TO_BASE
			_select_retreat_destination()


func _resume_after_retreat(at_base: bool = false) -> void:
	retreat_threat = null
	if is_instance_valid(demolition_target):
		if at_base:
			state = State.DEPOSIT_DEMOLITION_TO_BASE
		else:
			navigation_agent.target_position = target_base.get_interaction_position(self)
			state = State.MOVE_TO_DEMOLITION_BASE
	elif carried_amount > 0.0:
		if at_base: state = State.DEPOSIT_TO_BASE
		else: go_to_base()
	elif is_hunter() and is_instance_valid(workplace):
		hunting.request_return(self)
	elif is_instance_valid(workplace) and job != Job.NONE:
		start_current_job()
	else:
		if not is_instance_valid(workplace): job = Job.NONE
		return_to_idle()


func _civilian_alarm_required(ignore_protection: bool = false) -> bool:
	if Time.get_ticks_msec() < retreat_safe_at_msec: return true
	if is_instance_valid(retreat_threat) and not retreat_threat.is_queued_for_deletion() and (not retreat_threat.has_method("is_dead") or not retreat_threat.is_dead()):
		if Vector2(retreat_threat.global_position.x - global_position.x, retreat_threat.global_position.z - global_position.z).length_squared() <= combat_detection_range * combat_detection_range: return true
	if not is_instance_valid(settlement_alarm): settlement_alarm = get_tree().get_first_node_in_group("settlement_alarm")
	return is_instance_valid(settlement_alarm) and settlement_alarm.alarming and (ignore_protection or not settlement_alarm.is_protected(global_position))

func _process_civilian_retreat(delta: float) -> bool:
	if is_dead() or job == Job.WATCHER: return false
	if current_task is GameTask and current_task.type == GameTask.TaskType.TRAIN_SWORDSMAN: return false
	if state == State.SHELTERED:
		update_needs(delta)
		if not is_instance_valid(shelter_target) or shelter_target.is_destroyed() or shelter_target.is_queued_for_deletion() or shelter_target.is_demolition_in_progress():
			_exit_shelter_and_resume(true)
		elif not _civilian_alarm_required(true):
			_exit_shelter_and_resume()
		return true
	if has_combat_role() or is_dead() or not is_visible_in_tree():
		return false
	if _civilian_alarm_required():
		_begin_civilian_retreat()
	if state != State.RETREAT_TO_BASE:
		return false
	update_needs(delta)
	combat_attack_cooldown = maxf(combat_attack_cooldown - delta, 0.0)
	if shelter_target != null and (not is_instance_valid(shelter_target) or shelter_target.is_destroyed() or shelter_target.is_queued_for_deletion() or shelter_target.is_demolition_in_progress()):
		_select_retreat_destination(shelter_target if is_instance_valid(shelter_target) else null)
	if not is_instance_valid(target_base) and not is_instance_valid(shelter_target):
		velocity = Vector3.ZERO
		find_base()
		if is_instance_valid(target_base):
			navigation_agent.target_position = target_base.get_interaction_position(self)
		return true
	var offset: Vector3 = navigation_agent.target_position - global_position
	offset.y = 0.0
	var reached_shelter: bool = shelter_target.is_at_entrance_front(global_position) if is_instance_valid(shelter_target) else offset.length() <= navigation_agent.target_desired_distance + 0.5
	if not reached_shelter and is_instance_valid(shelter_target) and offset.length() <= 0.35 and shelter_target.is_at_entrance_front(navigation_agent.target_position):
		reached_shelter = shelter_target.is_at_entrance_front(global_position, 0.35)
	if not reached_shelter:
		if navigation_agent.is_navigation_finished() and Time.get_ticks_msec() >= shelter_repath_msec:
			shelter_repath_msec = Time.get_ticks_msec() + 500
			_select_retreat_destination()
		move_along_navigation()
		return true
	velocity = Vector3.ZERO
	if is_instance_valid(shelter_target):
		shelter_exit_position = global_position
		_enter_shelter()
		return true
	if _civilian_alarm_required():
		return true
	_resume_after_retreat(true)
	return true


func _process_tower_combat(delta: float) -> void:
	combat_attack_cooldown = maxf(combat_attack_cooldown - delta, 0.0)
	if state != State.GARRISONED: return
	var range: float = combat_attack_range * garrisoned_in.attack_range_multiplier
	var target: Node3D = _find_nearest_hostile(range)
	if target != null:
		_face_direction(target.global_position - global_position)
		tower_look_timer = 2.0
		if combat_attack_cooldown <= 0.0:
			fire_arrow(target)
			combat_attack_cooldown = combat_attack_interval
	else:
		tower_look_timer -= delta
		if tower_look_timer <= 0.0:
			var visual: Node3D = visual_root if is_instance_valid(visual_instance) else body_mesh
			var yaw: float = visual.global_rotation.y + PI / 2.0
			_face_direction(Vector3(sin(yaw), 0.0, cos(yaw)))
			tower_look_timer = 2.0


func _finish_combat() -> void:
	if combat_target != null:
		print("⚔️ 战斗：剑士目标结束，恢复之前的军事任务")
	var resume_state: int = combat_resume_state
	var resume_target: Vector3 = combat_resume_target_position
	var resume_navigation_target: Vector3 = combat_resume_navigation_target
	combat_target = null
	combat_resume_state = -1
	combat_resume_target_position = Vector3.ZERO
	combat_resume_navigation_target = Vector3.ZERO
	combat_attack_cooldown = 0.0
	velocity = Vector3.ZERO
	if is_hunter():
		state = resume_state if resume_state >= 0 else State.HUNTING
		navigation_agent.target_position = resume_navigation_target
		return
	if resume_state == State.MOVE_TO_BARRACKS:
		if is_instance_valid(garrison_target) and not garrison_target.is_demolition_in_progress():
			navigation_agent.target_position = resume_navigation_target
			collision_mask = 3
			state = State.MOVE_TO_BARRACKS
			return
		if is_instance_valid(garrison_target):
			garrison_target.unregister_garrison(self)
		garrison_target = null
	if resume_state == State.PATROLLING or resume_state == State.MOVE_TO_PATROL_POINT:
		patrol_target_position = resume_target
		navigation_agent.target_position = resume_target
		state = State.MOVE_TO_PATROL_POINT
		return
	if resume_state == State.MOVE_TO_PATROL_ASSEMBLE:
		navigation_agent.target_position = resume_navigation_target
		state = State.MOVE_TO_PATROL_ASSEMBLE
		return
	if resume_state == State.PATROL_ASSEMBLING:
		state = State.PATROL_ASSEMBLING
		return
	if resume_state == State.RETURN_TO_BARRACKS:
		navigation_agent.target_position = resume_navigation_target
		state = State.RETURN_TO_BARRACKS
		return
	state = State.IDLE
	return_to_idle()


func can_accept_treasure_hunt() -> bool:
	return (
		has_combat_role() and not is_dead() and not is_stunned() and not is_instance_valid(treasure_camp)
		and current_task == null and carried_amount <= 0.0
		and not is_quitting_job and not abandoning_work
		and state in [State.IDLE, State.RETURN_TO_IDLE, State.GARRISONED,
			State.MOVE_TO_PATROL_POINT, State.PATROLLING, State.RETURN_TO_BARRACKS]
	)


func begin_treasure_hunt(camp: Node3D) -> bool:
	if not can_accept_treasure_hunt():
		return false
	treasure_resume = {
		"state": state, "navigation": navigation_agent.target_position,
		"garrison": garrisoned_in, "target_distance": navigation_agent.target_desired_distance,
		"collision_mask": collision_mask
	}
	if is_instance_valid(garrisoned_in):
		garrisoned_in.unregister_garrison(self)
		if garrisoned_in.has_method("get_garrison_entrance_position"):
			global_position = garrisoned_in.get_garrison_entrance_position(self)
		garrisoned_in = null
		garrison_target = null
		visible = true
		collision_layer = 2
		_refresh_health_bar_display()
	treasure_camp = camp
	collision_mask = 1
	navigation_agent.target_desired_distance = 1.0
	navigation_agent.target_position = camp.global_position
	state = State.IDLE
	return true


func _process_treasure_hunt() -> void:
	if treasure_camp.cleared:
		treasure_camp.remove_participant(self)
		return
	var destination: Vector3 = treasure_camp.global_position
	var nearest_distance: float = INF
	for guard: Node3D in treasure_camp.get_living_guards():
		var distance: float = global_position.distance_squared_to(guard.global_position)
		if distance < nearest_distance:
			nearest_distance = distance
			destination = guard.global_position
	if navigation_agent.target_position.distance_to(destination) > 0.5:
		navigation_agent.target_position = destination
	if not navigation_agent.is_navigation_finished():
		move_along_navigation()
	else:
		velocity = Vector3.ZERO


func finish_treasure_hunt(camp: Node3D) -> void:
	if treasure_camp != camp:
		return
	treasure_camp = null
	combat_target = null
	combat_resume_state = -1
	navigation_agent.target_desired_distance = float(treasure_resume["target_distance"])
	# 驻军原碰撞掩码为0，离营往返途中仍需要与障碍碰撞。
	collision_mask = 3 if treasure_resume["garrison"] != null else int(treasure_resume["collision_mask"])
	if is_dead() or not is_inside_tree() or (get_tree().current_scene != null and get_tree().current_scene.is_queued_for_deletion()):
		treasure_resume.clear()
		return
	var previous_garrison: Node = treasure_resume["garrison"] as Node
	var previous_state: int = int(treasure_resume["state"])
	var previous_navigation: Vector3 = treasure_resume["navigation"]
	treasure_resume.clear()
	state = State.IDLE
	if is_instance_valid(previous_garrison) and try_assign_to_barracks(previous_garrison):
		return
	if is_instance_valid(patrol_barracks):
		navigation_agent.target_position = previous_navigation
		state = State.MOVE_TO_PATROL_POINT if previous_state == State.PATROLLING else previous_state as State
		return
	return_to_idle()


func _start_current_task() -> void:
	var task: GameTask = current_task as GameTask
	if task == null:
		return
	if indoor_idle and is_instance_valid(indoor_building):
		await _leave_idle_building()
		if is_dead() or current_task != task: return

	if task.type == GameTask.TaskType.BUILD_ROAD:
		task.state = GameTask.State.IN_PROGRESS
		state = State.MOVE_TO_ROAD
		road_previous_target_distance = navigation_agent.target_desired_distance
		navigation_agent.target_desired_distance = 0.25
		navigation_agent.target_position = task.data.position
		return

	if task.type == GameTask.TaskType.REPAIR_BUILDING:
		task.state = GameTask.State.IN_PROGRESS
		task_site = task.target as Node3D
		if not is_instance_valid(task_site):
			_release_current_task()
			return
		_set_task_site_navigation_target()
		state = State.MOVE_TO_REPAIR
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
		navigation_agent.target_position = _get_reachable_building_entrance(task_site)
		state = State.MOVE_TO_TRAINING
		print("Villager 前往训练：", task.id, " target=", task_site.name)
		return

	if task.type == GameTask.TaskType.PICKUP_LOOT:
		task.state = GameTask.State.IN_PROGRESS
		loot_bundle_target = task.target as Node3D
		if not is_instance_valid(loot_bundle_target):
			_release_current_task()
			return
		loot_pickup_position = NavigationServer3D.map_get_closest_point(
			navigation_agent.get_navigation_map(), loot_bundle_target.global_position
		)
		navigation_agent.target_position = loot_pickup_position
		state = State.MOVE_TO_LOOT
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
	var source_delta: Vector3 = navigation_agent.target_position - global_position
	source_delta.y = 0.0
	if source_delta.length() > navigation_agent.target_desired_distance + 0.5:
		velocity = Vector3.ZERO
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
	if task_site is ConstructionSite:
		if target_delta.length() > 0.35: return false
		var obstacle: ResourceBase = task_site.get_blocking_resource()
		if obstacle != null: return obstacle.is_in_gather_range(global_position)
		if task_site.exterior_construction_started: return true
		if task_site.has_model_bounds:
			var point: Vector3 = task_site.to_local(global_position)
			var bounds: AABB = task_site.model_bounds
			return point.x >= bounds.position.x and point.x <= bounds.end.x and point.z >= bounds.position.z and point.z <= bounds.end.z
		return true
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


func move_to_construction_position(site: ConstructionSite, destination: Vector3) -> void:
	construction_repositioning = true
	velocity = Vector3.ZERO
	collision_layer = 0
	collision_mask = 0
	_face_direction(destination - global_position)
	var tween: Tween = create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.tween_property(self, "global_position", destination, maxf(global_position.distance_to(destination) / get_move_speed(), 0.2))
	await tween.finished
	construction_repositioning = false
	if is_dead(): return
	collision_layer = 2
	collision_mask = 3
	if not is_instance_valid(site) or task_site != site:
		return_to_idle()
	else:
		_face_direction(site.global_position - global_position)


func move_to_build_site() -> void:

	if not is_instance_valid(task_site):
		_release_current_task()
		return

	var reached_site: bool = _has_reached_task_site_navigation_target()
	if not reached_site:
		if navigation_agent.is_navigation_finished():
			_set_task_site_navigation_target()
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
	if task_site is ConstructionSite and task_site.exterior_construction_started:
		_face_direction(task_site.global_position - global_position)
	print("Villager 已加入施工：", task.id)


func _process_road_construction(delta: float) -> void:
	var task: GameTask = current_task as GameTask
	if task == null or not is_instance_valid(task.target):
		_release_current_task()
		return
	if not task.target.can_work_cell(task.data.cell):
		task.target.work_cell(task, self, 0.0)
		return
	if global_position.distance_to(task.data.position) > 0.65:
		if navigation_agent.is_navigation_finished():
			var map: RID = navigation_agent.get_navigation_map()
			if task.target._path(map, global_position, task.data.position).is_empty():
				_release_current_task()
				return
		state = State.MOVE_TO_ROAD
		move_along_navigation()
		return
	state = State.BUILD_ROAD
	velocity = Vector3.ZERO
	task.target.work_cell(task, self, delta)


func move_to_training() -> void:
	if not is_instance_valid(task_site):
		_release_current_task()
		return
	if not task_site.is_at_entrance_front(global_position):
		if navigation_agent.is_navigation_finished():
			navigation_agent.target_position = _get_reachable_building_entrance(task_site)
		move_along_navigation()
		return

	var task: GameTask = current_task as GameTask
	if task == null or not task_site.has_method("begin_training"):
		_release_current_task()
		return
	var training_site: BuildingBase = task_site
	var entered: bool = await _pass_building_door(training_site, true)
	if current_task != task or task_site != training_site or is_dead():
		if entered and not is_dead() and indoor_building == training_site:
			await _pass_building_door(training_site, false)
			if not is_dead() and current_task == null: return_to_idle()
		return
	if not entered or not is_instance_valid(training_site) or training_site.is_queued_for_deletion():
		_release_current_task()
		return
	if not training_site.begin_training(self):
		_release_current_task()
		return
	training_elapsed = 0.0
	state = State.TRAINING
	print("Villager 开始训练：", task.id)


func leave_completed_training(building: BuildingBase) -> void:
	await _pass_building_door(building, false)
	if not is_dead():
		if carried_amount > 0.0: go_to_base()
		else: return_to_idle()


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
		or not has_combat_role()
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
	var entrance: Vector3 = garrison_target.get_garrison_entrance_position(self)
	if navigation_agent.target_position.distance_squared_to(entrance) > 0.01:
		navigation_agent.target_position = entrance
	navigation_agent.get_next_path_position()
	if not _has_reached_garrison_entry(garrison_target):
		if navigation_agent.is_navigation_finished():
			_repath_current_navigation_target()
		move_along_navigation()
		return
	if is_instance_valid(resupply_barracks):
		finish_barracks_resupply()
		return
	if garrison_target.has_method("enter_garrison"):
		garrison_target.enter_garrison(self)
		return
	enter_garrison(garrison_target)


func _has_reached_garrison_entry(barracks: Node) -> bool:
	if barracks is BuildingBase:
		return barracks.is_at_entrance_front(global_position)
	var reach_radius: float = 1.8
	if barracks != null and barracks.has_method("get_garrison_entry_reach_radius"):
		reach_radius = float(barracks.get_garrison_entry_reach_radius())
	var target_delta: Vector3 = navigation_agent.target_position - global_position
	target_delta.y = 0.0
	return target_delta.length() <= reach_radius


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
	if barracks.has_method("get_garrison_position"):
		global_position = barracks.get_garrison_position(self)
		visible = true


func process_garrison_needs() -> void:
	if state != State.GARRISONED or not is_instance_valid(garrisoned_in):
		return
	if hunger > SATIATED_HUNGER_THRESHOLD and begin_garrison_eating():
		return
	if fatigue > RESTED_THRESHOLD:
		state = State.GARRISON_RESTING


func process_garrison_resting(delta: float) -> void:
	if not is_instance_valid(garrisoned_in):
		state = State.IDLE
		return
	fatigue = clampf(fatigue - delta * rest_recovery_rate, 0.0, 100.0)
	velocity = Vector3.ZERO
	if fatigue <= RESTED_THRESHOLD:
		if hunger > SATIATED_HUNGER_THRESHOLD and begin_garrison_eating():
			return
		state = State.GARRISONED


func begin_garrison_eating() -> bool:
	if not is_instance_valid(garrisoned_in):
		return false
	if not garrisoned_in.has_method("get_food_resource_ids"):
		return false
	var food_ids: Array[StringName] = garrisoned_in.get_food_resource_ids()
	if food_ids.is_empty():
		return false
	selected_food_id = food_ids[0]
	for food_id: StringName in food_ids:
		if not _get_food_preferences(RESOURCE_DATABASE.get_resource_data(food_id)).is_empty():
			selected_food_id = food_id
			break
	eating_timer = 0.0
	state = State.GARRISON_EATING
	return true


func process_garrison_eating(delta: float) -> void:
	if not is_instance_valid(garrisoned_in):
		selected_food_id = &""
		eating_timer = 0.0
		state = State.IDLE
		return
	eating_timer += delta
	velocity = Vector3.ZERO
	if eating_timer < EATING_TIME:
		return
	var consumed_amount: float = 0.0
	if garrisoned_in.has_method("take_food"):
		consumed_amount = garrisoned_in.take_food(selected_food_id, 1.0)
	if consumed_amount <= 0.0:
		if begin_garrison_eating():
			return
		selected_food_id = &""
		eating_timer = 0.0
		state = State.GARRISONED
		return
	var food_data: ResourceData = RESOURCE_DATABASE.get_resource_data(selected_food_id)
	_apply_food_nutrition(food_data)
	if hunger > SATIATED_HUNGER_THRESHOLD:
		if begin_garrison_eating():
			return
	selected_food_id = &""
	eating_timer = 0.0
	state = State.GARRISONED


func is_garrisoned() -> bool:
	return (
		is_instance_valid(garrisoned_in)
		and (
			state == State.GARRISONED
			or state == State.GARRISON_EATING
			or state == State.GARRISON_RESTING
		)
	)


func is_ready_for_patrol() -> bool:
	return (
		is_instance_valid(garrisoned_in)
		and state == State.GARRISONED
		and hunger <= SATIATED_HUNGER_THRESHOLD
		and fatigue <= RESTED_THRESHOLD
	)


func begin_barracks_resupply(barracks: Node, base: Node) -> bool:
	if (
		barracks == null
		or base == null
		or not is_instance_valid(garrisoned_in)
		or garrisoned_in != barracks
		or state != State.GARRISONED
	):
		return false
	var base_storage: ResourceStorage = base.get("storage") as ResourceStorage
	if base_storage == null:
		base_storage = base.get_node_or_null("ResourceStorage") as ResourceStorage
	if base_storage == null:
		return false
	resupply_food_id = choose_food(base_storage, barracks)
	if resupply_food_id.is_empty():
		return false
	resupply_barracks = barracks
	returning_resupply_surplus = false
	if barracks.has_method("unregister_garrison"):
		barracks.unregister_garrison(self)
	garrisoned_in = null
	garrison_target = null
	visible = true
	if barracks.has_method("get_garrison_position"):
		global_position = barracks.get_garrison_entrance_position(self)
	_refresh_health_bar_display()
	collision_layer = 2
	collision_mask = 3
	if base.has_method("get_interaction_position"):
		navigation_agent.target_position = base.get_interaction_position(self)
	else:
		navigation_agent.target_position = base.global_position
	state = State.MOVE_TO_BASE
	return true


func _load_barracks_resupply_from_base() -> void:
	if not is_instance_valid(target_base) or not is_instance_valid(resupply_barracks):
		return_to_idle()
		return
	var base_storage: ResourceStorage = target_base.get("storage") as ResourceStorage
	if base_storage == null:
		base_storage = target_base.get_node_or_null("ResourceStorage") as ResourceStorage
	if base_storage == null:
		return_to_idle()
		return
	var taken: float = base_storage.take(resupply_food_id, minf(carry_capacity, resupply_barracks.get_food_free_space(resupply_food_id)))
	if taken <= 0.0:
		return_to_idle()
		return
	carried_resource_id = resupply_food_id
	carried_amount = taken
	carried_resource_changed.emit()
	garrison_target = resupply_barracks
	navigation_agent.target_position = resupply_barracks.get_garrison_entrance_position(self)
	state = State.MOVE_TO_BARRACKS


func finish_barracks_resupply() -> void:
	if not is_instance_valid(resupply_barracks):
		resupply_food_id = &""
		returning_resupply_surplus = false
		return_to_idle()
		return
	var delivered: float = resupply_barracks.add_food(
		resupply_food_id,
		carried_amount
	)
	carried_amount -= delivered
	if carried_amount > 0.0:
		returning_resupply_surplus = true
		go_to_base()
		return
	carried_resource_id = &""
	resupply_food_id = &""
	returning_resupply_surplus = false
	var barracks: Node = resupply_barracks
	resupply_barracks = null
	if barracks.has_method("receive_resupply_return"):
		barracks.receive_resupply_return(self)
	else:
		enter_garrison(barracks)


func leave_garrison_for_defense(barracks: Node, attacker: Node3D) -> bool:
	if garrisoned_in != barracks or not has_combat_role() or is_dead():
		return false
	global_position = barracks.get_garrison_entrance_position(self)
	garrisoned_in = null
	garrison_target = barracks
	visible = true
	_refresh_health_bar_display()
	collision_layer = 2
	collision_mask = 1
	combat_target = attacker
	combat_resume_state = State.MOVE_TO_BARRACKS
	combat_resume_navigation_target = barracks.get_garrison_entrance_position(self)
	navigation_agent.target_position = combat_resume_navigation_target
	combat_attack_cooldown = 0.0
	state = State.COMBAT_MOVE
	return true


func leave_garrison_for_patrol(barracks: Node, assemble_position: Vector3) -> bool:
	if garrisoned_in != barracks:
		return false
	global_position = barracks.get_garrison_entrance_position(self)
	garrisoned_in = null
	garrison_target = null
	patrol_barracks = barracks
	patrol_previous_target_desired_distance = navigation_agent.target_desired_distance
	visible = true
	_refresh_health_bar_display()
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
	if is_instance_valid(treasure_camp):
		return
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
	if not is_instance_valid(patrol_barracks):
		return_to_idle()
		return
	var entrance: Vector3 = patrol_barracks.get_garrison_entrance_position(self)
	if navigation_agent.target_position.distance_squared_to(entrance) > 0.01:
		navigation_agent.target_position = entrance
	navigation_agent.get_next_path_position()
	if not _has_reached_garrison_entry(patrol_barracks):
		if navigation_agent.is_navigation_finished():
			_repath_current_navigation_target()
		move_along_navigation()
		return
	velocity = Vector3.ZERO
	if patrol_barracks.has_method("receive_patrol_return"):
		patrol_barracks.receive_patrol_return(self)


func stun_from_tower_fall() -> void:
	stun_remaining = 2.0
	velocity = Vector3.ZERO
	external_force = Vector3.ZERO


func is_stunned() -> bool:
	return stun_remaining > 0.0


func leave_garrison() -> void:
	if is_instance_valid(garrisoned_in) and garrisoned_in.has_method("get_garrison_entrance_position"):
		global_position = garrisoned_in.get_garrison_entrance_position(self)
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
	_refresh_health_bar_display()
	collision_layer = 2
	collision_mask = 3
	return_to_idle()


func _refresh_health_bar_display() -> void:
	var health_bar: Node = get_node_or_null("HealthBar3D")
	if health_bar != null and health_bar.has_method("refresh_display"):
		health_bar.call("refresh_display")


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
	var gather_position := Vector3.INF


	# --------------------------------------------------------
	# 筛选当前职业需要的资源
	# --------------------------------------------------------

	for resource in resources:

		# 必须是 ResourceBase
		if not resource is ResourceBase:
			continue
		if resource.is_queued_for_deletion():
			continue
		if not resource.can_gather():
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
			var candidate: Vector3 = resource.get_gather_position(global_position, navigation_agent.get_navigation_map())
			if not candidate.is_finite():
				continue

			nearest_distance = distance
			nearest_resource = resource
			gather_position = candidate




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

	navigation_agent.target_position = gather_position

	state = State.MOVE_TO_RESOURCE
# ============================================================
# 移动到树
# ============================================================

func move_to_resource():

	# 树已经不存在
	if not is_instance_valid(target_resource) or target_resource.is_queued_for_deletion():

		target_resource = null
		state = State.FIND_RESOURCE

		return


	# 已经到达树旁边
	if target_resource.is_in_gather_range(global_position):

		velocity = Vector3.ZERO

		chop_timer = 0.0

		print("🪓 开始砍：", target_resource.name)

		state = State.GATHER_RESOURCE

		return


	# 到点容差在进入/退出采集移动状态时切换，跨帧保持一致。
	if navigation_agent.is_navigation_finished():
		var candidate: Vector3 = target_resource.get_gather_position(global_position, navigation_agent.get_navigation_map())
		if candidate.is_finite():
			navigation_agent.target_position = candidate
		else:
			target_resource.release(self)
			target_resource = null
			state = State.FIND_RESOURCE
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

	_face_direction(target_resource.global_position - global_position)
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
			amount_to_gather, self
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
		if not _has_reached_task_site_navigation_target():
			velocity = Vector3.ZERO
			return

		velocity = Vector3.ZERO

		state = State.DEPOSIT_TO_BASE

		return


	# 继续沿导航移动
	move_along_navigation()

# ============================================================
# 存入 Base
# ============================================================
func deposit_to_base():
	if is_instance_valid(resupply_barracks) and carried_amount <= 0.0:
		_load_barracks_resupply_from_base()
		return

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


	# 猎户在据点满仓时保留货物等待，避免每帧重复打印卸货日志。
	if job == Job.HUNTER and carried_amount > 0.0:
		return

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
	if job == Job.HUNTER and hunting.prey_count > 0:
		is_transporting = false
		hunting.request_return(self)
		return

	if returning_resupply_surplus and is_instance_valid(resupply_barracks):
		returning_resupply_surplus = false
		carried_resource_id = &""
		garrison_target = resupply_barracks
		if resupply_barracks.has_method("get_garrison_entrance_position"):
			navigation_agent.target_position = (
				resupply_barracks.get_garrison_entrance_position(self)
			)
		else:
			navigation_agent.target_position = resupply_barracks.global_position
		state = State.MOVE_TO_BARRACKS
		return


	# ========================================================
	# 离职处理优先
	# ========================================================

	if is_quitting_job:

		is_transporting = false

		finish_quit_job()

		return


	if is_hunter():
		is_transporting = false
		start_current_job()
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
		navigation_agent.get_next_path_position()
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
		_face_direction(velocity)
		move_and_slide()
		patrol_collision_avoid_time = maxf(
			patrol_collision_avoid_time - get_physics_process_delta_time(),
			0.0
		)
		_update_patrol_collision_avoidance()
		if patrol_collision_avoid_time <= 0.0:
			patrol_collision_avoid_direction = Vector3.ZERO
		return


	var next_position: Vector3 = road_navigation.next_position(self, navigation_agent)


	var direction = (
		next_position - global_position
	)


	# 地图没有地面碰撞体，按导航表面高度经过坡道。


	if direction.length() > 0.01:

		var step_speed: float = minf(get_move_speed(), direction.length() / get_physics_process_delta_time())
		direction = direction.normalized()
		velocity.x = direction.x * step_speed
		velocity.y = direction.y * step_speed
		velocity.z = direction.z * step_speed

	else:

		velocity.x = 0.0
		velocity.y = 0.0
		velocity.z = 0.0


	velocity = unit_avoidance.steer(self, navigation_agent, velocity, get_physics_process_delta_time())
	_face_direction(velocity)
	move_and_slide()
	if state == State.MOVE_TO_PATROL_POINT:
		_update_patrol_collision_avoidance()


func _update_patrol_collision_avoidance() -> void:
	if patrol_collision_avoid_time > 0.0:
		return
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
	road_navigation.invalidate()
	navigation_stuck_time = 0.0
	if state == State.RETREAT_TO_BASE:
		_select_retreat_destination()
		return
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


func move_to_loot_bundle() -> void:
	if not is_instance_valid(loot_bundle_target) or loot_bundle_target.is_queued_for_deletion():
		_release_current_task()
		return
	# 更新路径后再判断是否抵达，拾取点沿用导航表面而非掉落物的原始高度。
	navigation_agent.get_next_path_position()
	if not navigation_agent.is_navigation_finished():
		move_along_navigation()
		return
	var loot_offset: Vector3 = loot_pickup_position - loot_bundle_target.global_position
	loot_offset.y = 0.0
	if global_position.distance_to(loot_pickup_position) > 1.5 or loot_offset.length() > 1.5:
		velocity = Vector3.ZERO
		return
	velocity = Vector3.ZERO
	if loot_bundle_target.has_method("pick_up"):
		if not loot_bundle_target.pick_up(self):
			_release_current_task()
	else:
		_release_current_task()


func is_repairing_building(building: Node) -> bool:
	var task: GameTask = current_task as GameTask
	return task != null and task.type == GameTask.TaskType.REPAIR_BUILDING and task.target == building and state in [State.MOVE_TO_REPAIR, State.REPAIRING]


func _process_building_repair(delta: float) -> void:
	var task: GameTask = current_task as GameTask
	var building: BuildingBase = task_site as BuildingBase
	if task == null or not is_instance_valid(building) or building.is_queued_for_deletion() or building.is_destroyed() or building.is_demolition_in_progress():
		_release_current_task()
		return
	if state == State.MOVE_TO_REPAIR:
		navigation_agent.get_next_path_position()
		if not _has_reached_task_site_navigation_target():
			move_along_navigation()
			return
		state = State.REPAIRING
	velocity = Vector3.ZERO
	var missing: float = building.get_max_health() - building.get_health()
	var remaining: float = float(task.data["remaining_health"])
	if missing <= 0.001 or remaining <= 0.001:
		get_tree().call_group("task_manager", "complete_task", task)
		building._queue_repair()
		return_to_idle()
		return
	var data: BuildingData = building.building_data
	var restored: float = minf(missing, remaining)
	if data.construction_time > 0.0:
		restored = minf(restored, building.get_max_health() / data.construction_time * delta * get_work_speed())
	var costs: Dictionary[StringName, float] = {}
	var storages: Array[Node] = get_tree().get_nodes_in_group("resource_storages")
	for resource_id: StringName in data.construction_cost:
		var cost: float = float(data.construction_cost[resource_id]) * restored / building.get_max_health()
		var available: float = 0.0
		for storage: ResourceStorage in storages:
			available += storage.get_amount(resource_id)
		if available + 0.000001 < cost:
			task.data["waiting_resources"] = true
			return
		costs[resource_id] = cost
	task.data["waiting_resources"] = false
	for resource_id: StringName in costs:
		var needed: float = costs[resource_id]
		for storage: ResourceStorage in storages:
			needed -= storage.take(resource_id, needed)
			if needed <= 0.000001: break
	building.repair(restored)
	task.data["remaining_health"] = maxf(remaining - restored, 0.0)


func receive_loot(resource_id: StringName, amount: float) -> bool:
	if amount <= 0.0 or carried_amount > 0.0:
		return false
	carried_resource_id = resource_id
	carried_amount = amount
	carried_resource_changed.emit()
	loot_bundle_target = null
	var managers: Array[Node] = get_tree().get_nodes_in_group("task_manager")
	if not managers.is_empty() and current_task is GameTask:
		managers[0].complete_task(current_task)
	if target_base == null:
		find_base()
	go_to_base()
	return true


func steal_carried_resource(requested_amount: float) -> Dictionary:
	var taken_amount: float = minf(maxf(requested_amount, 0.0), carried_amount)
	if taken_amount <= 0.0:
		return {}
	var stolen_id: StringName = carried_resource_id
	carried_amount -= taken_amount
	if carried_amount <= 0.0:
		carried_amount = 0.0
		carried_resource_id = &""
	carried_resource_changed.emit()
	return {"resource_id": stolen_id, "amount": taken_amount}


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

func on_building_relocated(building: BuildingBase, old_transform: Transform3D) -> void:
	if is_dead():
		return
	if building is Watchtower and indoor_building == building and state == State.WATCHING:
		global_position = building.get_interior_position()
		return
	if task_site == building and building is ConstructionSite and state in [State.MOVE_TO_BUILD_SITE, State.WAIT_CONSTRUCTION_SITE, State.MOVE_TO_TASK_SITE]:
		_set_task_site_navigation_target()
		return
	if garrisoned_in == building:
		var old_entrance: Vector3 = old_transform * building.to_local(building.get_garrison_entrance_position(self))
		building.remove_unit_from_rosters(self)
		leave_garrison()
		global_position = old_entrance
		if is_instance_valid(garrison_target):
			garrison_target.remove_unit_from_rosters(self)
		garrison_target = null
		try_assign_to_barracks(building)
		return
	if garrison_target == building and state in [State.MOVE_TO_BARRACKS, State.RETURN_TO_BARRACKS]:
		navigation_agent.target_position = building.get_garrison_entrance_position(self)
	if task_site == building and state in [State.TRAINING, State.MOVE_TO_TRAINING]:
		relocated_building = building
		relocation_resumes_training = state == State.TRAINING
		if relocation_resumes_training:
			global_position = old_transform * building.to_local(building.get_interaction_position(self))
			visible = true
			collision_layer = 2
			collision_mask = 3
		state = State.MOVE_TO_RELOCATED_BUILDING
		return
	if task_site == building and state in [State.MOVE_TO_REPAIR, State.REPAIRING]:
		state = State.MOVE_TO_REPAIR
		navigation_agent.target_position = building.get_interaction_position(self)
	elif is_instance_valid(task_source) and task_source.get_parent() == building and state == State.MOVE_TO_TASK_SOURCE:
		navigation_agent.target_position = building.get_interaction_position(self)
	elif task_site == building and state == State.MOVE_TO_TASK_SITE:
		navigation_agent.target_position = building.get_interaction_position(self)
	if workplace == building and building is ResourceBuildingBase and not is_quitting_job and current_task == null:
		if is_instance_valid(target_resource):
			target_resource.release(self)
		target_resource = null
		release_target_field()
		if is_hunter():
			hunting.release_target(self)
			hunting.return_destination = Vector3.INF
		relocated_building = building
	elif target_base == building and job == Job.NONE and current_task == null and state in [State.IDLE, State.RETURN_TO_IDLE]:
		return_to_idle()
	elif target_base == building and state in [State.MOVE_TO_BASE, State.MOVE_TO_EAT, State.MOVE_TO_REST]:
		navigation_agent.target_position = building.get_interaction_position(self)


func _process_building_relocation() -> void:
	if relocated_building.is_destroyed() or (relocation_resumes_training and task_site != relocated_building) or (not relocation_resumes_training and workplace != relocated_building and task_site != relocated_building):
		relocated_building = null
		relocation_resumes_training = false
		return_to_idle()
		return
	state = State.MOVE_TO_RELOCATED_BUILDING
	var destination: Vector3 = relocated_building.get_interaction_position(self)
	destination = NavigationServer3D.map_get_closest_point(navigation_agent.get_navigation_map(), destination)
	if navigation_agent.target_position.distance_squared_to(destination) > 0.01:
		navigation_agent.target_position = destination
	var offset: Vector3 = destination - global_position
	offset.y = 0.0
	if offset.length() > 1.8:
		move_along_navigation()
		return
	var building: BuildingBase = relocated_building
	relocated_building = null
	velocity = Vector3.ZERO
	if relocation_resumes_training:
		relocation_resumes_training = false
		building.begin_training(self)
	elif task_site == building and current_task != null:
		navigation_agent.target_position = building.get_training_position(self)
		state = State.MOVE_TO_TRAINING
	elif is_hunter():
		hunting.request_return(self)
	elif carried_amount > 0.0:
		go_to_workplace()
	else:
		start_current_job()


func assign_job(
	new_job: Job,
	new_workplace: Node3D = null
) -> void:

	job = new_job
	workplace = new_workplace
	if new_job == Job.WATCHER:
		go_to_workplace()
		return
	if new_job == Job.HUNTER:
		set_unit_data(HUNTER_DATA)
		state = State.HUNTING
		return


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
		not is_stunned()
		and not leaving_immigration_base
		and not initial_idle_position_pending
		and not passing_door
		and state not in [State.NEED_REST, State.MOVE_TO_REST, State.RESTING, State.NEED_EAT, State.MOVE_TO_EAT, State.EATING]
		and job == Job.NONE
		and current_task == null
		and not is_quitting_job
		and not abandoning_work
		and state not in [State.RETREAT_TO_BASE, State.SHELTERED]
		and garrisoned_in == null
		and not is_instance_valid(construction_cancellation_target)
		and carried_amount <= 0.0
	)


func is_idle_resident() -> bool:
	return not has_combat_role() and is_idle() and state in [State.IDLE, State.RETURN_TO_IDLE] and not is_queued_for_deletion() and get_health() > 0.0
# ============================================================
# @feature 根据职业返回正确的待命地点
# ============================================================

func walk_out_of_immigration_base(base: Node3D, initial_slot: int = -1, _initial_count: int = 0) -> void:
	target_base = base
	collision_layer = 0
	collision_mask = 0
	if initial_slot >= 0:
		var runtime: MapGenerateRuntime = get_tree().get_first_node_in_group("map_generate_runtime") as MapGenerateRuntime
		while is_instance_valid(runtime) and runtime.navigation_revision == 0:
			await get_tree().process_frame
			if not is_inside_tree(): return
		# 等待生成网格替换场景旧网格，并由 NavigationServer 同步。
		await get_tree().process_frame
		if not is_inside_tree(): return
		await get_tree().process_frame
		if not is_inside_tree() or not is_instance_valid(base): return
		if initial_slot == 0 and runtime != null:
			var region: NavigationRegion3D = runtime.get_node(runtime.navigation_region_path)
			NavigationServer3D.region_set_navigation_mesh(region.get_rid(), region.navigation_mesh)
		await get_tree().process_frame
		if not is_inside_tree() or not is_instance_valid(base): return
	var exit_position: Vector3 = base.get_migrant_entrance_position()
	_face_direction(exit_position - global_position)
	var tween: Tween = create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	if initial_slot > 0: tween.tween_interval(initial_slot * 0.45)
	tween.tween_property(self, "global_position", exit_position, global_position.distance_to(exit_position) / get_move_speed())
	tween.tween_callback(func() -> void:
		leaving_immigration_base = false
		collision_layer = 2
		collision_mask = 3
		if not is_instance_valid(target_base):
			target_base = null
		return_to_idle()
	)


func _get_newcomer_idle_position(base: Node3D) -> Vector3:
	var residents: Array[Node] = get_tree().get_nodes_in_group("villagers")
	var map: RID = navigation_agent.get_navigation_map()
	var best_point: Vector3 = Vector3.INF
	var best_clearance: float = -1.0
	var entrance: Vector3 = base.get_migrant_entrance_position()
	base.idle_space.refresh(base)
	var candidates: Array[Vector3] = base.idle_space.points.duplicate()
	if get_tree().get_first_node_in_group("build_grid") == null:
		for _attempt: int in range(32): candidates.append(get_random_idle_position(base.global_position, base.idle_radius))
	candidates.shuffle()
	for point: Vector3 in candidates:
		var projected: Vector3 = NavigationServer3D.map_get_closest_point(map, point)
		if Vector2(projected.x - point.x, projected.z - point.z).length() > 0.35 or absf(projected.y - point.y) > 0.8: continue
		if Vector2(projected.x - entrance.x, projected.z - entrance.z).length() < 1.3: continue
		var clearance: float = INF
		for resident: Node3D in residents:
			if resident == self or not resident.is_visible_in_tree() and resident.state != State.RETURN_TO_IDLE: continue
			var position: Vector3 = resident.navigation_agent.target_position if resident.state == State.RETURN_TO_IDLE else resident.global_position
			clearance = minf(clearance, Vector2(position.x - projected.x, position.z - projected.z).length())
		if clearance < 0.9: continue
		var path: PackedVector3Array = NavigationServer3D.map_get_path(map, global_position, projected, true)
		if path.is_empty() or path[-1].distance_to(projected) > 0.4: continue
		if clearance > best_clearance:
			best_point = projected
			best_clearance = clearance
		if clearance >= 1.1: return projected
	if best_point != Vector3.INF: return best_point
	return Vector3.INF


func _set_base_idle_destination() -> void:
	target_base.idle_space.refresh(target_base)
	var point: Vector3 = Vector3.INF if target_base.idle_space.indoors else _get_newcomer_idle_position(target_base)
	idle_entrance_target = target_base if point == Vector3.INF else null
	state = State.RETURN_TO_IDLE
	navigation_agent.target_position = target_base.get_entrance_position() if point == Vector3.INF else point
	initial_idle_position_pending = true


func _leave_idle_building() -> void:
	indoor_idle = false
	var building: BuildingBase = indoor_building
	if is_instance_valid(building) and not building.is_queued_for_deletion():
		await _pass_building_door(building, false)
	else:
		indoor_building = null
		visible = true
		collision_layer = 2
		collision_mask = 3


func _leave_idle_and_reposition() -> void:
	var point: Vector3 = _get_newcomer_idle_position(target_base)
	if point == Vector3.INF: return
	# 出门排队时先预留室外站位，避免多个人同时抢同一个空地。
	state = State.RETURN_TO_IDLE
	navigation_agent.target_position = point
	initial_idle_position_pending = true
	await _leave_idle_building()
	if not is_dead() and not target_base.idle_space.contains(target_base, point): _set_base_idle_destination()


func _leave_idle_for_food() -> void:
	if choose_food(target_base.storage).is_empty(): return
	await _leave_idle_building()
	if not is_dead() and not begin_eating(): return_to_idle()


func _leave_idle_for_job() -> void:
	await _leave_idle_building()
	if is_dead(): return
	start_current_job()


func yield_to_unit(_other: CharacterBody3D, travel_direction: Vector3) -> void:
	if state != State.IDLE or current_task != null or carried_amount > 0.0 or yield_cooldown > 0.0 or passing_door or leaving_immigration_base or is_dead(): return
	var side := Vector3(-travel_direction.z, 0, travel_direction.x)
	for offset: Vector3 in [side * 1.0, -side * 1.0]:
		if is_instance_valid(target_base) and not target_base.idle_space.contains(target_base, global_position + offset): continue
		if not preload("res://Script/unit/unit_avoidance.gd").can_step(self, navigation_agent, offset): continue
		navigation_agent.target_position = NavigationServer3D.map_get_closest_point(navigation_agent.get_navigation_map(), global_position + offset)
		state = State.RETURN_TO_IDLE
		initial_idle_position_pending = true
		yield_cooldown = 2.0
		return


func return_to_idle():
	if abandoning_work:
		if target_base == null:
			find_base()
		if target_base != null:
			_set_base_idle_destination()
		else:
			state = State.IDLE
		return
	if is_instance_valid(garrisoned_in):
		state = State.GARRISONED
		return

	if is_instance_valid(patrol_barracks):
		if _resume_patrol_after_needs():
			return
		return

	if has_combat_role() and try_find_available_barracks():
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
		_set_base_idle_destination()

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
	if not has_combat_role() or garrisoned_in != null:
		return false
	if combat_role == CombatRole.Type.ARCHER:
		for building: Node in get_tree().get_nodes_in_group("buildings"):
			if building.has_method("allows_garrison_attacks") and not building.is_demolition_in_progress() and try_assign_to_barracks(building): return true
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
	if is_instance_valid(idle_entrance_target):
		if not idle_entrance_target.is_at_entrance_front(global_position):
			move_along_navigation()
			return
		var building: BuildingBase = idle_entrance_target
		idle_entrance_target = null
		if await _pass_building_door(building, true):
			state = State.IDLE
			indoor_idle = true
			abandoning_work = false
			idle_reposition_timer = 3.0
			_request_idle_tasks()
		else:
			return_to_idle()
		return
	if job == Job.NONE and is_instance_valid(target_base) and not target_base.idle_space.contains(target_base, navigation_agent.target_position):
		_set_base_idle_destination()
		return

	var reached_idle_position: bool = global_position.distance_to(navigation_agent.target_position) <= 0.8
	if initial_idle_position_pending:
		var offset: Vector3 = navigation_agent.target_position - global_position
		reached_idle_position = Vector2(offset.x, offset.z).length() <= 0.25 and absf(offset.y) <= 0.8
	if reached_idle_position:

		velocity = Vector3.ZERO
		state = State.IDLE
		if abandoning_work:
			abandoning_work = false
			var task_managers: Array[Node] = get_tree().get_nodes_in_group("task_manager")
			if not task_managers.is_empty():
				task_managers[0].request_dispatch()

		if job != Job.NONE:
			print("💤 已回到工作地点附近待命：", workplace.name)
		idle_reposition_timer = randf_range(3.0, 10.0)
		_request_idle_tasks()

		return


	move_along_navigation()


func _request_idle_tasks() -> void:
	var manager: Node = get_tree().get_first_node_in_group("task_manager")
	if manager != null: manager.request_dispatch()


func process_idle_reposition(delta: float) -> void:
	if current_task != null or job != Job.NONE and workplace == null:
		return
	if job == Job.NONE and is_instance_valid(target_base):
		target_base.idle_space.refresh(target_base)
		if target_base.idle_space.indoors or not target_base.idle_space.contains(target_base, global_position):
			_set_base_idle_destination()
			return
	idle_reposition_timer -= delta
	if idle_reposition_timer > 0.0:
		return
	if job in [Job.LUMBERJACK, Job.MINER] and is_instance_valid(workplace):
		state = State.FIND_RESOURCE
		find_nearest_resource()
		return
	if job != Job.NONE and workplace != null:
		navigation_agent.target_position = get_random_idle_position(
			workplace.global_position,
			workplace.idle_radius
		)
	else:
		if target_base == null or not is_instance_valid(target_base):
			find_base()
		if target_base == null:
			idle_reposition_timer = randf_range(3.0, 10.0)
			return
		_set_base_idle_destination()
		return
	state = State.RETURN_TO_IDLE


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

	if not is_instance_valid(workplace):

		print("❌ 没有工作建筑，无法运送木材")

		return_to_idle()

		return


	navigation_agent.target_position = _get_reachable_workplace_position()
	workplace_repath_msec = Time.get_ticks_msec() + 500

	state = State.MOVE_TO_WORKPLACE

	print(
		"👨 携带木材返回：",
		workplace.name
	)
# ============================================================
# 移动到工作建筑
# ============================================================

func _get_reachable_workplace_position() -> Vector3:
	return _get_reachable_building_entrance(workplace)


func _get_reachable_building_entrance(building: BuildingBase) -> Vector3:
	var preferred: Vector3 = building.get_interaction_position(self)
	var map: RID = navigation_agent.get_navigation_map()
	if not map.is_valid() or NavigationServer3D.map_get_iteration_id(map) == 0:
		return preferred
	var approaches: Array[Vector3] = building.get_entrance_approach_positions()
	approaches.sort_custom(func(a: Vector3, b: Vector3) -> bool: return global_position.distance_squared_to(a) < global_position.distance_squared_to(b))
	for approach: Vector3 in approaches:
		var navigation_point: Vector3 = NavigationServer3D.map_get_closest_point(map, approach)
		if not building.is_at_entrance_front(navigation_point): continue
		var path: PackedVector3Array = NavigationServer3D.map_get_path(map, global_position, navigation_point, true)
		if not path.is_empty() and path[-1].distance_to(navigation_point) <= 0.5:
			return navigation_point
	return preferred


func move_to_workplace():

	if not is_instance_valid(workplace):

		return_to_idle()

		return

	if (unreachable_warning or (navigation_agent.is_navigation_finished() and not workplace.is_at_entrance_front(global_position))) and Time.get_ticks_msec() >= workplace_repath_msec:
		workplace_repath_msec = Time.get_ticks_msec() + 500
		var approach: Vector3 = _get_reachable_workplace_position()
		if navigation_agent.target_position.distance_to(approach) > 0.1:
			navigation_agent.target_position = approach
			_set_unreachable_warning(false)
			unreachable_time = 0.0

	if workplace.is_at_entrance_front(global_position) or navigation_agent.is_navigation_finished():
		if not workplace.is_at_entrance_front(global_position):
			velocity = Vector3.ZERO
			return

		velocity = Vector3.ZERO
		if job == Job.WATCHER:
			workplace.begin_watch(self)
			return


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
	if passing_door: return
	if carried_amount <= 0.0 or not is_instance_valid(workplace):
		_deposit_to_workplace_inside()
		return
	var building: BuildingBase = workplace
	if not await _pass_building_door(building, true):
		if not is_instance_valid(workplace):
			workplace = null
			job = Job.NONE
		if is_dead(): return
		return_to_idle()
		return
	_deposit_to_workplace_inside()
	await _pass_building_door(building, false)
	if not is_instance_valid(workplace) and not is_dead(): return_to_idle()


func _deposit_to_workplace_inside():

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

	var pickup_position: Vector3 = _get_reachable_workplace_position()
	var distance = global_position.distance_to(pickup_position)


	if distance > 1.5:

		is_transporting = true

		print("📦 准备运输，先返回工作建筑取货")

		navigation_agent.target_position = pickup_position

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
func can_work_at(target: Node) -> bool:
	return not is_instance_valid(target) or target.get_instance_id() != abandoned_work_target_id


func abandon_current_work() -> void:
	if indoor_building is Watchtower:
		await _leave_idle_building()
		if is_dead(): return
	var previous_site: Variant = task_site
	var task: GameTask = current_task as GameTask
	var previous_target: Variant = task.target if task != null else previous_site
	if not is_instance_valid(previous_target):
		previous_target = workplace
	abandoned_work_target_id = previous_target.get_instance_id() if is_instance_valid(previous_target) else 0
	abandoning_work = true
	_set_unreachable_warning(false)
	unreachable_time = 0.0
	if task != null:
		var managers: Array[Node] = get_tree().get_nodes_in_group("task_manager")
		if not managers.is_empty():
			managers[0].cancel_task(task, false)
		else:
			clear_current_task()
	if is_instance_valid(previous_target) and previous_target is ConstructionSite:
		previous_target.stop_assigning_workers()
	if is_instance_valid(previous_site) and previous_site.has_method("remove_construction_worker"):
		previous_site.remove_construction_worker(self)
	if is_instance_valid(target_resource):
		target_resource.release(self)
	target_resource = null
	release_target_field()
	var previous_workplace: Variant = workplace
	job = Job.NONE
	workplace = null
	is_quitting_job = false
	is_transporting = false
	if is_instance_valid(previous_workplace) and previous_workplace.has_method("remove_worker"):
		previous_workplace.remove_worker(self)
	if is_instance_valid(garrisoned_in):
		if garrisoned_in.has_method("remove_unit_from_rosters"):
			garrisoned_in.remove_unit_from_rosters(self)
		leave_garrison()
	task_source = null
	task_site = null
	current_task = null
	state = State.IDLE
	if target_base == null:
		find_base()
	if carried_amount > 0.0:
		go_to_base()
	else:
		return_to_idle()


func quit_job():
	if job == Job.WATCHER and indoor_building is Watchtower:
		is_quitting_job = true
		await _leave_idle_building()
		if not is_dead(): finish_quit_job()
		return
	if job == Job.HUNTER:
		is_quitting_job = true
		if carried_amount > 0.0:
			hunting.release_target(self)
			go_to_base()
			return
		hunting.request_return(self)
		return

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
	release_target_field()
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
	if job == Job.HUNTER:
		hunting.release_target(self)
		set_unit_data(RESIDENT_DATA)

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
	if passing_door or construction_repositioning or hunting.inside_processing or leaving_immigration_base or initial_idle_position_pending: return false
	if state in [State.NEED_REST, State.MOVE_TO_REST, State.RESTING, State.NEED_EAT, State.MOVE_TO_EAT, State.EATING]: return false
	if _task is GameTask and _task.type == GameTask.TaskType.TRAIN_SWORDSMAN and state == State.SHELTERED:
		return not is_dead() and not has_combat_role() and current_task == null and not is_quitting_job and not abandoning_work and is_instance_valid(_task.target) and _task.target.get_sheltered_training_worker() == self
	if _task is GameTask and _task.type == GameTask.TaskType.BUILD_ROAD:
		if current_task != null or state not in [State.IDLE, State.RETURN_TO_IDLE] or is_dead(): return false
		var map: RID = navigation_agent.get_navigation_map()
		if NavigationServer3D.map_get_iteration_id(map) == 0: return false
		var path: PackedVector3Array = NavigationServer3D.map_get_path(map, global_position, _task.data.position, true)
		if path.is_empty() or path[-1].distance_to(_task.data.position) > 0.5: return false
	if _task != null:
		var task_target: Variant = _task.get("target")
		if is_instance_valid(task_target) and task_target.get_instance_id() == abandoned_work_target_id:
			return false

	return (
		job == Job.NONE
		and current_task == null
		and not is_quitting_job
		and not abandoning_work
		and state not in [State.RETREAT_TO_BASE, State.SHELTERED]
		and not has_combat_role()
		and not is_instance_valid(construction_cancellation_target)
		and carried_amount <= 0.0
	)


func set_current_task(task: Object) -> void:

	current_task = task
	if task is GameTask and task.type == GameTask.TaskType.TRAIN_SWORDSMAN and state == State.SHELTERED:
		var training_in_shelter: bool = shelter_target == task.target
		if training_in_shelter:
			shelter_target.release_shelter(self)
			shelter_target = null
		else:
			await _leave_shelter()
		if is_dead() or current_task != task or not is_instance_valid(task.target) or task.target.is_queued_for_deletion(): return
		retreat_threat = null
		_start_current_task()
		if training_in_shelter and current_task == task and is_instance_valid(task_site):
			training_elapsed = 0.0
			task_site.begin_training(self)


func clear_current_task() -> void:
	if current_task is GameTask and current_task.type == GameTask.TaskType.BUILD_ROAD and state in [State.MOVE_TO_ROAD, State.BUILD_ROAD]:
		navigation_agent.target_desired_distance = road_previous_target_distance

	if state == State.TRAINING and not is_dead():
		visible = true
		collision_layer = 2
		collision_mask = 3
	var was_training: bool = (
		state == State.MOVE_TO_TRAINING or state == State.TRAINING
		or (is_instance_valid(relocated_building) and task_site == relocated_building and current_task != null)
	)
	if was_training:
		relocated_building = null
		relocation_resumes_training = false
	current_task = null
	if state == State.MOVE_TO_LOOT:
		loot_bundle_target = null
		state = State.IDLE
	if state in [State.BUILDING, State.MOVE_TO_ROAD, State.BUILD_ROAD, State.MOVE_TO_REPAIR, State.REPAIRING] or was_training:
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
