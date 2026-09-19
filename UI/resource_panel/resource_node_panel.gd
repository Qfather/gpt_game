class_name ResourceNodePanel
extends BuildingPanelBase

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

	resource_type_label.text = (
		"资源类型："
		+ ResourceType.Type.keys()[current_resource.resource_type]
	)
	remaining_label.text = "剩余数量：%d" % current_resource.resource_amount
	reserved_label.text = (
		"预约状态：已预约"
		if current_resource.is_reserved()
		else "预约状态：未预约"
	)
func _process(_delta: float) -> void:
	if visible:
		refresh()
