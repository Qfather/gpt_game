class_name RaidSpawnManager
extends Node

const ENEMY_SCENE: PackedScene = preload("res://Scene/unit/enemy_base.tscn")
const SLIME_DATA: EnemyData = preload("res://data/combat/SlimeData.tres")
const WOLF_DATA: EnemyData = preload("res://data/combat/WolfData.tres")

@export_range(2, 4, 1) var default_raid_size: int = 3
var raid_in_progress: bool = false
var active_raid_enemies: Array[Node] = []


func _process(_delta: float) -> void:
	if not raid_in_progress:
		return
	for enemy: Node in active_raid_enemies.duplicate():
		if (
			not is_instance_valid(enemy)
			or (enemy.has_method("is_dead") and enemy.is_dead())
		):
			active_raid_enemies.erase(enemy)
	if active_raid_enemies.is_empty():
		raid_in_progress = false
		print("✅ 第三方袭扰结束，可以生成下一批")


func spawn_raid(enemy_count: int = -1) -> bool:
	if raid_in_progress:
		return false
	var scene: Node = get_tree().current_scene
	var enemies_container: Node = scene.get_node_or_null("Enemies")
	var world_bounds: Node = get_tree().get_first_node_in_group("world_bounds")
	var base: Node3D = get_tree().get_first_node_in_group("bases") as Node3D
	if enemies_container == null or world_bounds == null or base == null:
		return false

	var count: int = enemy_count
	if count < 2 or count > 4:
		count = randi_range(2, 4) if enemy_count < 0 else default_raid_size
	var settlement_center: Vector3 = base.global_position
	if base.has_method("get_interaction_position"):
		settlement_center = base.get_interaction_position(null)
	var spawn_points: Array[Vector3] = _get_spawn_points(world_bounds)
	for index: int in range(count):
		var enemy: Node3D = ENEMY_SCENE.instantiate() as Node3D
		if enemy == null:
			continue
		enemy.set("enemy_data", WOLF_DATA if index == count - 1 else SLIME_DATA)
		enemy.set("raid_destination", settlement_center)
		enemy.set("raid_active", true)
		enemies_container.add_child(enemy)
		enemy.global_position = spawn_points[index % spawn_points.size()]
		active_raid_enemies.append(enemy)

	raid_in_progress = true
	print("⚠️ 第三方袭扰开始：生成 ", count, " 个敌人")
	return true


func _get_spawn_points(world_bounds: Node) -> Array[Vector3]:
	var bounds: AABB = world_bounds.get_world_bounds()
	var half_size: Vector2 = Vector2(bounds.size.x, bounds.size.z) * 0.5
	var center: Vector3 = world_bounds.get_settlement_center()
	var margin: float = 1.0
	return [
		center + Vector3(-half_size.x + margin, 0.6, 0.0),
		center + Vector3(half_size.x - margin, 0.6, 0.0),
		center + Vector3(0.0, 0.6, -half_size.y + margin),
		center + Vector3(0.0, 0.6, half_size.y - margin),
	]
