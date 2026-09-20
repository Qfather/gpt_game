class_name ResourceNodePanel
extends BuildingPanelBase

const RESOURCE_DATABASE: ResourceDatabase = preload(
	"res://data/resources/resource_database.tres"
)

@onready var resource_type_label: Label = %ResourceTypeLabel
@onready var remaining_label: Label = %RemainingLabel
@onready var reserved_label: Label = %ReservedLabel


func _ready() -> void:
	super._ready()


func refresh() -> void:
	var current_resource: ResourceBase = current_building as ResourceBase
	if not is_instance_valid(current_resource):
		close_panel_immediately()
		return

	var resource_id: StringName = &""
	if current_resource.has_method("get_resource_id"):
		resource_id = current_resource.get_resource_id()
	var resource_name: String = str(resource_id)
	var resource_data: ResourceData = RESOURCE_DATABASE.get_resource_data(resource_id)
	if resource_data != null and not resource_data.display_name.is_empty():
		resource_name = resource_data.display_name
	resource_type_label.text = "资源类型：" + resource_name
	remaining_label.text = "剩余数量：%d" % current_resource.resource_amount
	reserved_label.text = (
		"预约状态：已预约"
		if current_resource.is_reserved()
		else "预约状态：未预约"
	)
func _process(_delta: float) -> void:
	if visible:
		refresh()
