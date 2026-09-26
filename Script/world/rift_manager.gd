class_name RiftManager
extends Node3D

signal rift_changed(active: bool, remaining: float)
signal rift_event_completed(event: LevelEventEntry)

@export var countdown: float = 10.0
@export_range(1, 10, 1) var total_waves: int = 3
@export var wave_interval: float = 5.0
var rift_active: bool = false
var remaining: float = 0.0
var rift_marker: MeshInstance3D = null
var wave_started: bool = false
var current_wave: int = 0
var next_wave_timer: float = 0.0
var active_total_waves: int = 3
var active_wave_interval: float = 5.0
var active_countdown: float = 10.0
var active_monster_group: RaidGroupData
var active_random_total_count: int = 3
var current_event_number: int = 0
var active_event: LevelEventEntry

func _ready() -> void:
	add_to_group("rift_manager")

func _process(delta: float) -> void:
	_process_wave_interval(delta)
	if not rift_active:
		return
	remaining = maxf(remaining - delta, 0.0)
	rift_changed.emit(true, remaining)
	if remaining <= 0.0:
		rift_active = false
		_start_first_wave()
		rift_changed.emit(false, 0.0)

func spawn_rift(event: LevelEventEntry = null) -> bool:
	if rift_active or wave_started:
		return false
	var bounds: Node = get_tree().get_first_node_in_group("world_bounds")
	if bounds == null:
		return false
	var world: AABB = bounds.get_world_bounds()
	var settlement: AABB = bounds.get_settlement_bounds()
	var center: Vector3 = bounds.get_settlement_center()
	var position := _find_safe_rift_position(world, settlement, center)
	if position == Vector3.INF:
		push_warning("裂缝未找到可用陆地点，本次生成已取消")
		return false
	if rift_marker == null:
		rift_marker = MeshInstance3D.new()
		var mesh: CylinderMesh = CylinderMesh.new()
		mesh.top_radius = 0.7
		mesh.bottom_radius = 0.7
		mesh.height = 0.15
		var material: StandardMaterial3D = StandardMaterial3D.new()
		material.albedo_color = Color(0.55, 0.1, 0.9, 1.0)
		material.emission_enabled = true
		material.emission = Color(0.25, 0.05, 0.6, 1.0)
		mesh.material = material
		rift_marker.mesh = mesh
		add_child(rift_marker)
	rift_marker.global_position = position
	rift_marker.show()
	active_monster_group = null if event == null else event.get_monster_group()
	active_event = event
	active_random_total_count = 3 if event == null else event.random_total_count
	active_total_waves = total_waves if event == null else maxi(event.rift_wave_count, 1)
	if active_monster_group != null and active_monster_group.is_boss_group:
		active_total_waves = 1
	active_wave_interval = wave_interval if event == null else maxf(event.rift_wave_interval, 0.0)
	active_countdown = countdown if event == null else maxf(event.rift_countdown, 0.0)
	rift_active = true
	wave_started = false
	current_wave = 0
	next_wave_timer = 0.0
	current_event_number += 1
	remaining = active_countdown
	print("🌀 时间裂缝出现：", position, "，倒计时：", active_countdown)
	rift_changed.emit(true, remaining)
	return true


func _start_first_wave() -> void:
	_start_next_wave()


func _start_next_wave() -> void:
	if wave_started and current_wave >= active_total_waves:
		return
	var raid_manager: RaidSpawnManager = get_tree().get_first_node_in_group("raid_spawn_manager") as RaidSpawnManager
	if raid_manager == null:
		return
	var spawn_origin: Vector3 = rift_marker.global_position if rift_marker != null else Vector3.INF
	var spawned: bool
	if active_monster_group != null:
		spawned = raid_manager.spawn_monster_group(active_monster_group, spawn_origin, active_random_total_count)
	else:
		spawned = raid_manager.spawn_raid(-1, spawn_origin, EnemyData.Faction.RIFT)
	if spawned:
		current_wave += 1
		wave_started = true
		print("🌊 时间裂缝 Wave ", current_wave, " 开始")
		if current_wave >= active_total_waves and is_instance_valid(rift_marker):
			rift_marker.hide()


func _process_wave_interval(delta: float) -> void:
	if not wave_started or rift_active:
		return
	var raid_manager: RaidSpawnManager = get_tree().get_first_node_in_group("raid_spawn_manager") as RaidSpawnManager
	if raid_manager == null or raid_manager.is_faction_in_progress(EnemyData.Faction.RIFT):
		return
	if current_wave >= active_total_waves:
		wave_started = false
		if active_event != null:
			var completed_event: LevelEventEntry = active_event
			active_event = null
			rift_event_completed.emit(completed_event)
		return
	if next_wave_timer <= 0.0:
		next_wave_timer = active_wave_interval
	else:
		next_wave_timer = maxf(next_wave_timer - delta, 0.0)
		if next_wave_timer <= 0.0:
			_start_next_wave()


func get_current_event_number() -> int:
	return current_event_number


func _find_safe_rift_position(world: AABB, settlement: AABB, center: Vector3) -> Vector3:
	var map_generator := get_tree().get_first_node_in_group("map_generate_runtime")
	if map_generator == null or not map_generator.has_method("get_safe_ground_position"):
		return Vector3.INF
	for attempt in range(120):
		var side := randi_range(0, 3)
		var candidate := center
		const OFFSET := 1.5
		if side == 0:
			candidate = Vector3(center.x + randf_range(-settlement.size.x * 0.5, settlement.size.x * 0.5), 0.0, settlement.position.z - OFFSET)
		elif side == 1:
			candidate = Vector3(center.x + randf_range(-settlement.size.x * 0.5, settlement.size.x * 0.5), 0.0, settlement.end.z + OFFSET)
		elif side == 2:
			candidate = Vector3(settlement.position.x - OFFSET, 0.0, center.z + randf_range(-settlement.size.y * 0.5, settlement.size.y * 0.5))
		else:
			candidate = Vector3(settlement.end.x + OFFSET, 0.0, center.z + randf_range(-settlement.size.y * 0.5, settlement.size.y * 0.5))
		candidate.x = clampf(candidate.x, world.position.x + 0.75, world.end.x - 0.75)
		candidate.z = clampf(candidate.z, world.position.z + 0.75, world.end.z - 0.75)
		var safe_position: Vector3 = map_generator.get_safe_ground_position(Vector2(candidate.x, candidate.z))
		if safe_position != Vector3.INF:
			return safe_position
	for attempt in range(240):
		var point := Vector2(
			randf_range(world.position.x + 1.0, world.end.x - 1.0),
			randf_range(world.position.z + 1.0, world.end.z - 1.0)
		)
		var safe_position: Vector3 = map_generator.get_safe_ground_position(point, 1.0)
		if safe_position != Vector3.INF:
			return safe_position
	return Vector3.INF
