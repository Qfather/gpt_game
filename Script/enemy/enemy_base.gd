class_name EnemyBase
extends CharacterBody3D

const LOOT_BUNDLE_SCENE: PackedScene = preload("res://Scene/world/loot_bundle.tscn")

signal enemy_clicked(enemy: EnemyBase)
signal health_changed(current_health: float, max_health: float)

@export var enemy_data: EnemyData

var max_health: float = 0.0
var current_health: float = 0.0
var damage: float = 0.0
var move_speed: float = 0.0
var attack_range: float = 0.0
var attack_interval: float = 0.0
var detection_range: float = 0.0
var raid_steal_timer: float = 0.0
var target: Node3D = null
var attack_cooldown: float = 0.0
var raid_destination: Vector3 = Vector3.ZERO
var raid_spawn_position: Vector3 = Vector3.ZERO
var raid_active: bool = false
var raid_retreating: bool = false
var stolen_resource_amount: float = 0.0
var raid_fallback_resource_id: StringName = &""
var stolen_resources: Dictionary[StringName, float] = {}
var raid_stuck_time: float = 0.0
var raid_last_position: Vector3 = Vector3.ZERO
var death_cleanup_started: bool = false
var death_log_pending: bool = false
var runtime_features: Array[FeatureData] = []
var ability_runtimes: Array[AbilityRuntime] = []
var faction_override: int = -1

signal target_changed(target: Node3D)

@onready var visual_root: Node3D = $VisualRoot
@onready var health_component: Node = $HealthComponent
@onready var navigation_agent: NavigationAgent3D = $NavigationAgent3D


func _ready() -> void:
	add_to_group("enemies")
	input_event.connect(_on_input_event)
	health_component.connect("health_changed", _on_health_changed)
	health_component.connect("died", _on_health_died)
	_apply_enemy_data()
	_create_aggro_range_display()
	call_deferred("_register_with_main")


func _process(_delta: float) -> void:
	update_targeting()


func _physics_process(delta: float) -> void:
	if is_dead():
		velocity = Vector3.ZERO
		return
	if raid_retreating and not is_instance_valid(target):
		var retreat_position: Vector3 = raid_spawn_position
		if retreat_position == Vector3.ZERO:
			retreat_position = raid_destination
		if global_position.distance_to(retreat_position) <= maxf(attack_range, 1.0):
			print("🟠 袭扰单位携带战利品撤离：", get_display_name())
			queue_free()
			return
		_move_toward_navigation_target(retreat_position)
		return
	if not is_instance_valid(target):
		if raid_active:
			_move_toward_navigation_target(raid_destination)
			return
		velocity = Vector3.ZERO
		return

	var target_position: Vector3 = target.global_position
	var flat_target_position: Vector3 = Vector3(
		target_position.x,
		global_position.y,
		target_position.z
	)
	var distance: float = global_position.distance_to(flat_target_position)
	if distance > _get_target_attack_range():
		_move_toward_navigation_target(flat_target_position)
		return

	velocity = Vector3.ZERO
	if (
		_has_raid_objective(EnemyData.RaidObjective.STEAL_RESOURCES)
		and not raid_retreating
		and _is_stealable_target(target)
	):
		raid_steal_timer = maxf(raid_steal_timer - maxf(delta, 0.0), 0.0)
		if raid_steal_timer <= 0.0:
			_steal_from_target(target)
			raid_steal_timer = maxf(enemy_data.raid_steal_interval, 0.1)
		return
	attack_cooldown = maxf(attack_cooldown - maxf(delta, 0.0), 0.0)
	if attack_cooldown > 0.0:
		return
	for ability_runtime: AbilityRuntime in ability_runtimes:
		if ability_runtime.try_use(self, target):
			print("✨ 能力：%s 使用 %s 成功" % [get_display_name(), ability_runtime.ability.display_name])
			break

	if target.has_method("take_damage"):
		var actual_damage: float = float(target.take_damage(damage, self))
		var health_text: String = ""
		if target.has_method("get_health") and target.has_method("get_max_health"):
			health_text = "，剩余生命 %.1f/%.1f" % [
				float(target.get_health()),
				float(target.get_max_health())
			]
		print(
			"⚔️ 战斗：%s 攻击 %s，造成 %.1f 伤害%s"
			% [get_display_name(), _get_target_name(target), actual_damage, health_text]
		)
	attack_cooldown = attack_interval


func _move_toward_navigation_target(target_position: Vector3) -> void:
	if navigation_agent == null:
		velocity = Vector3.ZERO
		return
	var navigation_target: Vector3 = target_position
	navigation_target.y = global_position.y
	navigation_agent.target_desired_distance = maxf(
		_get_target_attack_range() - 0.35,
		0.4
	)
	if navigation_agent.target_position.distance_to(navigation_target) > 0.5:
		navigation_agent.target_position = navigation_target
	if navigation_agent.is_navigation_finished():
		velocity = Vector3.ZERO
		return

	var next_position: Vector3 = navigation_agent.get_next_path_position()
	var direction: Vector3 = next_position - global_position
	direction.y = 0.0
	if direction.length_squared() <= 0.01:
		velocity = Vector3.ZERO
		return
	velocity = direction.normalized() * move_speed
	move_and_slide()

	var moved_distance: float = global_position.distance_to(raid_last_position)
	if raid_last_position == Vector3.ZERO or moved_distance > 0.02:
		raid_last_position = global_position
		raid_stuck_time = 0.0
	else:
		raid_stuck_time += get_physics_process_delta_time()
	if raid_stuck_time >= 1.5:
		raid_stuck_time = 0.0
		navigation_agent.target_position = navigation_target


func _get_target_attack_range() -> float:
	var reach: float = attack_range + 0.25
	if not is_instance_valid(target) or not target.is_in_group("buildings"):
		return reach

	var footprint: Vector2i = target.get("build_grid_size")
	if footprint == Vector2i.ZERO:
		var building_data: BuildingData = target.get("building_data") as BuildingData
		if building_data != null:
			footprint = building_data.grid_size
	if footprint == Vector2i.ZERO:
		return reach + 0.75
	return reach + Vector2(footprint).length() * 0.5


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

	enemy_clicked.emit(self)
	get_viewport().set_input_as_handled()


func _register_with_main() -> void:
	var main_node: Node = get_tree().current_scene
	if main_node != null and main_node.has_method("register_enemy"):
		main_node.register_enemy(self)


func _apply_enemy_data() -> void:
	if enemy_data == null:
		return

	max_health = maxf(enemy_data.max_health, 1.0)
	health_component.call("setup", max_health)
	current_health = float(health_component.get("current_health"))
	health_changed.emit(current_health, max_health)
	damage = maxf(enemy_data.damage, 0.0)
	move_speed = maxf(enemy_data.move_speed, 0.0)
	attack_range = maxf(enemy_data.attack_range, 0.0)
	attack_interval = maxf(enemy_data.attack_interval, 0.0)
	detection_range = maxf(enemy_data.detection_range, 0.0)
	runtime_features = _roll_features(enemy_data.features)
	ability_runtimes = _create_ability_runtimes(enemy_data)
	_apply_visual_scene()
	var health_bar: Node3D = get_node_or_null("HealthBar3D") as Node3D
	if health_bar != null and enemy_data.is_boss:
		health_bar.position.y = 2.85
	var range_display: Node = get_node_or_null("AggroRange")
	if range_display != null and range_display.has_method("set_radius"):
		range_display.set_radius(detection_range)


func _create_aggro_range_display() -> void:
	var range_display: MeshInstance3D = MeshInstance3D.new()
	range_display.name = "AggroRange"
	range_display.set_script(preload("res://Script/combat/aggro_range_3d.gd"))
	range_display.set("radius", detection_range)
	range_display.set("ring_color", Color(1.0, 0.1, 0.1, 0.45))
	range_display.position.y = -0.58
	add_child(range_display)


func take_damage(amount: float, source: Node = null) -> float:
	return float(health_component.call("take_damage", amount, source))


func is_dead() -> bool:
	if health_component == null:
		return false
	return bool(health_component.call("is_dead"))


func get_faction() -> int:
	if faction_override >= 0:
		return faction_override
	if enemy_data == null:
		return EnemyData.Faction.RAID
	return int(enemy_data.faction)


func update_targeting() -> void:
	if is_dead():
		_set_target(null)
		return

	var nearest_combat_target: Node3D = null
	var nearest_distance: float = detection_range
	var combat_targets: Array[Node3D] = []
	var preferred_kill_targets: Array[Node3D] = []
	var candidates: Array[Node] = []
	candidates.append_array(get_tree().get_nodes_in_group("villagers"))
	candidates.append_array(get_tree().get_nodes_in_group("enemies"))
	for candidate: Node in candidates:
		if not candidate is Node3D or candidate == self:
			continue
		if not _is_legal_target(candidate):
			continue

		var candidate_node: Node3D = candidate as Node3D
		var distance: float = global_position.distance_to(
			candidate_node.global_position
		)
		if distance > detection_range:
			continue
		combat_targets.append(candidate_node)
		if (
			_has_raid_objective(EnemyData.RaidObjective.KILL_UNITS)
			and _matches_preferred_kill_target(candidate)
		):
			preferred_kill_targets.append(candidate_node)
		if distance >= nearest_distance:
			continue

		nearest_distance = distance
		nearest_combat_target = candidate_node

	var nearest_target: Node3D = nearest_combat_target
	if _has_raid_objective(EnemyData.RaidObjective.KILL_UNITS):
		var kill_candidates: Array[Node3D] = (
			preferred_kill_targets
			if not preferred_kill_targets.is_empty()
			else combat_targets
		)
		if not kill_candidates.is_empty():
			nearest_target = (
				target if target in kill_candidates else kill_candidates.pick_random()
			)
		else:
			nearest_target = _find_nearest_building_target(false, true)
			if nearest_target == null:
				nearest_target = _find_nearest_base_target()
	if _has_raid_objective(EnemyData.RaidObjective.DESTROY_BUILDINGS):
		var building_target: Node3D = _find_nearest_building_target()
		if building_target != null:
			nearest_target = building_target
	elif _has_raid_objective(EnemyData.RaidObjective.STEAL_RESOURCES):
		var steal_target: Node3D = null
		if not raid_retreating:
			steal_target = _find_nearest_steal_target()
		if steal_target != null:
			nearest_target = steal_target
		else:
			raid_retreating = true

	if (
		nearest_target == null
		and raid_active
		and not _has_configured_raid_objective()
	):
		var base: Node3D = get_tree().get_first_node_in_group("bases") as Node3D
		if is_instance_valid(base) and not _is_base_destroyed(base):
			nearest_target = base

	_set_target(nearest_target)


func _has_raid_objective(objective: EnemyData.RaidObjective) -> bool:
	return (
		raid_active
		and enemy_data != null
		and int(enemy_data.faction) == EnemyData.Faction.RAID
		and enemy_data.raid_objective == objective
	)


func _has_configured_raid_objective() -> bool:
	return (
		raid_active
		and enemy_data != null
		and int(enemy_data.faction) == EnemyData.Faction.RAID
		and enemy_data.raid_objective != EnemyData.RaidObjective.NONE
	)


func _find_nearest_building_target(
	include_bases: bool = true,
	nearest_only: bool = false
) -> Node3D:
	var candidates: Array[Node] = []
	for group_name: StringName in [&"resource_buildings", &"buildings"]:
		candidates.append_array(get_tree().get_nodes_in_group(group_name))
	if include_bases:
		candidates.append_array(get_tree().get_nodes_in_group("bases"))
	var valid_buildings: Array[Node3D] = []
	var checked_ids: Dictionary[int, bool] = {}
	for building: Node in candidates:
		if not is_instance_valid(building):
			continue
		if checked_ids.has(building.get_instance_id()):
			continue
		checked_ids[building.get_instance_id()] = true
		if not include_bases and building.is_in_group("bases"):
			continue
		if not building is Node3D or not building.has_method("take_damage"):
			continue
		if building.has_method("is_destroyed") and building.is_destroyed():
			continue
		valid_buildings.append(building as Node3D)
	var preferred_id: StringName = enemy_data.raid_destroy_building_id
	var preferred_targets: Array[Node3D] = []
	for candidate: Node3D in valid_buildings:
		if _get_building_target_id(candidate) == preferred_id:
			preferred_targets.append(candidate)
	var target_pool: Array[Node3D] = (
		preferred_targets if not preferred_targets.is_empty() else valid_buildings
	)
	if not nearest_only and target in target_pool:
		return target
	if nearest_only:
		var nearest_building: Node3D = null
		var nearest_distance: float = INF
		for building: Node3D in target_pool:
			var distance: float = global_position.distance_squared_to(
				building.global_position
			)
			if distance < nearest_distance:
				nearest_building = building
				nearest_distance = distance
		return nearest_building
	return target_pool.pick_random() if not target_pool.is_empty() else null


func _find_nearest_base_target() -> Node3D:
	var nearest_base: Node3D = null
	var nearest_distance: float = INF
	for candidate: Node in get_tree().get_nodes_in_group("bases"):
		if not is_instance_valid(candidate) or not candidate is Node3D:
			continue
		if not candidate.has_method("take_damage") or _is_base_destroyed(candidate):
			continue
		var distance: float = global_position.distance_squared_to(
			(candidate as Node3D).global_position
		)
		if distance < nearest_distance:
			nearest_base = candidate as Node3D
			nearest_distance = distance
	return nearest_base


func _get_building_target_id(building: Node) -> StringName:
	if building.is_in_group("bases"):
		return &"base"
	var building_data: BuildingData = building.get("building_data") as BuildingData
	return building_data.id if building_data != null else &""


func _matches_preferred_kill_target(candidate: Node) -> bool:
	var preferred_id: StringName = enemy_data.raid_kill_unit_id
	if preferred_id.is_empty():
		return false
	match preferred_id:
		&"villager":
			return candidate.is_in_group("villagers")
		&"swordsman":
			return (
				candidate.is_in_group("villagers")
				and candidate.has_method("get_combat_role")
				and int(candidate.get_combat_role()) == CombatRole.Type.SWORDSMAN
			)
		_:
			return (
				candidate.has_method("get_enemy_id")
				and StringName(candidate.get_enemy_id()) == preferred_id
			)


func _find_nearest_steal_target() -> Node3D:
	var candidates: Array[Node3D] = []
	for storage: Node in get_tree().get_nodes_in_group("resource_storages"):
		var owner: Node3D = storage.get_parent() as Node3D
		if owner != null:
			candidates.append(owner)
	for villager: Node in get_tree().get_nodes_in_group("villagers"):
		if (
			villager is Node3D
			and villager.has_method("get_carried_amount")
		):
			candidates.append(villager as Node3D)

	var preferred_id: StringName = enemy_data.get_raid_steal_resource_id()
	if not preferred_id.is_empty():
		var preferred_target: Node3D = _find_nearest_source_with_resource(candidates, preferred_id)
		if preferred_target != null:
			return preferred_target
	if not raid_fallback_resource_id.is_empty():
		var fallback_target: Node3D = _find_nearest_source_with_resource(
			candidates,
			raid_fallback_resource_id
		)
		if fallback_target != null:
			return fallback_target
		raid_fallback_resource_id = &""

	var available_resource_ids: Array[StringName] = []
	for candidate: Node3D in candidates:
		for resource_id: StringName in _get_source_resource_ids(candidate):
			if resource_id not in available_resource_ids:
				available_resource_ids.append(resource_id)
	if available_resource_ids.is_empty():
		return null
	raid_fallback_resource_id = available_resource_ids.pick_random()
	return _find_nearest_source_with_resource(candidates, raid_fallback_resource_id)


func _find_nearest_source_with_resource(
	candidates: Array[Node3D],
	resource_id: StringName
) -> Node3D:
	var nearest: Node3D = null
	var nearest_distance: float = INF
	for candidate: Node3D in candidates:
		if _get_source_resource_amount(candidate, resource_id) <= 0.0:
			continue
		var distance: float = global_position.distance_to(candidate.global_position)
		if distance < nearest_distance:
			nearest = candidate
			nearest_distance = distance
	return nearest


func _get_source_resource_ids(candidate: Node) -> Array[StringName]:
	if candidate.has_method("get_carried_amount"):
		if float(candidate.get_carried_amount()) <= 0.0:
			return []
		return [StringName(candidate.get_carried_resource_id())]
	var storage: ResourceStorage = candidate.get_node_or_null("ResourceStorage") as ResourceStorage
	if storage == null:
		return []
	var resource_ids: Array[StringName] = []
	for key: Variant in storage.resources.keys():
		var resource_id: StringName = StringName(key)
		if storage.get_amount(resource_id) > 0.0:
			resource_ids.append(resource_id)
	return resource_ids


func _get_source_resource_amount(candidate: Node, resource_id: StringName) -> float:
	if candidate.has_method("get_carried_amount"):
		if StringName(candidate.get_carried_resource_id()) != resource_id:
			return 0.0
		return float(candidate.get_carried_amount())
	var storage: ResourceStorage = candidate.get_node_or_null("ResourceStorage") as ResourceStorage
	return storage.get_amount(resource_id) if storage != null else 0.0


func _is_stealable_target(candidate: Node) -> bool:
	return (
		candidate != null
		and (
			candidate.has_method("steal_carried_resource")
			or candidate.get_node_or_null("ResourceStorage") is ResourceStorage
		)
	)


func _get_available_resource(candidate: Node) -> Dictionary:
	if candidate.has_method("get_carried_amount"):
		var carried: float = float(candidate.get_carried_amount())
		var carried_id: StringName = (
			StringName(candidate.get_carried_resource_id())
			if carried > 0.0
			else &""
		)
		var requested_carried_id: StringName = raid_fallback_resource_id
		var configured_id: StringName = enemy_data.get_raid_steal_resource_id()
		if not configured_id.is_empty() and carried_id == configured_id:
			requested_carried_id = configured_id
		if (
			not requested_carried_id.is_empty()
			and requested_carried_id != carried_id
		):
			return {"resource_id": &"", "amount": 0.0}
		return {
			"resource_id": carried_id,
			"amount": carried,
		}
	var storage: ResourceStorage = candidate.get_node_or_null("ResourceStorage") as ResourceStorage
	if storage == null:
		return {"resource_id": &"", "amount": 0.0}
	var requested_id: StringName = raid_fallback_resource_id
	var configured_id: StringName = enemy_data.get_raid_steal_resource_id()
	if not configured_id.is_empty() and storage.get_amount(configured_id) > 0.0:
		requested_id = configured_id
	if not requested_id.is_empty():
		return {"resource_id": requested_id, "amount": storage.get_amount(requested_id)}
	var selected_id: StringName = &""
	var selected_amount: float = 0.0
	for key: Variant in storage.resources.keys():
		var resource_id: StringName = StringName(key)
		var available: float = storage.get_amount(resource_id)
		if available > selected_amount:
			selected_id = resource_id
			selected_amount = available
	return {"resource_id": selected_id, "amount": selected_amount}


func _steal_from_target(source: Node3D) -> void:
	var available: Dictionary = _get_available_resource(source)
	var resource_id: StringName = StringName(available.get("resource_id", &""))
	var available_amount: float = float(available.get("amount", 0.0))
	var remaining_quota: float = maxf(
		enemy_data.raid_steal_quota - stolen_resource_amount,
		0.0
	)
	var requested_amount: float = minf(
		minf(remaining_quota, maxf(enemy_data.raid_steal_amount_per_tick, 0.0)),
		available_amount
	)
	var taken_amount: float = 0.0
	if requested_amount > 0.0 and not resource_id.is_empty():
		if source.has_method("steal_carried_resource"):
			var stolen: Dictionary = source.steal_carried_resource(requested_amount)
			resource_id = StringName(stolen.get("resource_id", &""))
			taken_amount = float(stolen.get("amount", 0.0))
		else:
			var storage: ResourceStorage = source.get_node_or_null("ResourceStorage") as ResourceStorage
			if storage != null:
				taken_amount = storage.take(resource_id, requested_amount)
	if taken_amount > 0.0:
		stolen_resource_amount += taken_amount
		stolen_resources[resource_id] = (
			float(stolen_resources.get(resource_id, 0.0)) + taken_amount
		)
		var main_node: Node = get_tree().current_scene
		if main_node != null and main_node.has_method("show_resource_loss"):
			main_node.show_resource_loss(source, taken_amount)
		print("🟠 袭扰偷取资源：", source.name, " -", taken_amount, " ", resource_id)
		if stolen_resource_amount >= enemy_data.raid_steal_quota:
			raid_retreating = true
	else:
		print("🟠 袭扰目标已无可偷资源：", source.name)
	_set_target(null)


func _is_base_destroyed(base: Node) -> bool:
	return base.has_method("is_destroyed") and base.is_destroyed()


func _is_legal_target(candidate: Node) -> bool:
	if candidate == null or not is_instance_valid(candidate):
		return false
	if not candidate.is_visible_in_tree():
		return false
	if not candidate.is_in_group("enemies"):
		var raid_hunts_villagers: bool = (
			_has_raid_objective(EnemyData.RaidObjective.KILL_UNITS)
			and candidate.is_in_group("villagers")
		)
		if not raid_hunts_villagers:
			if not candidate.has_method("get_combat_role"):
				return false
			if candidate.has_method("has_combat_role") and not candidate.has_combat_role():
				return false
			if int(candidate.get_combat_role()) == CombatRole.Type.NONE:
				return false
	if candidate.has_method("is_dead") and candidate.is_dead():
		return false
	return candidate.has_method("get_faction") and int(candidate.get_faction()) != get_faction()


func _set_target(next_target: Node3D) -> void:
	if target == next_target:
		return
	target = next_target
	if (
		is_instance_valid(target)
		and _has_raid_objective(EnemyData.RaidObjective.STEAL_RESOURCES)
		and _is_stealable_target(target)
		and raid_steal_timer <= 0.0
	):
		raid_steal_timer = maxf(enemy_data.raid_steal_interval, 0.1)
	if target != null:
		print(
			"⚔️ 战斗：%s 锁定目标：%s"
			% [get_display_name(), _get_target_name(target)]
		)
	else:
		print("⚔️ 战斗：%s 失去目标" % get_display_name())
	target_changed.emit(target)


func _get_target_name(unit: Node) -> String:
	if unit.is_in_group("bases"):
		return "据点"
	if unit.has_method("get_combat_role"):
		if int(unit.get_combat_role()) == CombatRole.Type.SWORDSMAN:
			return "剑士"
	return str(unit.name)


func _on_health_changed(next_health: float, _next_max_health: float) -> void:
	current_health = next_health
	health_changed.emit(current_health, max_health)


func _on_health_died(_source: Node) -> void:
	if death_cleanup_started:
		return
	death_cleanup_started = true
	_drop_stolen_loot()
	death_log_pending = true
	velocity = Vector3.ZERO
	set_process(false)
	set_physics_process(false)
	collision_layer = 0
	collision_mask = 0
	remove_from_group("enemies")
	target = null
	hide()
	call_deferred("_print_death_log")
	var death_timer: SceneTreeTimer = get_tree().create_timer(0.35)
	death_timer.timeout.connect(_finish_death_cleanup)


func _drop_stolen_loot() -> void:
	if stolen_resources.is_empty():
		return
	var current_scene: Node = get_tree().current_scene
	if current_scene == null:
		return
	var container: Node = current_scene.get_node_or_null("LootBundles")
	if container == null:
		container = current_scene
	var bundle: LootBundle = LOOT_BUNDLE_SCENE.instantiate() as LootBundle
	if bundle == null:
		return
	bundle.configure_resources(stolen_resources)
	container.add_child(bundle)
	bundle.global_position = Vector3(global_position.x, 0.0, global_position.z)
	print("📦 袭扰单位死亡，掉落一个战利品包裹：", stolen_resources)
	stolen_resources.clear()
	stolen_resource_amount = 0.0


func _print_death_log() -> void:
	if not death_log_pending:
		return
	death_log_pending = false
	print("⚔️ 战斗：%s 已死亡" % get_display_name())


func _finish_death_cleanup() -> void:
	if is_instance_valid(self):
		queue_free()


func _apply_visual_scene() -> void:
	if enemy_data.visual_scene == null or visual_root == null:
		return

	for child: Node in visual_root.get_children():
		child.queue_free()

	var visual_instance: Node = enemy_data.visual_scene.instantiate()
	if visual_instance != null:
		visual_root.add_child(visual_instance)
	_apply_visual_tint()


func _apply_visual_tint() -> void:
	if enemy_data == null or enemy_data.visual_tint == Color.WHITE:
		return
	for node: Node in visual_root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance: MeshInstance3D = node as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null:
			continue
		var material: Material = mesh_instance.get_active_material(0)
		if material == null:
			continue
		var tinted_material: Material = material.duplicate()
		if tinted_material is StandardMaterial3D:
			(tinted_material as StandardMaterial3D).albedo_color *= enemy_data.visual_tint
			mesh_instance.set_surface_override_material(0, tinted_material)


func get_enemy_id() -> StringName:
	if enemy_data == null:
		return &""
	return enemy_data.id


func get_display_name() -> String:
	if enemy_data == null:
		return "未配置敌人"
	return enemy_data.display_name


func get_abilities() -> Array[Resource]:
	if enemy_data == null:
		return []
	return enemy_data.abilities


func get_ability_runtimes() -> Array[AbilityRuntime]:
	return ability_runtimes.duplicate()


func _create_ability_runtimes(data: EnemyData) -> Array[AbilityRuntime]:
	var runtimes: Array[AbilityRuntime] = []
	if data == null:
		return runtimes
	if not data.ability_entries.is_empty():
		for entry: AbilityEntry in data.ability_entries:
			if entry != null and entry.ability != null:
				runtimes.append(AbilityRuntime.new(entry.ability, entry))
		return runtimes
	for ability_resource: Resource in data.abilities:
		var ability: EnemyAbility = ability_resource as EnemyAbility
		if ability != null:
			runtimes.append(AbilityRuntime.new(ability))
	return runtimes


func get_features() -> Array[FeatureData]:
	return runtime_features.duplicate()


func get_feature_descriptors() -> Array[FeatureData]:
	var descriptors: Array[FeatureData] = get_features()
	for ability_resource: Resource in get_abilities():
		var ability: EnemyAbility = ability_resource as EnemyAbility
		if ability != null:
			descriptors.append(FeatureAdapter.from_ability(ability))
	return descriptors


func _roll_features(entries: Array[FeatureEntry]) -> Array[FeatureData]:
	var rolled: Array[FeatureData] = []
	for entry: FeatureEntry in entries:
		if entry == null or not entry.enabled or entry.feature == null:
			continue
		if randf() <= clampf(entry.chance, 0.0, 1.0):
			rolled.append(entry.feature)
	return rolled
