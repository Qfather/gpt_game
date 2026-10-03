extends SceneTree

var failed: bool = false

func _init() -> void:
	call_deferred("_run")

func _expect(value: bool, text: String) -> void:
	print("[", "通过" if value else "失败", "] ", text)
	if not value:
		failed = true
		push_error(text)

func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world
	var grid := BuildGrid.new()
	grid.grid_min = Vector2i(-100, -100)
	grid.grid_max = Vector2i(100, 100)
	world.add_child(grid)
	var base: Node3D = load("res://Scene/building/base.tscn").instantiate()
	world.add_child(base)
	for id: String in ["ArrowTower", "Wall", "Gate", "Torch", "Base", "LumberCamp", "Quarry", "Farm", "HunterHut", "SwordsmanCamp", "ArcherCamp", "Barracks", "House"]:
		var building := BuildingBase.new()
		building.building_data = load("res://data/buildings/" + id + "Data.tres")
		# 资源建筑使用实际类型，检查可移动范围。
		if id in ["LumberCamp", "Quarry", "Farm", "HunterHut"]:
			building.free()
			building = ResourceBuildingBase.new()
			building.building_data = load("res://data/buildings/" + id + "Data.tres")
		_expect(building.can_be_moved() == (id not in ["ArrowTower", "Wall", "Gate", "Torch", "Base"]), id + "搬迁权限")
		building.free()
	var house := BuildingBase.new()
	house.building_data = load("res://data/buildings/HouseData.tres").duplicate()
	house.building_data.construction_cost = {&"wood": 20.0, &"stone": 7.0}
	world.add_child(house)
	house.position = Vector3.ZERO
	_expect(house.get_relocation_cost(Vector3.ZERO) == {&"wood": 2.0, &"stone": 1.0}, "零距离按10%并向上取整")
	_expect(house.get_relocation_cost(Vector3(15, 10, 0)) == {&"wood": 6.0, &"stone": 3.0}, "15米按30%，不计高度差")
	_expect(house.get_relocation_cost(Vector3(30, 0, 0)) == {&"wood": 10.0, &"stone": 4.0}, "30米按50%")
	_expect(house.get_relocation_cost(Vector3(100, 0, 0)) == {&"wood": 10.0, &"stone": 4.0}, "超出30米仍封顶50%")
	base.add_resource(&"wood", 100)
	var old_wood: float = base.get_resource(&"wood")
	var destination := Transform3D(Basis.IDENTITY, Vector3(15, 0, 0))
	_expect(not house.relocate(grid, Vector2i(15, 0), 0, false, destination), "缺少石材不能搬迁")
	_expect(house.position == Vector3.ZERO and base.get_resource(&"wood") == old_wood, "资源不足不移动也不部分扣费")
	base.add_resource(&"stone", 100)
	var old_stone: float = base.get_resource(&"stone")
	_expect(house.relocate(grid, Vector2i(15, 0), 0, false, destination), "库存充足完成搬迁")
	_expect(base.get_resource(&"wood") == old_wood - 6 and base.get_resource(&"stone") == old_stone - 3, "实际扣除各类搬迁费用")
	var enemy_panel: EnemyPanel = load("res://Scene/ui/enemy_panel.tscn").instantiate()
	root.add_child(enemy_panel)
	await process_frame
	var enemy := EnemyBase.new()
	enemy_panel.current_building = enemy
	enemy_panel.show()
	enemy.free()
	enemy_panel.refresh()
	_expect(not enemy_panel.visible and enemy_panel.current_building == null, "敌人释放后刷新面板安全关闭，不转换已释放对象")
	enemy_panel.queue_free()
	world.queue_free()
	await process_frame
	quit(1 if failed else 0)
