extends SceneTree

const DETAIL_KEYS: Array[String] = ["unit_avoidance", "road_next_position", "resident_render_tick", "resident_needs", "resident_hostile_scan", "resident_retreat", "resident_combat", "building_entrance_search", "enemy_wall_raycast", "main_render_tick", "hud_render_tick"]

# 计时仅存在于压力测试子类中，不修改游戏脚本。
class Timings:
	static var unit_usec: int = 0
	static var navigation_usec: int = 0
	static var shelter_usec: int = 0
	static var enemy_usec: int = 0
	static var enemy_navigation_usec: int = 0
	static var enemy_targeting_usec: int = 0
	static var resident_physics_calls: int = 0
	static var detail_usec: Dictionary = {}
	static var detail_calls: Dictionary = {}
	static func record(key: String, started: int) -> void:
		detail_usec[key] = detail_usec.get(key, 0) + Time.get_ticks_usec() - started
		detail_calls[key] = detail_calls.get(key, 0) + 1
	static func take() -> Dictionary:
		var values := {"resident_script": unit_usec / 1000.0, "resident_navigation": navigation_usec / 1000.0, "shelter_selection": shelter_usec / 1000.0, "enemy_script": enemy_usec / 1000.0, "enemy_navigation": enemy_navigation_usec / 1000.0, "enemy_targeting": enemy_targeting_usec / 1000.0}
		values.resident_physics_calls = resident_physics_calls
		for key: String in detail_usec: values[key] = detail_usec[key] / 1000.0
		values.detail_calls = detail_calls.duplicate()
		detail_usec.clear()
		detail_calls.clear()
		unit_usec = 0
		navigation_usec = 0
		shelter_usec = 0
		enemy_usec = 0
		enemy_navigation_usec = 0
		enemy_targeting_usec = 0
		resident_physics_calls = 0
		return values

class MeasuredAvoidance extends "res://Script/unit/unit_avoidance.gd":
	static var bypass: bool = false
	func steer(body: CharacterBody3D, agent: NavigationAgent3D, desired: Vector3, delta: float) -> Vector3:
		if bypass: return desired
		var started := Time.get_ticks_usec()
		var result := super.steer(body, agent, desired, delta)
		Timings.record("unit_avoidance", started)
		return result

class MeasuredRoadNavigation extends "res://Script/unit/road_navigation.gd":
	func next_position(unit: Node3D, agent: NavigationAgent3D) -> Vector3:
		var started := Time.get_ticks_usec()
		var result := super.next_position(unit, agent)
		Timings.record("road_next_position", started)
		return result

class MeasuredMain extends "res://Script/main.gd":
	func _process(delta: float) -> void:
		var started := Time.get_ticks_usec()
		super._process(delta)
		Timings.record("main_render_tick", started)

class MeasuredHUD extends "res://Script/ui/hud.gd":
	func _process(delta: float) -> void:
		var started := Time.get_ticks_usec()
		super._process(delta)
		Timings.record("hud_render_tick", started)

class MeasuredResident extends "res://Script/unit/game/villager.gd":
	func _ready():
		unit_avoidance = MeasuredAvoidance.new()
		road_navigation = MeasuredRoadNavigation.new()
		super._ready()
	func _process(delta: float) -> void:
		var started := Time.get_ticks_usec()
		super._process(delta)
		Timings.record("resident_render_tick", started)
	func update_needs(delta: float) -> void:
		var started := Time.get_ticks_usec()
		super.update_needs(delta)
		Timings.record("resident_needs", started)
	func _find_nearest_hostile(search_range: float = -1.0) -> Node3D:
		var started := Time.get_ticks_usec()
		var result := super._find_nearest_hostile(search_range)
		Timings.record("resident_hostile_scan", started)
		return result
	func _process_civilian_retreat(delta: float) -> bool:
		var started := Time.get_ticks_usec()
		var result := super._process_civilian_retreat(delta)
		Timings.record("resident_retreat", started)
		return result
	func _process_combat(delta: float) -> bool:
		var started := Time.get_ticks_usec()
		var result := super._process_combat(delta)
		Timings.record("resident_combat", started)
		return result
	func _get_reachable_building_entrance(building: BuildingBase) -> Vector3:
		var started := Time.get_ticks_usec()
		var result := super._get_reachable_building_entrance(building)
		Timings.record("building_entrance_search", started)
		return result
	func get_max_health() -> float:
		return 100000.0
	func _physics_process(delta):
		Timings.resident_physics_calls += 1
		var start := Time.get_ticks_usec()
		super._physics_process(delta)
		Timings.unit_usec += Time.get_ticks_usec() - start
	func move_along_navigation():
		var start := Time.get_ticks_usec()
		super.move_along_navigation()
		Timings.navigation_usec += Time.get_ticks_usec() - start
	func _select_retreat_destination(excluded: BuildingBase = null) -> void:
		var start := Time.get_ticks_usec()
		super._select_retreat_destination(excluded)
		Timings.shelter_usec += Time.get_ticks_usec() - start

class MeasuredEnemy extends "res://Script/enemy/enemy_base.gd":
	func _ready() -> void:
		unit_avoidance = MeasuredAvoidance.new()
		super._ready()
	func _find_blocking_wall(destination: Vector3) -> Wall:
		var started := Time.get_ticks_usec()
		var result := super._find_blocking_wall(destination)
		Timings.record("enemy_wall_raycast", started)
		return result
	func _process(delta: float) -> void:
		var start := Time.get_ticks_usec()
		super._process(delta)
		Timings.enemy_targeting_usec += Time.get_ticks_usec() - start
	func _physics_process(delta: float) -> void:
		var start := Time.get_ticks_usec()
		super._physics_process(delta)
		Timings.enemy_usec += Time.get_ticks_usec() - start
	func _move_toward_navigation_target(point: Vector3, close_approach: bool = false) -> void:
		var start := Time.get_ticks_usec()
		super._move_toward_navigation_target(point, close_approach)
		Timings.enemy_navigation_usec += Time.get_ticks_usec() - start

class MeasuredFog extends "res://Script/world/fog_of_war.gd":
	var samples: Dictionary = {}
	var current: Dictionary = {}
	var frozen: bool = false
	func _record(key: String, start: int) -> void:
		current[key] = current.get(key, 0.0) + (Time.get_ticks_usec() - start) / 1000.0
	func refresh_visibility() -> void:
		if frozen:
			refresh_queued = false
			return
		current = {}
		var start := Time.get_ticks_usec()
		super.refresh_visibility()
		_record("total", start)
		current["pixel_merge"] = current.get("reveal", 0.0) - current.get("occlusion_angles", 0.0) - current.get("angle_smoothing", 0.0)
		current["other_collection_copy_upload"] = current.total - current.get("collect_trees", 0.0) - current.get("reveal", 0.0) - current.get("canopies", 0.0) - current.get("object_visibility", 0.0)
		for key: String in current:
			if not samples.has(key): samples[key] = []
			samples[key].append(current[key])
	func _collect_tree_occluders() -> Array[Vector3]:
		var start := Time.get_ticks_usec()
		var result := super._collect_tree_occluders()
		_record("collect_trees", start)
		return result
	func _reveal_at(point: Vector3, radius: float = SIGHT_RADIUS, trees: Array[Vector3] = []) -> void:
		var start := Time.get_ticks_usec()
		super._reveal_at(point, radius, trees)
		_record("reveal", start)
	func _tree_sight_limits(origin: Vector2, radius: float = SIGHT_RADIUS, trees: Array[Vector3] = []) -> PackedFloat32Array:
		var start := Time.get_ticks_usec()
		var result := super._tree_sight_limits(origin, radius, trees)
		_record("occlusion_angles", start)
		return result
	func _smooth_sight_limits(limits: PackedFloat32Array) -> PackedFloat32Array:
		var start := Time.get_ticks_usec()
		var result := super._smooth_sight_limits(limits)
		_record("angle_smoothing", start)
		return result
	func _reveal_visible_tree_canopies() -> void:
		var start := Time.get_ticks_usec()
		super._reveal_visible_tree_canopies()
		_record("canopies", start)
	func _refresh_object_visibility() -> void:
		var start := Time.get_ticks_usec()
		super._refresh_object_visibility()
		_record("object_visibility", start)

var main: Node3D
var fog: MeasuredFog
var residents: Array[Node] = []
var enemies: Array[Node] = []
var report: Dictionary = {}

func _initialize() -> void:
	call_deferred("_run")

func _statistics(values: Array) -> Dictionary:
	if values.is_empty(): return {"count": 0}
	values.sort()
	var total: float = 0.0
	for value: float in values: total += value
	return {"count": values.size(), "mean": total / values.size(), "p50": values[values.size() / 2], "p95": values[mini(ceili(values.size() * 0.95) - 1, values.size() - 1)], "max": values.back()}

func _sample(label: String, frames: int) -> void:
	fog.samples.clear()
	Timings.take()
	var measurements: Dictionary = {"frame": [], "engine_physics_tick": []}
	var physics_steps: Array = []
	var call_measurements: Dictionary = {}
	var engine_counts: Dictionary = {"draw_calls": [], "primitives": [], "collision_pairs": [], "nodes": [], "orphan_nodes": []}
	for key: String in DETAIL_KEYS:
		measurements[key] = []
		call_measurements[key] = []
	var slow_frames: Dictionary = {"over_33ms": 0, "over_66ms": 0, "over_142ms": 0}
	var previous: int = Time.get_ticks_usec()
	for frame: int in range(frames):
		await process_frame
		var now: int = Time.get_ticks_usec()
		measurements.frame.append((now - previous) / 1000.0)
		var frame_ms: float = (now - previous) / 1000.0
		if frame_ms > 33.333: slow_frames.over_33ms += 1
		if frame_ms > 66.667: slow_frames.over_66ms += 1
		if frame_ms > 142.857: slow_frames.over_142ms += 1
		previous = now
		measurements.engine_physics_tick.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
		engine_counts.draw_calls.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		engine_counts.primitives.append(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
		engine_counts.collision_pairs.append(Performance.get_monitor(Performance.PHYSICS_3D_COLLISION_PAIRS))
		engine_counts.nodes.append(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
		engine_counts.orphan_nodes.append(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
		var values: Dictionary = Timings.take()
		physics_steps.append(values.resident_physics_calls / float(residents.size()))
		values.erase("resident_physics_calls")
		var calls: Dictionary = values.detail_calls
		values.erase("detail_calls")
		for key: String in DETAIL_KEYS:
			call_measurements[key].append(calls.get(key, 0))
			measurements[key].append(values.get(key, 0.0))
			values.erase(key)
		for key: String in values:
			if not measurements.has(key): measurements[key] = []
			measurements[key].append(values[key])
	var result: Dictionary = {"frames_ms": {}, "fog_refresh_ms": {}, "resident_states": {}}
	result.physics_steps_per_frame = _statistics(physics_steps)
	result.calls_per_frame = {}
	for key: String in call_measurements: result.calls_per_frame[key] = _statistics(call_measurements[key])
	result.engine_counts = {}
	for key: String in engine_counts: result.engine_counts[key] = _statistics(engine_counts[key])
	result.slow_frames = slow_frames
	for key: String in measurements: result.frames_ms[key] = _statistics(measurements[key])
	for key: String in fog.samples: result.fog_refresh_ms[key] = _statistics(fog.samples[key])
	for resident: Node in residents:
		if not is_instance_valid(resident): continue
		var state_name: String = resident.State.keys()[resident.state]
		result.resident_states[state_name] = result.resident_states.get(state_name, 0) + 1
	result.live_residents = get_nodes_in_group("villagers").size()
	result.live_enemies = get_nodes_in_group("enemies").size()
	report.phases[label] = result
	print("STRESS ", label, " ", JSON.stringify(result))

func _building(scene_name: String, data_name: String, offset: Vector3) -> Node3D:
	var building: Node3D = load("res://Scene/building/game/" + scene_name + ".tscn").instantiate()
	building.building_data = load("res://data/buildings/" + data_name + ".tres").duplicate(true)
	building.building_data.max_health = 100000.0
	main.add_child(building)
	building.global_position = get_first_node_in_group("bases").global_position + offset
	main.register_building(building)
	return building

func _run() -> void:
	var population: int = 11
	var speed: float = 3.0
	var shelter_capacity: int = 0
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--population="): population = int(argument.get_slice("=", 1))
		if argument.begins_with("--speed="): speed = float(argument.get_slice("=", 1))
		if argument.begins_with("--shelter-capacity="): shelter_capacity = int(argument.get_slice("=", 1))
	seed(418)
	main = load("res://Scene/main.tscn").instantiate()
	main.set_script(MeasuredMain)
	main.get_node("UI/HUD").set_script(MeasuredHUD)
	main.level_preset = main.level_preset.duplicate(true)
	main.level_preset.layout_seed = 418
	main.level_preset.events.clear()
	main.level_preset.camp_config.enabled = false
	root.add_child(main)
	current_scene = main
	for frame: int in range(90): await physics_frame
	main.get_node("Systems/PopulationManager").set_process(false)
	main.get_node("Systems/EncounterDirector").elapsed_time = 1140
	for unit: Node in get_nodes_in_group("villagers"): unit.queue_free()
	get_first_node_in_group("fog_of_war").free()
	fog = MeasuredFog.new()
	main.add_child(fog)
	var base: Node3D = get_first_node_in_group("bases")
	base.durability.setup(100000.0)
	var farm := _building("farm", "FarmData", Vector3(5, 0, 0))
	var lumber := _building("lumber_camp", "LumberCampData", Vector3(-5, 0, 0))
	var hut := _building("hunter_hut", "HunterHutData", Vector3(0, 0, -5))
	var house := _building("house", "HouseData", Vector3(-5, 0, -5))
	if shelter_capacity > 0: house.housing_capacity = shelter_capacity
	for index: int in range(population):
		var unit: Node = load("res://Scene/unit/villager.tscn").instantiate()
		unit.set_script(MeasuredResident)
		main.add_child(unit)
		unit.global_position = base.global_position + Vector3((index % 11 - 5) * 0.7, 0, 3 + index / 11 * 0.8)
		unit.health_component.setup(100000.0)
		residents.append(unit)
	for frame: int in range(15): await physics_frame
	for index: int in range(population):
		if index < 3: farm.add_worker(residents[index])
		elif index < 6: lumber.add_worker(residents[index])
		elif index == 6: hut.add_worker(residents[index])
		elif index % 5 == 3: residents[index].set_combat_role(CombatRole.Type.SWORDSMAN)
	Engine.time_scale = speed
	report = {"population": population, "enemy_count": maxi(5, population * 5 / 11), "speed": speed, "seed": 418, "renderer": RenderingServer.get_current_rendering_method(), "phases": {}}
	report.shelter_capacity_override = shelter_capacity
	await _sample("no_enemies", 240)
	for index: int in range(report.enemy_count):
		var enemy: Node = load("res://Scene/unit/enemy_base.tscn").instantiate()
		enemy.set_script(MeasuredEnemy)
		enemy.enemy_data = load("res://data/enemies/raid/SlimeData.tres").duplicate(true)
		enemy.enemy_data.max_health = 100000.0
		main.add_child(enemy)
		enemy.global_position = base.global_position + Vector3((index % 7 - 3) * 0.6, 0, 7 + index / 7 * 0.6)
		main.register_enemy(enemy)
		enemies.append(enemy)
	await _sample("raid_arrival", 360)
	await _sample("raid_settled", 360)
	fog.set_process(false)
	fog.frozen = true
	# 停止已排队的刷新后再采样，遮罩与对象显隐维持当前状态。
	for frame: int in range(5): await process_frame
	await _sample("fog_frozen", 360)
	MeasuredAvoidance.bypass = true
	await _sample("fog_and_avoidance_frozen", 360)
	for unit: Variant in residents:
		if is_instance_valid(unit):
			unit.set_physics_process(false)
			unit.set_process(false)
	for enemy: Variant in enemies:
		if is_instance_valid(enemy):
			enemy.set_physics_process(false)
			enemy.set_process(false)
	await _sample("fog_and_unit_ai_frozen", 360)
	var filename: String = "res://.godot/unit_profile_stress_%d_%dx.json" % [population, int(speed)]
	if shelter_capacity > 0: filename = filename.trim_suffix(".json") + "_shelter_%d.json" % shelter_capacity
	var file := FileAccess.open(filename, FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	print("STRESS_REPORT ", filename)
	quit()
