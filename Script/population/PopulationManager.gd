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

var level_config: LevelConfig = preload(
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
var current_immigration_group: ImmigrationGroup
var departing_immigration_group: ImmigrationGroup
var refresh_cooldown_remaining: float = 0.0
const REFRESH_COOLDOWN: float = 60.0


func _ready() -> void:
	add_to_group("population_manager")
	immigration_ready.connect(_spawn_migrant_group)
	call_deferred("refresh_population")


func _process(delta: float) -> void:
	refresh_cooldown_remaining = maxf(refresh_cooldown_remaining - delta, 0.0)
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
	_ensure_immigration_group()
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
	_ensure_immigration_group()
	if current_immigration_group != null:
		if not _group_requirements_satisfied():
			return 0
		return mini(maxi(get_free_housing() - pending_migrant_count, 0), current_immigration_group.max_group_size)
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
	_ensure_immigration_group()
	if current_immigration_group != null:
		return get_immigration_group_size() >= current_immigration_group.min_group_size
	var rules: ImmigrationRules = _get_immigration_rules()
	if rules == null:
		return false

	return (
		get_free_housing() >= rules.required_free_housing
		and get_immigration_group_size() >= rules.min_group_size
	)


func get_immigration_status() -> Dictionary:
	_ensure_immigration_group()
	if current_immigration_group != null:
		var group: ImmigrationGroup = current_immigration_group
		var size: int = get_immigration_group_size()
		var trait_names: PackedStringArray = []
		for entry: UnitTrait in group.resident_traits:
			if entry != null and entry.trait_data != null:
				trait_names.append(entry.trait_data.trait_name)
		return {
			"group_name": group.display_name, "group_size": size,
			"housing_satisfied": get_free_housing() - pending_migrant_count >= group.min_group_size,
			"food_satisfied": _get_group_food() >= group.food_amount,
			"required_housing": group.min_group_size, "free_housing": get_free_housing() - pending_migrant_count,
			"required_food": group.food_amount, "available_food": _get_group_food(),
			"food_name": _get_food_tag_name(group.food_tag),
			"building_requirements": _get_building_requirements_text(),
			"trait_names": "、".join(trait_names), "can_start": can_start_immigration(),
			"countdown_active": immigration_countdown_active, "countdown_remaining": immigration_countdown_remaining,
			"ready_emitted": _immigration_ready_emitted, "pending_migrant_count": pending_migrant_count,
			"refresh_cooldown": refresh_cooldown_remaining,
		}
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
	var interval: float = current_immigration_group.arrival_interval if current_immigration_group != null else (rules.arrival_interval if rules != null else 0.0)
	if (
		rules == null
		or not immigration_countdown_active
		or interval <= 0.0
	):
		return 0.0

	return clampf(
		1.0 - immigration_countdown_remaining / interval,
		0.0,
		1.0
	)


func _update_immigration_countdown(delta: float) -> void:
	var rules: ImmigrationRules = _get_immigration_rules()
	var minimum: int = current_immigration_group.min_group_size if current_immigration_group != null else (rules.min_group_size if rules != null else 1)
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
	if group_size < minimum:
		if pending_migrant_count <= 0:
			_reset_immigration_countdown()
		return

	if _immigration_ready_emitted:
		return

	if not immigration_countdown_active:
		immigration_countdown_active = true
		immigration_countdown_group_size = group_size
		immigration_countdown_remaining = maxf(
			current_immigration_group.arrival_interval if current_immigration_group != null else rules.arrival_interval,
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
	if bases.is_empty():
		push_warning("PopulationManager：没有 Base，无法生成移民")
		return

	var base: Node3D = bases[0] as Node3D
	var map_runtime: MapGenerateRuntime = get_tree().get_first_node_in_group("map_generate_runtime") as MapGenerateRuntime
	if map_runtime == null or map_runtime.map_data == null:
		push_warning("PopulationManager：地图尚未生成，无法生成移民")
		_immigration_ready_emitted = false
		return
	var spawn_positions: Array[Vector3] = []
	var candidates: Array[Vector3] = []
	for cell: Vector2i in map_runtime.map_data.occupied_cells:
		var point: Vector3 = map_runtime._cell_world_position(cell)
		if Vector2(point.x - base.global_position.x, point.z - base.global_position.z).length() >= 30.0:
			candidates.append(point)
	candidates.shuffle()
	# 同一批尽量从同一片远端区域进场；每个点仍验证到据点的导航连通性。
	if not candidates.is_empty():
		var origin: Vector3 = candidates[0]
		candidates.sort_custom(func(a: Vector3, b: Vector3) -> bool: return a.distance_squared_to(origin) < b.distance_squared_to(origin))
	for candidate: Vector3 in candidates:
		var ground: Vector3 = map_runtime.get_safe_ground_position(Vector2(candidate.x, candidate.z), 1.0)
		if ground == Vector3.INF:
			continue
		var occupied: bool = false
		for existing: Vector3 in spawn_positions:
			if Vector2(existing.x - ground.x, existing.z - ground.z).length() < 2.0:
				occupied = true
				break
		if not occupied:
			spawn_positions.append(ground)
		if spawn_positions.size() >= group_size:
			break
	if spawn_positions.size() < group_size:
		push_warning("PopulationManager：距据点30米以外没有足够的可达移民出生点，本次暂不生成")
		_immigration_ready_emitted = false
		return
	var migrant_container: Node = get_tree().current_scene.get_node_or_null(
		"Migrants"
	)
	if migrant_container == null:
		migrant_container = get_tree().current_scene

	var spawned_count: int = 0
	departing_immigration_group = current_immigration_group
	for index: int in range(group_size):
		var migrant: Node3D = MIGRANT_SCENE.instantiate() as Node3D
		if migrant == null:
			continue
		if current_immigration_group != null:
			migrant.resident_traits = current_immigration_group.resident_traits.duplicate(true)
		migrant_container.add_child(migrant)
		migrant.global_position = spawn_positions[index]
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
	for entry: UnitTrait in migrant.resident_traits:
		villager.traits.append(entry.duplicate(true))
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
		if current_immigration_group == departing_immigration_group:
			_select_immigration_group()
	migrant.queue_free()

	print(
		"Migrant 已抵达 Base，转为正式 Villager：人口将更新"
	)


func _ensure_immigration_group() -> void:
	if current_immigration_group == null:
		_select_immigration_group()
		return
	var rules: ImmigrationRules = _get_immigration_rules()
	if rules == null or rules.groups.is_empty():
		return
	var stage: int = 0
	for group: ImmigrationGroup in rules.groups:
		if group != null and group.unlock_population <= current_population:
			stage = maxi(stage, group.unlock_population)
	if current_immigration_group.unlock_population != stage:
		_cancel_active_immigration_countdown()
		_select_immigration_group()
		_immigration_ready_emitted = pending_migrant_count > 0


func _select_immigration_group() -> void:
	var rules: ImmigrationRules = _get_immigration_rules()
	if rules == null or rules.groups.is_empty():
		return
	var stage: int = -1
	var candidates: Array[ImmigrationGroup] = []
	for group: ImmigrationGroup in rules.groups:
		if group != null and group.unlock_population <= current_population:
			stage = maxi(stage, group.unlock_population)
	for group: ImmigrationGroup in rules.groups:
		if group != null and group.unlock_population == stage:
			candidates.append(group)
	if candidates.size() > 1:
		candidates.erase(current_immigration_group)
	if candidates.is_empty():
		return
	var total: float = 0.0
	for group: ImmigrationGroup in candidates:
		total += group.weight
	var roll: float = randf() * total
	for group: ImmigrationGroup in candidates:
		roll -= group.weight
		if roll <= 0.0:
			current_immigration_group = group
			return
	current_immigration_group = candidates.back()


func refresh_immigration_requirements() -> bool:
	if refresh_cooldown_remaining > 0.0:
		return false
	var rules: ImmigrationRules = _get_immigration_rules()
	if rules == null or rules.groups.is_empty():
		return false
	_cancel_active_immigration_countdown()
	_select_immigration_group()
	_immigration_ready_emitted = pending_migrant_count > 0
	refresh_cooldown_remaining = REFRESH_COOLDOWN
	return true


func _get_group_food() -> float:
	var manager: Node = get_tree().get_first_node_in_group("resource_manager")
	var amount: float = 0.0
	if manager == null:
		return amount
	for food: ResourceData in RESOURCE_DATABASE.resources:
		if food != null and food.is_food() and (current_immigration_group.food_tag == &"" or food.has_tag(current_immigration_group.food_tag)):
			amount += manager.get_total(food.id)
	return amount


func _has_required_building(required: BuildingData) -> bool:
	for building: Node in get_tree().get_nodes_in_group("buildings"):
		if building is ConstructionSite:
			continue
		if building.is_queued_for_deletion() or (building.has_method("is_destroyed") and building.is_destroyed()):
			continue
		if building is BuildingBase and building.demolition_state != BuildingBase.DemolitionState.NONE:
			continue
		if building.has_method("get_building_data"):
			var data: BuildingData = building.get_building_data()
			if data != null and data.id == required.id:
				return true
	return false


func _group_requirements_satisfied() -> bool:
	if _get_group_food() < current_immigration_group.food_amount:
		return false
	for required: BuildingData in current_immigration_group.required_buildings:
		if required != null and not _has_required_building(required):
			return false
	return true


func _get_building_requirements_text() -> String:
	var names: PackedStringArray = []
	for required: BuildingData in current_immigration_group.required_buildings:
		if required != null:
			names.append("%s（%s）" % [required.display_name, "已满足" if _has_required_building(required) else "缺少"])
	return "、".join(names)


func _get_food_tag_name(tag: StringName) -> String:
	if tag == &"":
		return "任意食物"
	for food: ResourceData in RESOURCE_DATABASE.resources:
		if food != null and food.id == tag:
			return food.display_name
	return {&"processed_food": "精致加工食物", &"grain_product": "谷物制品"}.get(tag, String(tag))
