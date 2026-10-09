extends SceneTree

class TestMap extends MapGenerateRuntime:
	func _ready() -> void:
		add_to_group("map_generate_runtime")

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
	var region := NavigationRegion3D.new()
	world.add_child(region)
	var runtime := TestMap.new()
	world.add_child(runtime)
	runtime._navigation_faces = PackedVector3Array([Vector3(-15,0,-15),Vector3(15,0,-15),Vector3(-15,0,15),Vector3(15,0,-15),Vector3(15,0,15),Vector3(-15,0,15)])
	var lumber: ResourceBuildingBase = load("res://Scene/building/game/lumber_camp.tscn").instantiate()
	lumber.set_building_data(load("res://data/buildings/LumberCampData.tres"))
	world.add_child(lumber)
	var house: BuildingBase = load("res://Scene/building/game/house.tscn").instantiate()
	house.get_node("ClickArea/CollisionShape3D").shape = BoxShape3D.new()
	house.get_node("ClickArea/CollisionShape3D").shape.size = Vector3(4,2,4)
	world.add_child(house)
	house.position = Vector3(3,0,0)
	var mesh: NavigationMesh = runtime._new_navigation_mesh()
	NavigationServer3D.bake_from_source_geometry_data(mesh, runtime._navigation_geometry())
	region.navigation_mesh = mesh
	for i in range(10): await physics_frame
	var worker: Node3D = load("res://Scene/unit/villager.tscn").instantiate()
	world.add_child(worker)
	worker.set_physics_process(false)
	worker.position = Vector3(-7,0,-3)
	for i in range(3): await physics_frame
	lumber.add_worker(worker)
	worker.carried_resource_id = &"wood"
	worker.carried_amount = 3.0
	var blocked: Vector3 = lumber.get_interaction_position(worker)
	worker.go_to_workplace()
	_expect(worker.navigation_agent.target_position.distance_to(blocked) > 0.5, "伐木场原入口被相邻住宅挡住时选择其他入口")
	for i in range(420):
		worker.move_to_workplace()
		if worker.state == worker.State.DEPOSIT_TO_WORKPLACE: break
		await physics_frame
	_expect(worker.state == worker.State.DEPOSIT_TO_WORKPLACE and worker.position.distance_to(Vector3(-7,0,-3)) > 1.0, "居民实际走到可用入口进入卸货状态")
	if worker.state == worker.State.DEPOSIT_TO_WORKPLACE: await worker.deposit_to_workplace()
	_expect(worker.carried_amount == 0 and lumber.get_resource_amount(&"wood") == 3, "木材实际入库，伐木工恢复找树")
	# 模拟已持有旧入口坐标的居民，停在导航末端但仍未到入口。
	worker.position = Vector3(-7,0,-3)
	worker.carried_amount = 2.0
	worker.navigation_agent.target_position = blocked
	worker.state = worker.State.MOVE_TO_WORKPLACE
	worker._set_unreachable_warning(true)
	for i in range(3): await physics_frame
	worker.move_to_workplace()
	_expect(worker.navigation_agent.target_position.distance_to(blocked) > 0.5, "已有感叹号和旧入口目标也会重新选择入口")
	# 将建筑搬到整个导航平面之外，不能把远处路径终点当作建筑入口。
	lumber.position = Vector3(40,0,0)
	lumber.interaction_positions.clear()
	worker.position = Vector3(-7,0,-3)
	worker.go_to_workplace()
	var inventory: float = lumber.get_resource_amount(&"wood")
	for i in range(420):
		worker.move_to_workplace()
		worker._update_unreachable_warning(1.0 / 60.0)
		await physics_frame
	_expect(worker.state == worker.State.MOVE_TO_WORKPLACE and worker.carried_amount == 2 and lumber.get_resource_amount(&"wood") == inventory, "整座伐木场不可达时保持货物，不隔空卸货")
	worker._update_unreachable_warning(5.1)
	worker._update_unreachable_warning(5.1)
	_expect(worker.unreachable_warning, "整座建筑不可达且停止前进时仍显示感叹号")
	world.queue_free()
	await process_frame
	quit(1 if failed else 0)
