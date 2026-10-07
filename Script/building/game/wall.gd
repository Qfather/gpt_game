class_name Wall
extends BuildingBase

const CONNECTIONS: Script = preload("res://Script/building/wall_connections.gd")
var connection_mask: int = -1
var connection_model: Node3D
var tower_site: ConstructionSite


@onready var durability: BuildingDurability = $BuildingDurability


func _ready() -> void:
	super._ready()
	tree_exited.connect(func() -> void: CONNECTIONS.refresh(Engine.get_main_loop() as SceneTree))
	durability.health_changed.connect(_on_health_changed)
	durability.destroyed.connect(_on_destroyed)


func get_max_health() -> float:
	return durability.max_health


func get_health() -> float:
	return durability.current_health


func take_damage(amount: float, source: Node = null) -> float:
	return durability.take_damage(amount, source)


func _on_health_changed(current: float, maximum: float) -> void:
	health_changed.emit(current, maximum)


func _on_destroyed() -> void:
	release_build_grid_area()
	queue_free()


func set_build_grid_occupancy(cell: Vector2i, size: Vector2i, turns: int) -> void:
	super.set_build_grid_occupancy(cell, size, turns)
	if is_inside_tree(): CONNECTIONS.refresh(get_tree())

func set_building_data(data: BuildingData) -> void:
	super.set_building_data(data)
	connection_mask = -1
	if is_inside_tree(): CONNECTIONS.refresh(get_tree())

func release_build_grid_area() -> bool:
	# 塔楼工地与底墙共用一格；底墙摧毁后该格仍由工地保留。
	if is_instance_valid(tower_site) and not tower_site.is_queued_for_deletion():
		build_grid_area_registered = false
		return true
	return super.release_build_grid_area()

func update_connection(mask: int, cell_size: float) -> void:
	if mask == connection_mask: return
	var shape: Vector2i = CONNECTIONS.shape_for_mask(mask)
	var scene: PackedScene = building_data.wall_scenes()[shape.x]
	if scene == null: return
	connection_mask = mask
	if is_instance_valid(connection_model): connection_model.free()
	$VisualDetail.hide()
	connection_model = scene.instantiate() as Node3D
	connection_model.rotation.y = -shape.y * PI * 0.5
	connection_model.scale = Vector3(cell_size, 1, cell_size)
	add_child(connection_model)
	rotation.y = 0
	var click_shape := BoxShape3D.new()
	click_shape.size = Vector3(cell_size, 1.8, cell_size)
	$ClickArea/CollisionShape3D.shape = click_shape
	var body: StaticBody3D = $StaticBody3D
	for child: Node in body.get_children(): child.free()
	_add_collision(body, Vector3.ZERO, Vector3(0.42, 1.5, 0.42), cell_size)
	for index: int in range(4):
		if not (mask & (1 << index)): continue
		var direction: Vector2i = CONNECTIONS.DIRECTIONS[index]
		_add_collision(body, Vector3(direction.x * 0.25, 0, direction.y * 0.25), Vector3(0.5 if direction.x != 0 else 0.36, 1.5, 0.5 if direction.y != 0 else 0.36), cell_size)
	_request_navigation_update()

func _add_collision(body: StaticBody3D, offset: Vector3, size: Vector3, cell_size: float) -> void:
	var shape := BoxShape3D.new()
	shape.size = Vector3(size.x * cell_size, size.y, size.z * cell_size)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position = Vector3(offset.x * cell_size, 0.75, offset.z * cell_size)
	body.add_child(collision)
