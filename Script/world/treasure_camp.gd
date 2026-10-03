class_name TreasureCamp
extends LootBundle

const ENEMY_SCENE: PackedScene = preload("res://Scene/unit/enemy_base.tscn")
const GUARD_SCRIPT: Script = preload("res://Script/world/camp_guard.gd")

signal camp_clicked(camp: TreasureCamp)
signal changed

var display_name: String = "宝箱营地"
var generated_at: float = 0.0
var footprint_radius: float = 3.0
var guard_leash_radius: float = 10.0
var guard_health_regen: float = 1.0
var guard_plan: Array[EnemyData] = []
var guard_positions: Array[Vector3] = []
var guards: Array[EnemyBase] = []
var participants: Array[Node] = []
var cleared: bool = false


func configure_camp(data: TreasureCampData, plan: Dictionary, positions: Array[Vector3], elapsed: float) -> void:
	display_name = data.display_name
	generated_at = elapsed
	footprint_radius = data.footprint_radius
	guard_leash_radius = data.guard_leash_radius
	guard_health_regen = data.guard_health_regen
	guard_plan.assign(plan["guards"])
	guard_positions = positions.duplicate()
	configure_resources(plan["rewards"])


func _ready() -> void:
	add_to_group("treasure_camps")
	$ClickArea.input_event.connect(_on_input_event)
	for index: int in range(guard_plan.size()):
		var guard: EnemyBase = ENEMY_SCENE.instantiate() as EnemyBase
		guard.set_script(GUARD_SCRIPT)
		guard.enemy_data = guard_plan[index].duplicate(true) as EnemyData
		guard.faction_override = EnemyData.Faction.RAID
		guard.set("camp", self)
		guard.set("home_position", guard_positions[index])
		guard.position = guard_positions[index] - global_position + Vector3.UP * 0.6
		add_child(guard)
		guards.append(guard)
	var main: Node = get_tree().current_scene
	if main != null and main.has_method("register_treasure_camp"):
		main.register_treasure_camp(self)


func _process(_delta: float) -> void:
	for unit: Node in participants.duplicate():
		if not is_instance_valid(unit) or unit.is_dead():
			remove_participant(unit)
	if not cleared and get_living_guards().is_empty():
		cleared = true
		for unit: Node in participants.duplicate():
			remove_participant(unit)
		add_to_group("loot_bundles")
		_create_pickup_task()
		_request_resource_refresh()
		changed.emit()


func get_living_guards() -> Array[EnemyBase]:
	var living: Array[EnemyBase] = []
	for guard: EnemyBase in guards:
		if is_instance_valid(guard) and not guard.is_dead():
			living.append(guard)
	return living


func add_participant(unit: Node) -> bool:
	if cleared or not is_instance_valid(unit) or participants.has(unit):
		return false
	if not unit.has_method("begin_treasure_hunt") or not unit.begin_treasure_hunt(self):
		return false
	participants.append(unit)
	changed.emit()
	return true


func remove_participant(unit: Node) -> void:
	participants.erase(unit)
	if is_instance_valid(unit) and unit.has_method("finish_treasure_hunt"):
		unit.finish_treasure_hunt(self)
	changed.emit()


func _create_pickup_task() -> void:
	if cleared:
		super._create_pickup_task()


func pick_up(worker: Node) -> bool:
	if not cleared:
		return false
	var result: bool = super.pick_up(worker)
	changed.emit()
	return result


func get_status_text() -> String:
	if cleared:
		return "搬运中" if pickup_task != null and pickup_task.state != GameTask.State.AVAILABLE else "待搬运"
	return "清剿中" if not participants.is_empty() else "待清剿"


func _on_input_event(_camera: Node, event: InputEvent, _position: Vector3, _normal: Vector3, _shape: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		camp_clicked.emit(self)
		get_viewport().set_input_as_handled()


func _exit_tree() -> void:
	for unit: Node in participants.duplicate():
		remove_participant(unit)
	var manager: Node = get_tree().get_first_node_in_group("task_manager")
	if manager != null:
		manager.cancel_tasks_for_target(self)
