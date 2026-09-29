@tool
extends EditorPlugin

const INSPECTOR_SCRIPT := preload("res://addons/water_material_inspector/water_inspector.gd")

var _inspector: EditorInspectorPlugin


func _enter_tree() -> void:
	_inspector = INSPECTOR_SCRIPT.new()
	add_inspector_plugin(_inspector)


func _exit_tree() -> void:
	if _inspector != null:
		remove_inspector_plugin(_inspector)
