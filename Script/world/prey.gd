extends Node3D

signal prey_clicked(prey: Node3D)

var data: Resource
var health: float
var claimed_by: Node
var escape_direction: Vector3
var escape_time: float = 0.0
var corpse_time: float = 60.0

func _ready() -> void:
	add_to_group("wildlife")
	health = data.health
	var area := Area3D.new()
	area.name = "ClickArea"
	area.position.y = 0.3
	area.process_mode = Node.PROCESS_MODE_ALWAYS
	area.collision_layer = 2
	area.collision_mask = 0
	area.monitoring = false
	area.monitorable = false
	var collider := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.55
	collider.shape = shape
	area.add_child(collider)
	add_child(area)
	area.input_event.connect(_on_input_event)
	var main: Node = get_tree().current_scene
	if main != null and main.has_method("register_prey"):
		main.register_prey(self)


func claim(hunter: Node) -> bool:
	if is_instance_valid(claimed_by) and claimed_by != hunter: return false
	claimed_by = hunter
	return true

func release(hunter: Node) -> void:
	if claimed_by == hunter: claimed_by = null

func is_dead() -> bool:
	return health <= 0.0

func take_damage(amount: float, source: Node = null) -> float:
	if is_dead() or not is_instance_valid(source) or not source.has_method("is_hunter") or not source.is_hunter(): return 0.0
	if claimed_by != source: return 0.0
	var actual: float = minf(health, amount)
	health -= actual
	escape_direction = source.global_position.direction_to(global_position)
	escape_direction.y = 0.0
	escape_time = 2.0
	if is_dead(): rotation.z = PI * 0.5
	return actual

func _physics_process(delta: float) -> void:
	if is_dead():
		if not is_instance_valid(claimed_by):
			corpse_time -= delta
			if corpse_time <= 0.0: queue_free()
		return
	if escape_time <= 0.0: return
	escape_time -= delta
	var next: Vector3 = global_position + escape_direction.normalized() * data.flee_speed * delta
	var map: RID = get_world_3d().get_navigation_map()
	if NavigationServer3D.map_get_iteration_id(map) == 0: return
	var ground: Vector3 = NavigationServer3D.map_get_closest_point(map, next)
	if ground.distance_to(next) < 0.7: global_position = ground

func _on_input_event(_camera: Node, event: InputEvent, _position: Vector3, _normal: Vector3, _shape: int) -> void:
	if bool(get_meta("fog_hidden", false)) or is_queued_for_deletion():
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		prey_clicked.emit(self)
		get_viewport().set_input_as_handled()
