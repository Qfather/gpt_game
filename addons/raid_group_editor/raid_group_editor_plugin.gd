@tool
extends EditorPlugin

var panel: Control
var raid_resource_inspector: EditorInspectorPlugin

func _enter_tree() -> void:
	raid_resource_inspector = preload(
		"res://addons/raid_group_editor/raid_resource_inspector.gd"
	).new()
	add_inspector_plugin(raid_resource_inspector)
	panel = preload("res://addons/resource_editor/raid_editor_panel.gd").new()
	panel.name = "LevelEventEditor"
	add_control_to_bottom_panel(panel, "关卡")

func _exit_tree() -> void:
	if raid_resource_inspector != null:
		remove_inspector_plugin(raid_resource_inspector)
		raid_resource_inspector = null
	if panel != null and is_instance_valid(panel):
		remove_control_from_bottom_panel(panel)
		panel.queue_free()
