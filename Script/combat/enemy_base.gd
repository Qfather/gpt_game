class_name EnemyBase
extends CharacterBody3D

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
var target: Node3D = null
var attack_cooldown: float = 0.0

signal target_changed(target: Node3D)

@onready var visual_root: Node3D = $VisualRoot
@onready var health_component: Node = $HealthComponent


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
	if is_dead() or not is_instance_valid(target):
		velocity = Vector3.ZERO
		return

	var target_position: Vector3 = target.global_position
	var flat_target_position: Vector3 = Vector3(
		target_position.x,
		global_position.y,
		target_position.z
	)
	var distance: float = global_position.distance_to(flat_target_position)
	if distance > attack_range:
		velocity = global_position.direction_to(flat_target_position) * move_speed
		move_and_slide()
		return

	velocity = Vector3.ZERO
	attack_cooldown = maxf(attack_cooldown - maxf(delta, 0.0), 0.0)
	if attack_cooldown > 0.0:
		return

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
	_apply_visual_scene()
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
	if enemy_data == null:
		return EnemyData.Faction.HOSTILE
	return int(enemy_data.faction)


func update_targeting() -> void:
	if is_dead():
		_set_target(null)
		return

	var nearest_target: Node3D = null
	var nearest_distance: float = detection_range
	for candidate: Node in get_tree().get_nodes_in_group("villagers"):
		if not candidate is Node3D:
			continue
		if not _is_legal_target(candidate):
			continue

		var candidate_node: Node3D = candidate as Node3D
		var distance: float = global_position.distance_to(
			candidate_node.global_position
		)
		if distance > detection_range or distance >= nearest_distance:
			continue

		nearest_distance = distance
		nearest_target = candidate_node

	_set_target(nearest_target)


func _is_legal_target(candidate: Node) -> bool:
	if candidate == null or not is_instance_valid(candidate):
		return false
	if not candidate.has_method("get_combat_role"):
		return false
	if not candidate.is_visible_in_tree():
		return false
	if candidate.has_method("has_combat_role") and not candidate.has_combat_role():
		return false
	if int(candidate.get_combat_role()) == CombatRole.Type.NONE:
		return false
	if candidate.has_method("is_dead") and candidate.is_dead():
		return false
	if candidate.has_method("get_faction"):
		return int(candidate.get_faction()) != get_faction()
	return true


func _set_target(next_target: Node3D) -> void:
	if target == next_target:
		return
	target = next_target
	if target != null:
		print(
			"⚔️ 战斗：%s 锁定目标：%s"
			% [get_display_name(), _get_target_name(target)]
		)
	else:
		print("⚔️ 战斗：%s 失去目标" % get_display_name())
	target_changed.emit(target)


func _get_target_name(unit: Node) -> String:
	if unit.has_method("get_combat_role"):
		if int(unit.get_combat_role()) == CombatRole.Type.SWORDSMAN:
			return "剑士"
	return str(unit.name)


func _on_health_changed(next_health: float, _next_max_health: float) -> void:
	current_health = next_health
	health_changed.emit(current_health, max_health)


func _on_health_died(_source: Node) -> void:
	print("⚔️ 战斗：%s 已死亡" % get_display_name())
	velocity = Vector3.ZERO
	set_process(false)
	set_physics_process(false)
	collision_layer = 0
	collision_mask = 0
	hide()


func _apply_visual_scene() -> void:
	if enemy_data.visual_scene == null or visual_root == null:
		return

	for child: Node in visual_root.get_children():
		child.queue_free()

	var visual_instance: Node = enemy_data.visual_scene.instantiate()
	if visual_instance != null:
		visual_root.add_child(visual_instance)


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
