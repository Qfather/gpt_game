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
	for scene_path: String in ["res://Scene/building/base.tscn", "res://Scene/building/game/house.tscn", "res://Scene/building/game/farm.tscn", "res://Scene/building/game/swordsman_camp.tscn", "res://Scene/building/game/archer_camp.tscn", "res://Scene/building/game/barracks.tscn", "res://Scene/building/game/hunter_hut.tscn", "res://Scene/building/game/arrow_tower.tscn", "res://Scene/building/game/wall_tower.tscn", "res://Scene/building/game/wood_wall_tower.tscn", "res://Scene/building/game/lumber_camp.tscn", "res://Scene/building/game/quarry.tscn"]:
		var building: BuildingBase = load(scene_path).instantiate()
		world.add_child(building)
		var entrance: Vector3 = building.to_local(building.get_entrance_position())
		for turns: int in range(4):
			for mirrored: bool in [false, true]:
				building.rotation.y = turns * PI * 0.5
				building.scale.x = -1 if mirrored else 1
				building.position = Vector3(7, 2, -5)
				_expect(building.is_at_entrance_front(building.to_global(entrance + Vector3(-0.65, 0, 0))) and building.is_at_entrance_front(building.to_global(entrance + Vector3(0.65, 0, 0))), "%s 正面两侧可进入，旋转%d 镜像%s" % [building.name, turns, mirrored])
				_expect(not building.is_at_entrance_front(building.to_global(Vector3(entrance.x, 0, -3))), "背面不可进入")
				_expect(not building.is_at_entrance_front(building.to_global(entrance + Vector3(5, 0, 0))), "侧面不可进入")
				_expect(not building.is_at_entrance_front(building.get_entrance_position() + Vector3.UP * 2), "高度不同不可进入")
		if building is Farm:
			_expect(not building.is_at_entrance_front(building.to_global(Vector3(-1, 0, 2.5))), "农场田地不充当工具屋入口")
		building.free()
	var base: BuildingBase = load("res://Scene/building/base.tscn").instantiate()
	world.add_child(base)
	var region := NavigationRegion3D.new()
	var navigation := NavigationMesh.new()
	navigation.vertices = PackedVector3Array([Vector3(-20, 0, -20), Vector3(-20, 0, 20), Vector3(20, 0, 20), Vector3(20, 0, -20)])
	navigation.add_polygon(PackedInt32Array([0, 1, 2, 3]))
	region.navigation_mesh = navigation
	world.add_child(region)
	var migrant: Migrant = load("res://Scene/unit/migrant.tscn").instantiate()
	world.add_child(migrant)
	migrant.position = Vector3(0.9, 0, 2.4)
	var arrived: Array[bool] = [false]
	migrant.arrived.connect(func(_unit: Node3D, _base: Node3D) -> void: arrived[0] = true)
	migrant.setup(base)
	for frame: int in range(180):
		await physics_frame
		if arrived[0]: break
	_expect(arrived[0] and migrant.position.distance_to(base.get_migrant_interior_position()) < 0.01, "移民从正面边缘触发进门并抵达室内")
	var house: BuildingBase = load("res://Scene/building/game/house.tscn").instantiate()
	world.add_child(house)
	house.position = Vector3(5, 0, 0)
	var resident = load("res://Scene/unit/villager.tscn").instantiate()
	world.add_child(resident)
	resident.set_physics_process(false)
	for frame: int in range(5): await physics_frame
	resident.rest_home = house
	resident.global_position = house.get_entrance_position() + Vector3(0.7, 0, 0)
	resident.state = resident.State.NEED_REST
	await resident.move_to_rest()
	_expect(resident.indoor_building == house and resident.state == resident.State.RESTING, "居民从住宅正面边缘进屋休息")
	world.free()
	quit(1 if failed else 0)
