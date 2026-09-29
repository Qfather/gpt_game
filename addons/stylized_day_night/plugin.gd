@tool
extends EditorPlugin

const DAY_NIGHT_SCRIPT: Script = preload("res://addons/stylized_day_night/stylized_day_night.gd")


func _enter_tree() -> void:
	add_custom_type("StylizedDayNight", "Node3D", DAY_NIGHT_SCRIPT, null)


func _exit_tree() -> void:
	remove_custom_type("StylizedDayNight")
