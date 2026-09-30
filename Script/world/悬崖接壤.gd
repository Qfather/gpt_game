extends Node3D

func _ready() -> void:
	var selected := randi_range(0, get_child_count() - 1)
	for i in range(get_child_count()):
		get_child(i).visible = i == selected
