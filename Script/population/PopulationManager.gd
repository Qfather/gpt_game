class_name PopulationManager
extends Node

signal population_changed(current_population: int, housing_capacity: int)
signal immigration_ready(group_size: int)

const RESOURCE_DATABASE: ResourceDatabase = preload(
	"res://data/resources/resource_database.tres"
)
const MIGRANT_SCENE: PackedScene = preload(
	"res://Scene/unit/migrant.tscn"
)
const VILLAGER_SCENE: PackedScene = preload(
	"res://Scene/unit/villager.tscn"
)

@export var level_config: LevelConfig = preload(
	"res://data/levels/Level_01.tres"
)

var current_population: int = 0
var housing_capacity: int = 0
var _last_immigration_status: String = ""
var immigration_countdown_active: bool = false
var immigration_countdown_remaining: float = 0.0
var immigration_countdown_group_size: int = 0
var _immigration_ready_emitted: bool = false
var pending_migrant_count: int = 0


func _ready() -> void:
	add_to_group("population_manager")
	immigration_ready.connect(_spawn_migrant_group)
	call_deferred("refresh_population")


func _process(delta: float) -> void:
	refresh_population()
	_refresh_immigration_status()
	_update_immigration_countdown(delta)


func register_villager(villager: Node) -> void:
	if villager == null:
		return
	refresh_population()


func unregister_villager(villager: Node) -> void:
	if villager == null:
		return
	refresh_population()


func remove_villager(villager: Node) -> bool:
	if villager == null or not is_instance_valid(villager):
		return false
	if villager.has_method("is_idle") and not villager.is_idle():
		push_warning("PopulationManager：只能删除无业待命居民")
		return false
	if villager.has_method("get_carried_amount") and villager.get_carried_amount() > 0.0:
		push_warning("PopulationManager：居民仍携带资源，不能删除")
		return false
	villager.queue_free()
	call_deferred("refresh_population")
	return true


func register_housing(_source: Node, _capacity: int) -> void:
	refresh_population()


func unregister_housing(_source: Node) -> void:
	refresh_population()


func refresh_population() -> void:
	var next_population: int = get_tree().get_nodes_in_group("villagers").size()
	var next_housing_capacity: int = 0

	for base: Node in get_tree().get_nodes_in_group("bases"):
		if base.has_method("get_housing_capacity"):
			next_housing_capacity += int(base.get_housing_capacity())

	for housing: Node in get_tree().get_nodes_in_group("housing_buildings"):
		if housing.has_method("get_housing_capacity"):
			next_housing_capacity += int(housing.get_housing_capacity())

	if (
		next_population == current_population
		and next_housing_capacity == housing_capacity
	):
		return

	current_population = next_population
	housing_capacity = next_housing_capacity
	population_changed.emit(current_population, housing_capacity)


func get_population() -> int:
	return current_population


func get_housing_capacity() -> int:
	return housing_capacity


func get_free_housing() -> int:
	return housing_capacity - current_population


func get_available_food() -> float:
	var resource_manager: Node = get_tree().get_first_node_in_group(
		"resource_manager"
	)
	if resource_manager == null:
		return 0.0

	var total_food: float = 0.0
	for resource_data: ResourceData in RESOURCE_DATABASE.resources:
		if resource_data == null or not resource_data.is_food():
			continue
		if resource_manager.has_method("get_total"):
			total_food += float(resource_manager.get_total(resource_data.id))

	return total_food


func _get_immigration_rules() -> ImmigrationRules:
	if level_config == null:
		return null
	return level_config.immigration_rules


func get_immigration_group_size() -> int:
	var rules: ImmigrationRules = _get_immigration_rules()
	if rules == null:
		return 0

	var free_housing: int = get_free_housing()
	if free_housing < rules.required_free_housing:
		return 0

	var available_food: float = get_available_food()
	if available_food < rules.minimum_food_reserve:
		return 0

	var food_group_limit: int = rules.max_group_size
	if rules.food_per_migrant > 0.0:
		food_group_limit = mini(
			food_group_limit,
			int(floor(
				(available_food - rules.minimum_food_reserve)
				/ rules.food_per_migrant
			))
		)

	return clampi(
		mini(free_housing, food_group_limit),
		0,
		rules.max_group_size
	)


func can_start_immigration() -> bool:
	var rules: ImmigrationRules = _get_immigration_rules()
	if rules == null:
		return false

	return (
		get_free_housing() >= rules.required_free_housing
		and get_immigration_group_size() >= rules.min_group_size
	)


func get_immigration_status() -> Dictionary:
	var rules: ImmigrationRules = _get_immigration_rules()
	if rules == null:
		return {
			"housing_satisfied": false,
			"food_satisfied": false,
			"group_size": 0,
			"required_housing": 0,
			"free_housing": get_free_housing(),
			"required_food": 0.0,
			"available_food": 0.0,
			"can_start": false,
			"countdown_active": false,
			"countdown_remaining": 0.0,
			"ready_emitted": false,
			"pending_migrant_count": pending_migrant_count,
		}

	var available_food: float = get_available_food()
	var housing_satisfied: bool = (
		get_free_housing() >= rules.required_free_housing
	)
	var food_satisfied: bool = available_food >= rules.minimum_food_reserve
	var group_size: int = get_immigration_group_size()
	var requirement_group_size: int = maxi(group_size, rules.min_group_size)
	var required_housing: int = rules.required_free_housing
	if group_size > 0:
		required_housing = group_size
	var required_food: float = (
		rules.minimum_food_reserve
		+ rules.food_per_migrant * float(requirement_group_size)
	)

	return {
		"housing_satisfied": housing_satisfied,
		"food_satisfied": food_satisfied,
		"group_size": group_size,
		"required_housing": required_housing,
		"free_housing": get_free_housing(),
		"required_food": required_food,
		"available_food": available_food,
		"can_start": can_start_immigration(),
		"countdown_active": immigration_countdown_active,
		"countdown_remaining": immigration_countdown_remaining,
		"ready_emitted": _immigration_ready_emitted,
		"pending_migrant_count": pending_migrant_count,
	}


func _refresh_immigration_status() -> void:
	var status: Dictionary = get_immigration_status()
	var status_key: String = "%s|%s|%d|%s" % [
		status["housing_satisfied"],
		status["food_satisfied"],
		status["group_size"],
		status["can_start"],
	]
	if status_key == _last_immigration_status:
		return

	_last_immigration_status = status_key
	print(
		"移民条件：住房满足=%s FOOD满足=%s 预计移民人数=%d 状态=%s"
		% [
			"是" if status["housing_satisfied"] else "否",
			"是" if status["food_satisfied"] else "否",
			status["group_size"],
			"可以开始" if status["can_start"] else "等待条件",
		]
	)


func get_immigration_countdown_remaining() -> float:
	return immigration_countdown_remaining


func is_immigration_countdown_active() -> bool:
	return immigration_countdown_active


func get_immigration_progress() -> float:
	var rules: ImmigrationRules = _get_immigration_rules()
	if (
		rules == null
		or not immigration_countdown_active
		or rules.arrival_interval <= 0.0
	):
		return 0.0

	return clampf(
		1.0 - immigration_countdown_remaining / rules.arrival_interval,
		0.0,
		1.0
	)


func _update_immigration_countdown(delta: float) -> void:
	var rules: ImmigrationRules = _get_immigration_rules()
	if rules == null:
		if pending_migrant_count <= 0:
			_reset_immigration_countdown()
		return

	if not can_start_immigration():
		if immigration_countdown_active:
			_cancel_active_immigration_countdown()
		elif pending_migrant_count <= 0 and _immigration_ready_emitted:
			_reset_immigration_countdown()
		return

	var group_size: int = get_immigration_group_size()
	if group_size < rules.min_group_size:
		if pending_migrant_count <= 0:
			_reset_immigration_countdown()
		return

	if _immigration_ready_emitted:
		return

	if not immigration_countdown_active:
		immigration_countdown_active = true
		immigration_countdown_group_size = group_size
		immigration_countdown_remaining = maxf(
			rules.arrival_interval,
			0.0
		)
		print(
			"移民倒计时开始：%.1f 秒，人数=%d"
			% [immigration_countdown_remaining, group_size]
		)

	if group_size != immigration_countdown_group_size:
		immigration_countdown_group_size = group_size

	immigration_countdown_remaining = maxf(
		immigration_countdown_remaining - maxf(delta, 0.0),
		0.0
	)
	if immigration_countdown_remaining > 0.0:
		return

	immigration_countdown_active = false
	_immigration_ready_emitted = true
	print("移民准备到来：%d人" % immigration_countdown_group_size)
	immigration_ready.emit(immigration_countdown_group_size)


func _reset_immigration_countdown() -> void:
	_cancel_active_immigration_countdown()
	_immigration_ready_emitted = false


func _cancel_active_immigration_countdown() -> void:
	if immigration_countdown_active:
		print("移民倒计时取消：条件不再满足")

	immigration_countdown_active = false
	immigration_countdown_remaining = 0.0
	immigration_countdown_group_size = 0


func _spawn_migrant_group(group_size: int) -> void:
	if group_size <= 0:
		return

	var bases: Array[Node] = get_tree().get_nodes_in_group("bases")
	var arrival_points: Array[Node] = get_tree().get_nodes_in_group(
		"arrival_points"
	)
	if bases.is_empty() or arrival_points.is_empty():
		push_warning("PopulationManager：没有 Base 或 ArrivalPoint，无法生成移民")
		return

	var base: Node3D = bases[0] as Node3D
	var arrival_point: Node3D = arrival_points.pick_random() as Node3D
	var migrant_container: Node = get_tree().current_scene.get_node_or_null(
		"Migrants"
	)
	if migrant_container == null:
		migrant_container = get_tree().current_scene

	var spawned_count: int = 0
	for index: int in range(group_size):
		var migrant: Node3D = MIGRANT_SCENE.instantiate() as Node3D
		if migrant == null:
			continue
		migrant_container.add_child(migrant)
		migrant.global_position = arrival_point.global_position + Vector3(
			(randf() - 0.5) * 1.5,
			0.0,
			(randf() - 0.5) * 1.5
		)
		if migrant.has_method("setup"):
			migrant.call("setup", base)
		if migrant.has_signal("arrived"):
			migrant.arrived.connect(_on_migrant_arrived)
		spawned_count += 1

	if spawned_count <= 0:
		_immigration_ready_emitted = false
		return
	pending_migrant_count += spawned_count

	print(
		"移民已从 ArrivalPoint 生成：人数=%d，正式人口不变"
		% spawned_count
	)


func _on_migrant_arrived(migrant: Node3D, base: Node3D) -> void:
	if migrant == null or not is_instance_valid(migrant):
		return

	var villager_container: Node = get_tree().current_scene.get_node_or_null(
		"Villagers"
	)
	if villager_container == null:
		villager_container = get_tree().current_scene

	var villager: Node3D = VILLAGER_SCENE.instantiate() as Node3D
	villager_container.add_child(villager)
	villager.global_position = migrant.global_position

	var resource_manager: Node = get_tree().get_first_node_in_group(
		"resource_manager"
	)
	if resource_manager != null and resource_manager.has_method(
		"register_villager"
	):
		resource_manager.register_villager(villager)

	var main: Node = get_tree().current_scene
	if main != null and main.has_method("register_villager"):
		main.register_villager(villager)

	register_villager(villager)
	pending_migrant_count = maxi(pending_migrant_count - 1, 0)
	if pending_migrant_count == 0:
		_immigration_ready_emitted = false
	migrant.queue_free()

	print(
		"Migrant 已抵达 Base，转为正式 Villager：人口将更新"
	)
