extends SceneTree

class TestMap extends MapGenerateRuntime:
	func _ready() -> void: add_to_group("map_generate_runtime")

class MeasuredResident extends "res://Script/unit/game/villager.gd":
	var repath_count: int = 0
	func _repath_current_navigation_target() -> void:
		repath_count += 1
		super._repath_current_navigation_target()

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	Engine.print_to_stdout = false
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world
	var region := NavigationRegion3D.new()
	region.name = "NavigationRegion3D"
	world.add_child(region)
	var runtime := TestMap.new()
	world.add_child(runtime)
	runtime._navigation_faces = PackedVector3Array([Vector3(-10,0,-10),Vector3(10,0,-10),Vector3(-10,0,10),Vector3(10,0,-10),Vector3(10,0,10),Vector3(-10,0,10)])
	var camp: ResourceBuildingBase = load("res://Scene/building/game/lumber_camp.tscn").instantiate()
	world.add_child(camp)
	camp.set_process(false)
	var tower: Barracks = load("res://Scene/building/game/arrow_tower.tscn").instantiate()
	world.add_child(tower)
	tower.global_position = camp.get_entrance_position() + Vector3(0.5, 0, 0)
	tower.set_process(false)
	var mesh: NavigationMesh = runtime._new_navigation_mesh()
	NavigationServer3D.bake_from_source_geometry_data(mesh, runtime._navigation_geometry())
	region.navigation_mesh = mesh
	for frame: int in range(10): await physics_frame
	var worker: Node = load("res://Scene/unit/villager.tscn").instantiate()
	worker.set_script(MeasuredResident)
	world.add_child(worker)
	worker.set_physics_process(false)
	worker.set_process(false)
	for frame: int in range(5): await physics_frame
	worker.global_position = Vector3(0, 0, 4)
	worker.workplace = camp
	worker.state = worker.State.MOVE_TO_WORKPLACE
	worker.navigation_agent.target_position = worker._get_reachable_workplace_position()
	for frame: int in range(360):
		worker.move_to_workplace()
		await physics_frame
		if worker.state == worker.State.DEPOSIT_TO_WORKPLACE: break
	if worker.state != worker.State.DEPOSIT_TO_WORKPLACE:
		push_error("工作建筑边缘未抵达：位置%s 目标%s 路径%s 已结束%s 卡住%s 重查%d" % [worker.position, worker.navigation_agent.target_position, worker.navigation_agent.get_current_navigation_path(), worker.navigation_agent.is_navigation_finished(), worker.navigation_stuck_time, worker.repath_count])
		quit(1)
		return
	# 路径已经结束、目标仍在远处时，也必须继续执行停滞检测。
	worker.position = Vector3(8, 0, 8)
	worker.state = worker.State.MOVE_TO_RESOURCE
	worker.navigation_agent.target_position = Vector3(30, 0, 8)
	worker.navigation_last_position = worker.position
	worker.navigation_stuck_time = 0.0
	for frame: int in range(10): await physics_frame
	worker.navigation_agent.get_next_path_position()
	# 固定站在本路径末端，模拟无法抵达真实目标。
	var path: PackedVector3Array = worker.navigation_agent.get_current_navigation_path()
	assert(not path.is_empty())
	worker.position = path[-1] - Vector3.UP * worker.navigation_agent.path_height_offset
	worker.navigation_last_position = worker.position
	var stopped_position: Vector3 = worker.position
	for frame: int in range(150):
		worker.position = stopped_position + Vector3(0.03 if frame % 2 == 0 else -0.03, 0, 0)
		worker.move_along_navigation()
		await physics_frame
	assert(worker.repath_count > 0 and worker.repath_count <= 3, "路径结束不能跳过恢复检测，也不能每帧重查路径")
	Engine.print_to_stdout = true
	print("工作建筑边缘与路径结束恢复测试通过")
	world.queue_free()
	await process_frame
	quit()
