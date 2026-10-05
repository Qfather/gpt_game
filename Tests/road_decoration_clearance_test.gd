extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _decoration(world: Node3D, position: Vector3, flower: bool = false) -> Node3D:
	var scene: PackedScene = load("res://addons/MapGenerate/models/vegetation/示例小花.tscn" if flower else "res://addons/MapGenerate/models/vegetation/示例小草.tscn")
	var node: Node3D = scene.instantiate()
	world.add_child(node)
	node.global_position = position
	node.add_to_group("vegetation")
	return node


func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world
	var grid := BuildGrid.new()
	world.add_child(grid)
	var tasks := TaskManager.new()
	world.add_child(tasks)
	var roads = preload("res://Script/world/road_manager.gd").new()
	roads.grid = grid
	world.add_child(roads)
	var grass: Node3D = _decoration(world, grid.grid_to_world(Vector2i.ZERO))
	var flower: Node3D = _decoration(world, grid.grid_to_world(Vector2i.RIGHT), true)
	var neighbor: Node3D = _decoration(world, grid.grid_to_world(Vector2i.DOWN))
	var upper: Node3D = _decoration(world, grass.global_position + Vector3.UP * 3)
	roads.plan_stroke(Vector2i.ZERO, Vector2i.RIGHT)
	assert(not grass.is_queued_for_deletion() and not flower.is_queued_for_deletion(), "预览不能清除装饰")
	grid.occupied_cells[Vector2i.RIGHT] = true
	assert(roads.queue_cells([Vector2i.ZERO, Vector2i.RIGHT], 1) == 0)
	assert(not grass.is_queued_for_deletion(), "放置失败不能清除其他格的装饰")
	grid.occupied_cells.clear()
	assert(roads.queue_cells([Vector2i.ZERO], 2) == 0)
	assert(not grass.is_queued_for_deletion(), "材料不足不能清除装饰")
	paused = true
	assert(roads.queue_cells([Vector2i.ZERO, Vector2i.RIGHT], 1) == 2)
	assert(grass.is_queued_for_deletion() and flower.is_queued_for_deletion())
	assert(not grass.visible and not flower.visible, "暂停时确认道路也应立即隐藏装饰")
	assert(not neighbor.is_queued_for_deletion() and not upper.is_queued_for_deletion())
	paused = false
	var pebble := MeshInstance3D.new()
	pebble.mesh = SphereMesh.new()
	world.add_child(pebble)
	pebble.global_position = grid.grid_to_world(Vector2i(3, 0))
	pebble.add_to_group("vegetation")
	assert(roads.place_cells([Vector2i(3, 0)], 1) == 1 and pebble.is_queued_for_deletion())
	var resource: ResourceBase = load("res://Scene/resource/stone.tscn").instantiate()
	world.add_child(resource)
	resource.global_position = grid.grid_to_world(Vector2i(4, 0))
	resource.add_to_group("vegetation")
	roads._clear_road_decorations([Vector2i(4, 0)])
	assert(not resource.is_queued_for_deletion(), "可采集资源不能当作装饰清除")
	world.queue_free()
	await process_frame
	print("铺路装饰清理通过：花草与装饰石子、暂停确认、无效预览和缺料保护、邻格与不同高度保留、可采集石矿保留")
	quit()
