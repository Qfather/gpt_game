extends "res://Script/building/game/arrow_tower.gd"

const CONNECTIONS: Script = preload("res://Script/building/wall_connections.gd")

func _ready() -> void:
	super._ready()
	_resize_collision(1.0)
	tree_exited.connect(func() -> void: CONNECTIONS.refresh(Engine.get_main_loop() as SceneTree))

func set_build_grid_occupancy(cell: Vector2i, size: Vector2i, turns: int) -> void:
	super.set_build_grid_occupancy(cell, size, turns)
	if is_inside_tree():
		var grid: BuildGrid = get_tree().get_first_node_in_group("build_grid") as BuildGrid
		if grid != null: _resize_collision(grid.cell_size)
		CONNECTIONS.refresh(get_tree())

func _resize_collision(cell_size: float) -> void:
	# 塔楼占满底墙这一格，避免相邻墙与塔楼之间出现通行缝隙。
	var collision: CollisionShape3D = $StaticBody3D/CollisionShape3D
	var shape := BoxShape3D.new()
	shape.size = Vector3(cell_size, 3.5, cell_size)
	collision.shape = shape
	collision.scale = Vector3.ONE
	_request_navigation_update()

func get_garrison_capacity() -> int:
	return mini(super.get_garrison_capacity(), 1)

func get_garrison_position(_unit: Node) -> Vector3:
	return global_position + Vector3(0, 3.0, 0)
