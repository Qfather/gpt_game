extends SceneTree

var failed: bool = false

func _initialize() -> void:
	call_deferred("_run")

func _expect(value: bool, message: String) -> void:
	print("[", "通过" if value else "失败", "] ", message)
	if not value:
		failed = true
		push_error(message)

func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world
	var region := NavigationRegion3D.new()
	var mesh := NavigationMesh.new()
	# 门口单点最近的导航区域在屋内且不连通；正面右侧仍有可走通道。
	mesh.vertices = PackedVector3Array([Vector3(-0.1, 0, 0.5), Vector3(-0.1, 0, 0.7), Vector3(0.1, 0, 0.7), Vector3(0.1, 0, 0.5), Vector3(0.9, 0, 0.95), Vector3(0.9, 0, 1.0), Vector3(3, 0, 1.0), Vector3(3, 0, 0.95)])
	mesh.add_polygon(PackedInt32Array([0, 1, 2, 3]))
	mesh.add_polygon(PackedInt32Array([4, 5, 6, 7]))
	region.navigation_mesh = mesh
	world.add_child(region)
	var house: House = load("res://Scene/building/game/house.tscn").instantiate()
	world.add_child(house)
	var resident = load("res://Scene/unit/villager.tscn").instantiate()
	world.add_child(resident)
	resident.set_physics_process(false)
	var enemy: EnemyBase = load("res://Scene/unit/enemy_base.tscn").instantiate()
	world.add_child(enemy)
	enemy.set_process(false)
	enemy.set_physics_process(false)
	enemy.position = Vector3(3, 0, 1)
	for frame: int in range(10): await physics_frame
	resident.position = Vector3(2, 0, 0.98)
	var map: RID = region.get_navigation_map()
	var original_point: Vector3 = NavigationServer3D.map_get_closest_point(map, house.get_entrance_position())
	_expect(not house.is_at_entrance_front(original_point), "复现门口单点投影到不可进入的位置")
	resident.home_building = house
	resident.take_damage(5.0, enemy)
	for frame: int in range(240):
		resident._process_civilian_retreat(1.0 / 60.0)
		await physics_frame
		if resident.state == resident.State.SHELTERED and not resident.passing_door: break
	_expect(resident.shelter_target == house, "普通居民受击后选择自己住宅的可达正面")
	_expect(resident.state == resident.State.SHELTERED and not resident.visible and resident.indoor_building == house, "居民实际沿正面侧边走进建筑避难")
	_expect(resident.take_damage(5, enemy) == 0, "躲进建筑后仍受到建筑保护")
	world.free()
	quit(1 if failed else 0)
