@tool
extends EditorInspectorPlugin

const RESOURCE_EDITOR: Script = preload(
	"res://addons/raid_group_editor/raid_target_property.gd"
)

const STEAL_PROPERTIES: Array[String] = [
	"raid_steal_resource_id",
	"raid_steal_amount_per_tick",
	"raid_steal_interval",
	"raid_steal_quota",
]


func _can_handle(object: Object) -> bool:
	return object is EnemyData


func _parse_property(
	_object: Object,
	type: Variant.Type,
	property: String,
	_hint_type: PropertyHint,
	_hint_string: String,
	_usage_flags: int,
	_wide: bool
) -> bool:
	var data: EnemyData = _object as EnemyData
	var objective: int = int(data.raid_objective)
	if property == "raid_objective":
		var property_editor: EditorProperty = RESOURCE_EDITOR.new()
		property_editor.configure_objective()
		add_property_editor(property, property_editor)
		return true
	if property in STEAL_PROPERTIES:
		if objective != EnemyData.RaidObjective.STEAL_RESOURCES:
			return true
		if property == "raid_steal_resource_id":
			_add_dropdown(property, "优先偷取资源", "resource")
			return true
		return false
	if property == "raid_destroy_building_id":
		if objective != EnemyData.RaidObjective.DESTROY_BUILDINGS:
			return true
		_add_dropdown(property, "优先破坏建筑", "building")
		return true
	if property == "raid_kill_unit_id":
		if objective != EnemyData.RaidObjective.KILL_UNITS:
			return true
		_add_dropdown(property, "优先杀戮单位", "unit")
		return true
	return false


func _add_dropdown(property: String, label: String, choice_kind: String) -> void:
	var property_editor: EditorProperty = RESOURCE_EDITOR.new()
	property_editor.configure_choice(property, label, choice_kind)
	add_property_editor(property, property_editor)
