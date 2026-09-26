class_name RaidSpawnManager
extends Node

const ENEMY_SCENE: PackedScene = preload("res://Scene/unit/enemy_base.tscn")
const SLIME_DATA: EnemyData = preload("res://data/enemies/raid/SlimeData.tres")
const WOLF_DATA: EnemyData = preload("res://data/enemies/raid/WolfData.tres")
const RIFT_SLIME_DATA: EnemyData = preload("res://data/enemies/rift/SlimeData.tres")
const RIFT_WOLF_DATA: EnemyData = preload("res://data/enemies/rift/WolfData.tres")

@export_range(2, 4, 1) var default_raid_size: int = 3
var raid_in_progress: bool = false
var active_raid_enemies: Array[Node] = []


func _ready() -> void:
	add_to_group("raid_spawn_manager")


func _process(_delta: float) -> void:
	var had_active_raid: bool = raid_in_progress
	var valid_enemies: Array[Node] = []
	for enemy_value in active_raid_enemies:
		if not is_instance_valid(enemy_value):
			continue
		var enemy: Node = enemy_value as Node
		if enemy == null or (enemy.has_method("is_dead") and enemy.is_dead()):
			continue
		valid_enemies.append(enemy)
	active_raid_enemies = valid_enemies
	raid_in_progress = not active_raid_enemies.is_empty()
	if had_active_raid and not raid_in_progress:
		print("✅ 第三方袭扰结束，可以生成下一批")


func spawn_raid(
	enemy_count: int = -1,
	spawn_origin: Vector3 = Vector3.INF,
	faction: int = EnemyData.Faction.RAID,
	enemy_data_override: EnemyData = null
) -> bool:
	if is_faction_in_progress(faction):
		return false
	var scene: Node = get_tree().current_scene
	var enemies_container: Node = scene.get_node_or_null("Enemies")
	var world_bounds: Node = get_tree().get_first_node_in_group("world_bounds")
	var base: Node3D = get_tree().get_first_node_in_group("bases") as Node3D
	if enemies_container == null or world_bounds == null or base == null:
		return false

	var count: int = enemy_count
	if count < 1:
		count = randi_range(2, 4) if enemy_count < 0 else default_raid_size
	var settlement_center: Vector3 = base.global_position
	if base.has_method("get_interaction_position"):
		settlement_center = base.get_interaction_position(null)
	var spawn_points: Array[Vector3] = (
		_get_rift_spawn_points(spawn_origin, count, world_bounds)
		if spawn_origin != Vector3.INF
		else _get_spawn_points(world_bounds, count)
	)
	if spawn_points.is_empty():
		push_warning("袭扰暂未生成：没有足够的可达安全出生点")
		return false
	for index: int in range(count):
		var enemy: Node3D = ENEMY_SCENE.instantiate() as Node3D
		if enemy == null:
			continue
		var is_rift: bool = faction == EnemyData.Faction.RIFT
		var selected_data: EnemyData = enemy_data_override if enemy_data_override != null else (
			RIFT_WOLF_DATA if index == count - 1 else RIFT_SLIME_DATA
		) if is_rift else (
			WOLF_DATA if index == count - 1 else SLIME_DATA
		)
		enemy.set("enemy_data", selected_data)
		enemy.set("faction_override", faction)
		enemy.set("raid_destination", settlement_center)
		enemy.set("raid_active", true)
		enemies_container.add_child(enemy)
		enemy.global_position = spawn_points[index % spawn_points.size()]
		enemy.set("raid_spawn_position", enemy.global_position)
		active_raid_enemies.append(enemy)

	raid_in_progress = true
	print("⚠️ 第三方袭扰开始：生成 ", count, " 个敌人")
	return true


func spawn_raid_group(raid_group: RaidGroupData, fixed_count: int = -1) -> bool:
	if raid_group == null:
		return false
	var valid_units: Array[EnemyData] = raid_group.get_valid_units()
	if valid_units.is_empty():
		return false
	var scene: Node = get_tree().current_scene
	var enemies_container: Node = scene.get_node_or_null("Enemies")
	var world_bounds: Node = get_tree().get_first_node_in_group("world_bounds")
	var base: Node3D = get_tree().get_first_node_in_group("bases") as Node3D
	if enemies_container == null or world_bounds == null or base == null:
		return false
	var count: int = maxi(fixed_count, 1) if fixed_count > 0 else clampi(raid_group.get_random_count(), 1, valid_units.size())
	var settlement_center: Vector3 = base.global_position
	if base.has_method("get_interaction_position"):
		settlement_center = base.get_interaction_position(null)
	var spawn_points: Array[Vector3] = _get_spawn_points(world_bounds, count)
	if spawn_points.is_empty():
		push_warning("袭扰暂未生成：没有足够的可达安全出生点")
		return false
	for index: int in range(count):
		var enemy: Node3D = ENEMY_SCENE.instantiate() as Node3D
		var selected_data: EnemyData = valid_units[index % valid_units.size()]
		if enemy == null or selected_data == null:
			continue
		enemy.set("enemy_data", selected_data)
		enemy.set("faction_override", EnemyData.Faction.RAID)
		enemy.set("raid_destination", settlement_center)
		enemy.set("raid_active", true)
		enemies_container.add_child(enemy)
		enemy.global_position = spawn_points[index % spawn_points.size()]
		enemy.set("raid_spawn_position", enemy.global_position)
		active_raid_enemies.append(enemy)
	raid_in_progress = not active_raid_enemies.is_empty()
	if raid_in_progress:
		print("🟠 支线袭扰开始：", raid_group.display_name, "，生成 ", count, " 个敌人")
	return raid_in_progress


func spawn_monster_group(
	monster_group: RaidGroupData,
	spawn_origin: Vector3 = Vector3.INF,
	random_count: int = -1
) -> bool:
	if monster_group == null:
		return false
	var spawn_plan: Array[EnemyData] = monster_group.get_spawn_plan(random_count)
	if spawn_plan.is_empty():
		return false
	var scene: Node = get_tree().current_scene
	var enemies_container: Node = scene.get_node_or_null("Enemies")
	var world_bounds: Node = get_tree().get_first_node_in_group("world_bounds")
	var base: Node3D = get_tree().get_first_node_in_group("bases") as Node3D
	if enemies_container == null or world_bounds == null or base == null:
		return false
	var settlement_center: Vector3 = base.global_position
	if base.has_method("get_interaction_position"):
		settlement_center = base.get_interaction_position(null)
	var spawn_points: Array[Vector3] = (
		_get_rift_spawn_points(spawn_origin, spawn_plan.size(), world_bounds)
		if spawn_origin != Vector3.INF
		else _get_spawn_points(world_bounds, spawn_plan.size())
	)
	if spawn_points.is_empty():
		push_warning("怪物组暂未生成：没有足够的可达安全出生点")
		return false
	var faction: int = (
		EnemyData.Faction.RIFT
		if monster_group.group_type == RaidGroupData.GroupType.RIFT
		else EnemyData.Faction.RAID
	)
	var spawned_count: int = 0
	for index: int in range(spawn_plan.size()):
		var enemy: Node3D = ENEMY_SCENE.instantiate() as Node3D
		if enemy == null or spawn_plan[index] == null:
			continue
		enemy.set("enemy_data", spawn_plan[index])
		enemy.set("faction_override", faction)
		enemy.set("raid_destination", settlement_center)
		enemy.set("raid_active", true)
		enemies_container.add_child(enemy)
		enemy.global_position = spawn_points[index % spawn_points.size()]
		enemy.set("raid_spawn_position", enemy.global_position)
		active_raid_enemies.append(enemy)
		spawned_count += 1
	if spawned_count == 0:
		return false
	raid_in_progress = true
	print("👹 怪物组出现：", monster_group.display_name, "，生成 ", spawn_plan.size(), " 个单位")
	return true


func is_faction_in_progress(faction: int) -> bool:
	for enemy_value in active_raid_enemies:
		if not is_instance_valid(enemy_value):
			continue
		var enemy: Node = enemy_value as Node
		if enemy == null:
			continue
		if enemy.has_method("is_dead") and enemy.is_dead():
			continue
		if enemy.has_method("get_faction") and int(enemy.get_faction()) == faction:
			return true
	return false


func _get_spawn_points(world_bounds: Node, count: int = 4) -> Array[Vector3]:
	var bounds: AABB = world_bounds.get_world_bounds()
	var half_size: Vector2 = Vector2(bounds.size.x, bounds.size.z) * 0.5
	var center: Vector3 = world_bounds.get_settlement_center()
	var margin: float = 1.0
	var origins: Array[Vector3] = [
		center + Vector3(-half_size.x + margin, 0.6, 0.0),
		center + Vector3(half_size.x - margin, 0.6, 0.0),
		center + Vector3(0.0, 0.6, -half_size.y + margin),
		center + Vector3(0.0, 0.6, half_size.y - margin),
	]
	var result: Array[Vector3] = []
	for index: int in range(count):
		var origin: Vector3 = origins[index % origins.size()]
		var position: Vector3 = _find_reachable_spawn(Vector2(origin.x, origin.z), result)
		if position == Vector3.INF:
			return []
		result.append(position)
	return result


func _find_reachable_spawn(desired: Vector2, occupied: Array[Vector3], minimum_base_distance: float = 0.0) -> Vector3:
	var runtime: MapGenerateRuntime = get_tree().get_first_node_in_group("map_generate_runtime") as MapGenerateRuntime
	if runtime == null or runtime.map_data == null:
		return Vector3.INF
	var candidates: Array[Vector3] = []
	var base: Node3D = get_tree().get_first_node_in_group("bases") as Node3D
	for cell: Vector2i in runtime.map_data.occupied_cells:
		var point: Vector3 = runtime._cell_world_position(cell)
		if base != null and Vector2(point.x - base.global_position.x, point.z - base.global_position.z).length() < minimum_base_distance:
			continue
		candidates.append(point)
	candidates.sort_custom(func(a: Vector3, b: Vector3) -> bool:
		return Vector2(a.x, a.z).distance_squared_to(desired) < Vector2(b.x, b.z).distance_squared_to(desired))
	for candidate: Vector3 in candidates:
		var free: bool = true
		for other: Vector3 in occupied:
			if Vector2(candidate.x - other.x, candidate.z - other.z).length() < 1.1:
				free = false
				break
		if not free:
			continue
		var ground: Vector3 = runtime.get_safe_ground_position(Vector2(candidate.x, candidate.z), 0.75)
		if ground != Vector3.INF:
			return ground + Vector3.UP * 0.6
	return Vector3.INF


func _get_rift_spawn_points(
	origin: Vector3,
	count: int,
	world_bounds_node: Node
) -> Array[Vector3]:
	var result: Array[Vector3] = []
	var bounds: AABB = world_bounds_node.get_world_bounds()
	var rift_manager: RiftManager = get_tree().get_first_node_in_group("rift_manager") as RiftManager
	var minimum_distance: float = rift_manager.minimum_base_distance if rift_manager != null else 30.0
	var bounds_center: Vector3 = bounds.get_center()
	var inward: Vector2 = Vector2(bounds_center.x - origin.x, bounds_center.z - origin.z).normalized()
	if inward.length_squared() <= 0.01:
		inward = Vector2(0.0, -1.0)
	var tangent := Vector2(-inward.y, inward.x)
	var columns_per_row: int = 5
	var spacing: float = 1.4
	var edge_margin: float = 0.8
	var min_x: float = bounds.position.x + edge_margin
	var max_x: float = bounds.end.x - edge_margin
	var min_z: float = bounds.position.z + edge_margin
	var max_z: float = bounds.end.z - edge_margin

	for index: int in range(maxi(count, 1)):
		var row: int = floori(float(index) / float(columns_per_row))
		var row_start: int = row * columns_per_row
		var row_count: int = mini(columns_per_row, count - row_start)
		var column: int = index - row_start
		var lateral_offset: float = (float(column) - float(row_count - 1) * 0.5) * spacing
		var desired_xz: Vector2 = (
			Vector2(origin.x, origin.z)
			+ inward * (0.9 + float(row) * spacing)
			+ tangent * lateral_offset
		)
		desired_xz.x = clampf(desired_xz.x, min_x, max_x)
		desired_xz.y = clampf(desired_xz.y, min_z, max_z)
		var spawn_position: Vector3 = _find_reachable_spawn(desired_xz, result, minimum_distance)
		if spawn_position == Vector3.INF:
			return []
		result.append(spawn_position)
	return result
