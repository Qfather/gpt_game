extends SceneTree

var failed := false
var worker: Node3D
var hut: Node3D
var grid: BuildGrid

func _init() -> void: call_deferred("_run")

func _check(value: bool, message: String) -> void:
	print("[通过] " if value else "[失败] ", message)
	failed = failed or not value

func _wait(condition: Callable, frames: int = 2400) -> bool:
	for index: int in range(frames):
		if condition.call(): return true
		await physics_frame
		await process_frame
	print("等待超时：", worker.global_position, " phase=", worker.fishing.phase, " cargo=", worker.fishing.cargo)
	return condition.call()

func _capture() -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/fishing-hut.png")
	var camera: Camera3D = root.get_camera_3d()
	var old := camera.global_transform
	var point: Vector3 = worker.fishing.boat.global_position
	camera.position = point + Vector3(2,3,3)
	camera.look_at(point + Vector3.UP * 0.3)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/fishing-boat.png")
	camera.global_transform = old

func _run() -> void:
	Engine.time_scale = 6.0
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world
	grid = BuildGrid.new()
	grid.grid_min = Vector2i(-20,-20)
	grid.grid_max = Vector2i(20,20)
	grid.water_rule = func(cell: Vector2i) -> bool: return cell.y < 0
	grid.buildability_rule = func(cell: Vector2i) -> bool: return cell.y >= 0
	grid.ground_height_rule = func(cell: Vector2i) -> float: return 3.0 if cell.y >= 0 else 0.0
	world.add_child(grid)
	var data: BuildingData = load("res://data/buildings/FisherHutData.tres")
	_check(data.requires_blueprint and data.tier == 1, "T1渔夫小屋需要本局蓝图")
	_check(grid.is_building_area_free(data, Vector2i(-1,-2),0), "2×2全水面、正面贴岸可放置")
	_check(not grid.is_building_area_free(data, Vector2i(-1,-2),2), "门朝海拒绝放置")
	_check(not grid.is_building_area_free(data, Vector2i(-1,-4),0), "离岸拒绝放置")
	_check(not grid.is_building_area_free(data, Vector2i(-1,-1),0), "占地包含陆地拒绝放置")
	var region := NavigationRegion3D.new()
	var navigation := NavigationMesh.new()
	navigation.vertices = PackedVector3Array([Vector3(-20,3,0),Vector3(-20,3,20),Vector3(20,3,20),Vector3(20,3,0)])
	navigation.add_polygon(PackedInt32Array([0,1,2,3]))
	region.navigation_mesh = navigation
	world.add_child(region)
	var ground := StaticBody3D.new()
	# 游戏地图沿导航高度移动，没有地面物理碰撞体。
	ground.collision_layer = 0
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(40,0.4,20)
	collision.shape = shape
	ground.add_child(collision)
	world.add_child(ground)
	ground.position = Vector3(0,2.8,10)
	var land := MeshInstance3D.new()
	var land_mesh := BoxMesh.new()
	land_mesh.size = shape.size
	land.mesh = land_mesh
	ground.add_child(land)
	var sea := MeshInstance3D.new()
	var sea_mesh := PlaneMesh.new()
	sea_mesh.size = Vector2(40,20)
	sea.mesh = sea_mesh
	var blue := StandardMaterial3D.new()
	blue.albedo_color = Color(0.12,0.4,0.55)
	sea.material_override = blue
	world.add_child(sea)
	sea.position = Vector3(0,1.8,-10)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.position = Vector3(5,7,5)
	camera.look_at(Vector3(0,2,-2))
	camera.make_current()
	var light := DirectionalLight3D.new()
	world.add_child(light)
	light.rotation_degrees = Vector3(-55,-25,0)
	var base: Node3D = load("res://Scene/building/base.tscn").instantiate()
	world.add_child(base)
	base.position = Vector3(10,3,10)
	hut = data.building_scene.instantiate()
	hut.set_building_data(data)
	world.add_child(hut)
	hut.position = Vector3(0,3,-1)
	hut.work_radius = 6.0
	hut.boat_capacity = 2
	hut.catch_min = 1
	hut.catch_max = 1
	_check(grid.occupy_building_area(data,Vector2i(-1,-2),0), "小屋占用四个水面网格")
	hut.set_build_grid_occupancy(Vector2i(-1,-2),Vector2i(2,2),0)
	worker = load("res://Scene/unit/villager.tscn").instantiate()
	world.add_child(worker)
	worker.position = Vector3(0,3,6)
	for index: int in range(10): await physics_frame
	_check(await _wait(func() -> bool: return is_instance_valid(hut.boat) and not hut.launching), "建成后无人小船从屋内驶出停靠")
	var permanent_boat: Node3D = hut.boat
	_check(permanent_boat.global_position.is_equal_approx(hut.get_dock_position()), "无人船停在小屋码头")
	_check(hut.add_worker(worker), "居民任职渔民")
	var second: Node3D = load("res://Scene/unit/villager.tscn").instantiate()
	world.add_child(second)
	second.position = Vector3(10,3,9)
	_check(not hut.add_worker(second) and hut.workers.size() == 1, "小屋只允许一名渔民")
	second.queue_free()
	worker.hunger_rate = 0.0
	worker.fatigue_rate = 0.0
	worker.fishing.rng.seed = 42
	_check(await _wait(func() -> bool: return worker.fishing.phase == 3), "居民实际走到岸边入口、进屋登船、航行到打捞点")
	await _capture()
	_check(worker.fishing.boat != null and not worker.visible and worker.collision_layer == 0, "船上显示乘客，陆地角色隐藏且取消碰撞")
	_check(worker.fishing.boat == permanent_boat and permanent_boat.passenger.scale == Vector3.ONE, "复用建成时小船，乘客保持正常模型大小")
	_check(is_equal_approx(permanent_boat.get_node("Visual/Hull").mesh.size.x, 0.84), "船体宽度扩大为0.84米")
	var point: Vector3 = worker.fishing.boat.global_position
	_check(await _wait(func() -> bool: return worker.fishing.cargo == 1), "停留10游戏秒获取第一份渔获")
	_check(hut.get_storage_amount() == 0 and worker.fishing.phase == 2, "未满仓继续换点，不返屋、不提前入库存")
	_check(await _wait(func() -> bool: return worker.fishing.phase == 3), "航行到下一个打捞点")
	_check(worker.fishing.boat.global_position.distance_to(point) >= 2.0, "下一次打捞点与上一点不同")
	var before: float = worker.fishing.timer
	paused = true
	for index: int in range(20): await process_frame
	_check(worker.fishing.timer == before, "暂停保持打捞计时不变")
	paused = false
	_check(await _wait(func() -> bool: return worker.fishing.phase == 6), "满仓后沿水路实际返屋处理")
	_check(hut.boat == permanent_boat and not hut.boat.occupied and not is_instance_valid(hut.boat.passenger), "返航后空船保留在码头")
	_check(hut.get_storage_amount() == 0 and worker.fishing.cargo == 2, "处理完成前渔获不进入鱼库存")
	_check(await _wait(func() -> bool: return hut.get_storage_amount() == 2), "处理完成准确存入2条鱼")
	_check(await _wait(func() -> bool: return worker.fishing.cargo == 1 and worker.fishing.phase == 2), "开始下一轮并取得部分渔获")
	worker.fatigue = 95.0
	worker.rest_recovery_rate = 0.0
	_check(await _wait(func() -> bool: return worker.state == worker.State.MOVE_TO_REST or worker.state == worker.State.RESTING), "疲劳时未满仓提前实际返岸，再前往休息")
	_check(worker.fishing.cargo == 1 and hut.get_storage_amount() == 2 and not is_instance_valid(worker.fishing.boat), "提前返航保留未处理渔获")
	worker.fatigue = 0.0
	_check(await _wait(func() -> bool: return hut.get_storage_amount() == 3), "休息后实际回屋处理保留渔获")
	_check(await _wait(func() -> bool: return worker.fishing.cargo == 1 and worker.fishing.phase == 2), "再次出海取得部分渔获")
	hut.remove_worker(worker)
	_check(await _wait(func() -> bool: return worker.job == worker.Job.NONE), "途中离职实际提前返岸后结束职业")
	_check(worker.fishing.cargo == 0 and hut.get_storage_amount() == 4, "离职返屋处理已有渔获，无丢失或重复")
	_check(worker.visible and worker.collision_layer == 2 and worker.global_position.z >= 0, "返岸退出恢复实体角色与碰撞")
	# 独立船在水中岛块前实际转弯，验证水路与逐步朝向更新。
	var boat: Node3D = load("res://Scene/unit/fishing_boat.tscn").instantiate()
	world.add_child(boat)
	boat.position = Vector3(-3.5,1.8,-8.5)
	grid.occupied_cells[Vector2i(-1,-9)] = true
	grid.occupancy_revision += 1
	_check(boat.navigate(grid, Vector3(0,3,-6), 12.0, Vector3(3.5,1.8,-8.5)), "水路查找绕过被占用格")
	var turns_smooth := true
	var water_only := true
	var reached := false
	for index: int in range(600):
		var yaw: float = boat.get_node("Visual").rotation.y
		reached = boat.sail(grid,2.0,0.05)
		turns_smooth = turns_smooth and absf(wrapf(boat.get_node("Visual").rotation.y-yaw,-PI,PI)) <= PI/0.4*0.05+0.0001
		water_only = water_only and boat.water_clear(grid,grid.world_to_grid(boat.position))
		if reached: break
	_check(reached and water_only, "小船实际绕障到达，全程不进入陆地或占用格")
	_check(turns_smooth, "船头随航行方向平滑转向，角速度不超过角色转向速度")
	boat.queue_free()
	_check(hut.add_worker(worker), "离职后可重新任职")
	worker.fatigue = 0.0
	worker.hunger = 0.0
	worker.hunger_rate = 0.0
	worker.fatigue_rate = 0.0
	_check(await _wait(func() -> bool: return worker.fishing.cargo == 1 and worker.fishing.phase == 2), "拆屋场景取得部分渔获")
	var returning_boat: Node3D = worker.fishing.boat
	var blocker := StaticBody3D.new()
	var blocker_collision := CollisionShape3D.new()
	var blocker_shape := BoxShape3D.new()
	blocker_shape.size = Vector3(1.2,2,1)
	blocker_collision.shape = blocker_shape
	blocker.add_child(blocker_collision)
	world.add_child(blocker)
	blocker.position = Vector3(0,3.5,0.5)
	hut.queue_free()
	for index: int in range(300): await physics_frame
	_check(worker.job == worker.Job.FISHER and is_instance_valid(returning_boat) and worker.fishing.cargo == 1, "拆屋后入口被堵时保留船与渔获，不穿过障碍返岸")
	blocker.queue_free()
	_check(await _wait(func() -> bool: return worker.job == worker.Job.NONE), "障碍移除后沿原靠岸通道实际返岸并结束岗位")
	_check(worker.fishing.cargo == 1 and worker.visible and worker.collision_layer == 2 and worker.global_position.z >= 0 and not is_instance_valid(returning_boat), "拆屋返岸保留未处理渔获、释放船并恢复碰撞")
	print("捕鱼测试完成：", "失败" if failed else "通过")
	quit(1 if failed else 0)
