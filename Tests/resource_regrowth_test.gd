extends SceneTree

class TestRuntime extends MapGenerateRuntime:
	func _ready() -> void:
		add_to_group("map_generate_runtime")
		set_process(false)

var failed: bool = false

func _init() -> void:
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
	var runtime := TestRuntime.new()
	world.add_child(runtime)
	if DisplayServer.get_name() != "headless":
		var camera := Camera3D.new()
		world.add_child(camera)
		camera.position = Vector3(10, 10, 14)
		camera.look_at(Vector3(0, 1, 0))
		camera.current = true
		var light := DirectionalLight3D.new()
		world.add_child(light)
		light.rotation_degrees = Vector3(-45, -30, 0)
		var floor_mesh := MeshInstance3D.new()
		floor_mesh.mesh = PlaneMesh.new()
		floor_mesh.mesh.size = Vector2(40, 40)
		floor_mesh.position.y = 1.0
		world.add_child(floor_mesh)
	runtime._resource_rng.seed = 418
	runtime._visual_rng.seed = 418
	runtime._regrowth_rng.seed = 418
	runtime.map_data = WFCMapData.new()
	runtime.map_data.map_size = Vector2i(40, 40)
	for y: int in range(40):
		for x: int in range(40):
			var cell := Vector2i(x, y)
			runtime.map_data.occupied_cells.append(cell)
			runtime._resource_terrain_weights[cell] = Vector2.ONE
	runtime.height_field = runtime.map_data.create_height_field()
	var resources := Node3D.new()
	resources.name = "GeneratedResources"
	runtime.add_child(resources)
	var entry := MapResourceEntry.new()
	entry.scene = load("res://Scene/resource/tree.tscn")
	entry.regrowth_wait_min = 2.0
	entry.regrowth_wait_max = 2.0
	entry.growth_time_min = 4.0
	entry.growth_time_max = 4.0
	entry.mature_scale_min = 0.9
	entry.mature_scale_max = 0.9
	entry.minimum_spacing = 0.1
	entry.cluster_radius = 5.0
	entry.spacing_version = 1
	_expect(entry.validation_error().is_empty(), "再生配置可以通过校验")
	ResourceSaver.save(entry, "res://.godot/resource_regrowth_entry.tres")
	var reloaded: MapResourceEntry = ResourceLoader.load("res://.godot/resource_regrowth_entry.tres", "", ResourceLoader.CACHE_MODE_IGNORE)
	_expect(reloaded.growth_time_min == 4.0 and reloaded.regrowth_wait_min == 2.0 and reloaded.regrowth_mode == 1, "关卡资源条目生长与再生配置可保存重载")
	runtime._active_resource = entry
	runtime._regrowth_centers = [Vector3(0, 1, 0)]
	runtime._prepare_resource_spec(entry)
	for point: Vector3 in [Vector3(-2, 1, 0), Vector3(2, 1, 0), Vector3(0, 1, 2)]:
		_expect(runtime._place_resource_at(resources, entry.scene, point, null), "生成初始成熟资源")
	runtime._active_resource = null
	var original: ResourceBase = resources.get_child(0)
	var original_position: Vector3 = original.global_position
	var original_rotation: float = original.get_node("meshs").rotation.y
	_expect(original.can_gather() and original.get_node("meshs").scale.is_equal_approx(Vector3.ONE * 0.9), "初始资源成熟且使用配置的最终缩放")
	for resource: ResourceBase in resources.get_children():
		resource.gather(resource.resource_amount)
	await process_frame
	runtime.set_process(false)
	_expect(resources.get_child_count() == 0 and runtime._pending_regrowth.size() == 3, "三个耗尽资源对应三个空缺，没有增加簇数量")
	runtime._process(1.0)
	runtime.set_process(false)
	_expect(resources.get_child_count() == 0, "等待时间未结束不开始生长")
	runtime._process(1.1)
	runtime._process(0.0)
	runtime.set_process(false)
	_expect(resources.get_child_count() == 3 and runtime._pending_regrowth.is_empty(), "等待结束补齐原簇空缺并移除等待记录")
	var growing: ResourceBase = resources.get_child(0)
	for resource: ResourceBase in resources.get_children():
		resource.set_process(false)
		_expect(runtime._horizontal_distance(resource.global_position, Vector3(0, 1, 0)) <= entry.cluster_radius, "再生位置保持在原簇范围")
	_expect(growing.global_position.distance_to(original_position) > 0.1 and growing.get_node("meshs").rotation.y != original_rotation, "再生重新随机位置与朝向")
	var stock: int = growing.resource_amount
	_expect(not growing.can_gather() and not growing.reserve(world) and growing.gather(1) == 0 and growing.resource_amount == stock, "生长期间不能预约或采集，不扣资源量")
	growing._process(2.0)
	_expect(is_equal_approx(growing.growth_progress, 0.5) and growing.get_node("meshs").scale.is_equal_approx(Vector3.ONE * 0.45), "成熟缩放0.9时，50%生长对应0.45")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/resource_growth_half.png")
	var lumber: ResourceBuildingBase = load("res://Scene/building/game/lumber_camp.tscn").instantiate()
	lumber.set_building_data(load("res://data/buildings/LumberCampData.tres"))
	world.add_child(lumber)
	lumber.position = Vector3(-8, 1, 0)
	lumber.work_radius = 30.0
	lumber.set_process(false)
	_expect(not lumber.has_gatherable_resources(), "生长中的资源不能消除建筑缺资源提醒")
	var region := NavigationRegion3D.new()
	region.name = "NavigationRegion3D"
	world.add_child(region)
	runtime._build_navigation()
	var worker: Node3D = load("res://Scene/unit/villager.tscn").instantiate()
	world.add_child(worker)
	worker.position = Vector3(-6, 1, 0)
	worker.set_physics_process(false)
	for i in range(6): await physics_frame
	worker.workplace = lumber
	worker.job = worker.Job.LUMBERJACK
	worker.find_nearest_resource()
	_expect(worker.target_resource == null, "真实伐木工不选择未成熟资源")
	for resource: ResourceBase in resources.get_children():
		resource._process(4.0)
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/resource_growth_mature.png")
	worker.find_nearest_resource()
	_expect(is_instance_valid(worker.target_resource) and lumber.has_gatherable_resources(), "资源成熟后伐木工恢复选点，建筑提醒恢复正常")
	_expect(growing.reserve(world) or growing.is_reserved(), "成熟资源恢复预约")
	_expect(growing.gather(1) == 1 and growing.resource_amount == stock - 1, "成熟后实际采集恢复")
	var blocked_slot: Dictionary = {"entry": entry, "center": Vector3(10, 1, 0), "original": Vector3(10, 1, 0), "wait": 0.0}
	var house: BuildingBase = load("res://Scene/building/game/house.tscn").instantiate()
	var house_data: BuildingData = load("res://data/buildings/HouseData.tres").duplicate(true)
	house_data.grid_size = Vector2i(16, 16)
	house.set_building_data(house_data)
	world.add_child(house)
	house.position = Vector3(10, 1, 0)
	var before: int = resources.get_child_count()
	runtime._pending_regrowth.append(blocked_slot)
	runtime._process(0.1)
	runtime.set_process(false)
	_expect(resources.get_child_count() == before and runtime._pending_regrowth.has(blocked_slot) and blocked_slot.wait == 5.0, "建筑占满簇范围时不强行再生，延后重试")
	house.queue_free()
	await process_frame
	runtime._process(5.1)
	runtime.set_process(false)
	_expect(resources.get_child_count() == before + 1 and not runtime._pending_regrowth.has(blocked_slot), "建筑移除后原簇可以重新生长")
	var fresh: ResourceBase = resources.get_child(resources.get_child_count() - 1)
	fresh.set_process(false)
	entry.regrowth_mode = 0
	var original_slot: Dictionary = {"entry": entry, "center": Vector3(-12, 1, 0), "original": Vector3(-12, 1, 0)}
	_expect(runtime._try_regrow_resource(original_slot), "原地再生模式可生成")
	var same_place: ResourceBase = resources.get_child(resources.get_child_count() - 1)
	same_place.set_process(false)
	_expect(same_place.position == original_slot.original and not same_place.can_gather(), "原地模式保留位置但仍从零生长")
	var site := ConstructionSite.new()
	site.building_data = house_data
	world.add_child(site)
	site.position = Vector3(10, 1, 0)
	_expect(runtime._overlaps_regrowth_building(runtime._geometry(entry.scene, site.position, 0.0)), "施工蓝图占地也阻止资源再生")
	site.queue_free()
	entry.regrowth_enabled = false
	same_place.clear_for_construction()
	await process_frame
	_expect(runtime._pending_regrowth.is_empty(), "关闭再生后清除资源不产生新的空缺任务")
	fresh.growth_duration = 100.0
	fresh.set_process(true)
	var pause_slot: Dictionary = {"entry": entry, "center": Vector3.ZERO, "original": Vector3.ZERO, "wait": 100.0}
	runtime._pending_regrowth.append(pause_slot)
	runtime.set_process(true)
	paused = true
	var elapsed: float = fresh._growth_elapsed
	await create_timer(0.1, true, false, true).timeout
	_expect(fresh._growth_elapsed == elapsed and pause_slot.wait == 100.0, "暂停时生长与再生等待停止")
	paused = false
	Engine.time_scale = 3.0
	await create_timer(0.1, true, false, true).timeout
	_expect(fresh._growth_elapsed - elapsed > 0.18 and 100.0 - pause_slot.wait > 0.18, "三倍速加快游戏时间下的生长与再生等待")
	Engine.time_scale = 1.0
	fresh.set_process(false)
	runtime._pending_regrowth.clear()
	runtime.set_process(false)
	world.queue_free()
	await process_frame
	quit(1 if failed else 0)
