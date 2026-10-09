class_name Migrant
extends CharacterBody3D

signal arrived(migrant: Node3D, base: Node3D)

@export var move_speed: float = 2.5

@onready var navigation_agent: NavigationAgent3D = $NavigationAgent3D

var target_base: Node3D
var resident_traits: Array[UnitTrait] = []
var character_name: String = ""
var _arrival_notified: bool = false
var _entering_base: bool = false
var _navigation_target_ready: bool = false
# var unit_avoidance = preload("res://Script/unit/unit_avoidance.gd").new()


func _ready() -> void:
	var names = preload("res://Script/unit/character_names.gd")
	var data = preload("res://data/units/ResidentData.tres")
	character_name = names.assign(self, names.HUMAN_POOL, data.fixed_name)


func setup(base: Node3D) -> void:
	target_base = base
	_navigation_target_ready = false
	call_deferred("_set_navigation_target")


func _set_navigation_target() -> void:
	if not is_instance_valid(target_base):
		return

	await get_tree().physics_frame
	while NavigationServer3D.map_get_iteration_id(
		navigation_agent.get_navigation_map()
	) == 0:
		await get_tree().physics_frame

	if not is_instance_valid(target_base):
		return

	var target_position: Vector3 = target_base.global_position
	if target_base.has_method("get_migrant_entrance_position"):
		target_position = target_base.get_migrant_entrance_position()
		navigation_agent.target_desired_distance = 0.2
		navigation_agent.path_desired_distance = 0.2
	elif target_base.has_method("get_interaction_position"):
		target_position = target_base.get_interaction_position(self)

	navigation_agent.target_position = NavigationServer3D.map_get_closest_point(
		navigation_agent.get_navigation_map(),
		target_position
	)
	_navigation_target_ready = true


func _physics_process(delta: float) -> void:
	if _arrival_notified or _entering_base or not is_instance_valid(target_base) or not _navigation_target_ready:
		velocity = Vector3.ZERO
		return

	if NavigationServer3D.map_get_iteration_id(
		navigation_agent.get_navigation_map()
	) == 0:
		velocity = Vector3.ZERO
		return

	if _has_arrived():
		velocity = Vector3.ZERO
		if target_base.has_method("get_migrant_interior_position"):
			_enter_base()
		else:
			_notify_arrival()
		return

	var next_position: Vector3 = navigation_agent.get_next_path_position()
	if navigation_agent.is_navigation_finished():
		velocity = Vector3.ZERO
		return
	var offset: Vector3 = next_position - global_position
	# 倍速或拐角处不越过路径点，避免下一帧反向追赶同一点。
	velocity = offset.limit_length(move_speed * delta) / delta
	# 暂停自定义单位扫描、减速、绕行及让路；保留调用供后续恢复。
	# velocity = unit_avoidance.steer(self, navigation_agent, velocity, delta)
	move_and_slide()


func _has_arrived() -> bool:
	if _arrival_notified or not is_instance_valid(target_base):
		return false

	if target_base.has_method("get_migrant_entrance_position"):
		return target_base.is_at_entrance_front(global_position)

	# 与实际移动目标一致，旁边房屋可能使原始交互点投影到另一处可达位置。
	return (
		global_position.distance_to(navigation_agent.target_position) <= 1.6
	)


func _enter_base() -> void:
	_entering_base = true
	velocity = Vector3.ZERO
	# 只有正门到室内这一段使用出入动画，不改变正常寻路的碰撞规则。
	collision_layer = 0
	collision_mask = 0
	var interior: Vector3 = target_base.get_migrant_interior_position()
	var tween: Tween = create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.tween_property(self, "global_position", interior, global_position.distance_to(interior) / move_speed)
	tween.tween_callback(_notify_arrival)


func _notify_arrival() -> void:
	if _arrival_notified or not is_instance_valid(target_base):
		return

	_arrival_notified = true
	arrived.emit(self, target_base)
