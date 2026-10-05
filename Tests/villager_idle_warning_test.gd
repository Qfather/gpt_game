extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world
	var region := NavigationRegion3D.new()
	var mesh := NavigationMesh.new()
	mesh.vertices = PackedVector3Array([Vector3(-30,0,-30), Vector3(-30,0,30), Vector3(30,0,30), Vector3(30,0,-30)])
	mesh.add_polygon(PackedInt32Array([0,1,2,3]))
	region.navigation_mesh = mesh
	world.add_child(region)
	var base: BuildingBase = load("res://Scene/building/base.tscn").instantiate()
	world.add_child(base)
	base.position = Vector3(-10,0,0)
	var camp: ResourceBuildingBase = load("res://Scene/building/game/lumber_camp.tscn").instantiate()
	world.add_child(camp)
	var tree: ResourceBase = load("res://Scene/resource/tree.tscn").instantiate()
	world.add_child(tree)
	tree.position = Vector3(4,0,0)
	var workers: Array[CharacterBody3D] = []
	for index: int in range(3):
		var worker: CharacterBody3D = load("res://Scene/unit/villager.tscn").instantiate()
		world.add_child(worker)
		worker.set_physics_process(false)
		worker.position = Vector3(-3,0,index * 2 - 2)
		workers.append(worker)
	for frame: int in range(10): await physics_frame
	for worker: CharacterBody3D in workers:
		assert(camp.add_worker(worker))
		worker.find_nearest_resource()
	assert(workers[0].target_resource == tree and tree.reserved_by == workers[0])
	assert(not workers[0].unreachable_marker.visible, "正常去采集的工人不应提醒空闲")
	for index: int in [1,2]:
		var worker: CharacterBody3D = workers[index]
		assert(worker.target_resource == null)
		worker.global_position = worker.navigation_agent.target_position
		worker.move_to_idle_area()
		worker._update_unreachable_warning(4.9)
		assert(not worker.has_idle_warning() and not worker.unreachable_marker.visible, "待命不足 5 秒不显示提醒")
		worker._update_unreachable_warning(0.1)
		assert(worker.state == worker.State.IDLE and worker.has_idle_warning())
		assert(worker.unreachable_marker.visible and not worker.has_unreachable_warning())
	var worker: CharacterBody3D = workers[1]
	worker.state = worker.State.MOVE_TO_RESOURCE
	assert(not worker.unreachable_marker.visible, "恢复工作时应立即清除空闲提醒")
	worker.job = worker.Job.NONE
	worker.workplace = null
	worker.target_base = base
	worker.position = base.position + Vector3(1,0,0)
	worker.state = worker.State.IDLE
	assert(not worker.unreachable_marker.visible, "据点正常待机不提醒")
	worker.position = Vector3(20,0,0)
	worker._update_unreachable_warning(5.0)
	assert(worker.unreachable_marker.visible, "其他位置待机也应提醒")
	worker.state = worker.State.WAIT_TASK_RESOURCE
	assert(not worker.unreachable_marker.visible, "进入新的等待状态重新计时")
	worker._update_unreachable_warning(5.0)
	assert(worker.unreachable_marker.visible, "等待任务材料应提醒空闲")
	worker.set_meta("fog_hidden", true)
	worker._update_unreachable_warning(0.1)
	assert(not worker.unreachable_marker.visible and bool(worker.unreachable_marker.get_meta("fog_visible")))
	worker.set_meta("fog_hidden", false)
	worker._update_unreachable_warning(0.1)
	assert(worker.unreachable_marker.visible)
	worker.state = worker.State.BUILDING
	assert(not worker.unreachable_marker.visible)
	if DisplayServer.get_name() != "headless":
		for index: int in [1,2]:
			workers[index].job = workers[index].Job.LUMBERJACK
			workers[index].workplace = camp
			workers[index].position = Vector3(index * 3 - 4,0,2.5)
			workers[index].state = workers[index].State.IDLE
			workers[index]._update_unreachable_warning(5.0)
		root.size = Vector2i(1000,700)
		var camera := Camera3D.new()
		world.add_child(camera)
		camera.position = Vector3(0,12,15)
		camera.look_at(Vector3(0,1,0))
		camera.make_current()
		var light := DirectionalLight3D.new()
		world.add_child(light)
		light.rotation_degrees = Vector3(-45,-30,0)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/villager_idle_warning.png")
	world.queue_free()
	await process_frame
	print("居民空闲提醒通过：最后一棵树由一人采集、另两人待机提醒、恢复工作清除、据点豁免、异地待机与缺料等待、迷雾隐藏恢复")
	quit()
