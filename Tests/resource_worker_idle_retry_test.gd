extends SceneTree
func _init() -> void:
	call_deferred("_run")
func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world
	var region := NavigationRegion3D.new()
	var mesh := NavigationMesh.new()
	mesh.vertices = PackedVector3Array([Vector3(-20,0,-20),Vector3(-20,0,20),Vector3(20,0,20),Vector3(20,0,-20)])
	mesh.add_polygon(PackedInt32Array([0,1,2,3]))
	region.navigation_mesh = mesh
	world.add_child(region)
	for id: String in ["lumber_camp", "quarry"]:
		var workplace: ResourceBuildingBase = load("res://Scene/building/game/%s.tscn" % id).instantiate()
		world.add_child(workplace)
		var worker: CharacterBody3D = load("res://Scene/unit/villager.tscn").instantiate()
		world.add_child(worker)
		worker.set_physics_process(false)
		worker.hunger_rate = 0.0
		worker.fatigue_rate = 0.0
		worker.position = Vector3(-3,0,0)
		for frame in range(10): await physics_frame
		assert(workplace.add_worker(worker))
		var resource: ResourceBase = load("res://Scene/resource/%s.tscn" % ("tree" if id == "lumber_camp" else "stone")).instantiate()
		resource.growth_duration = 2.0
		world.add_child(resource)
		resource.position = Vector3(4,0,0)
		resource.set_process(false)
		worker.find_nearest_resource()
		assert(worker.target_resource == null and worker.state == worker.State.RETURN_TO_IDLE)
		# 待命位置抵达后，长时间没有成熟资源也不能预约幼苗。
		worker.state = worker.State.IDLE
		worker.idle_reposition_timer = 0.0
		worker.process_idle_reposition(0.1)
		assert(worker.target_resource == null and not resource.is_reserved())
		worker.navigation_agent.target_position = worker.position
		resource._process(2.0)
		for frame in range(150):
			worker._physics_process(0.1)
			await physics_frame
			if worker.target_resource == resource: break
		if worker.target_resource != resource:
			push_error(id + " 待命后未自动恢复采集成熟资源")
			quit(1)
			return
		assert(resource.reserved_by == worker)
		# 其他工人释放预约后，待命工人同样应重新选点。
		resource.release(worker)
		resource.reserve(world)
		worker.target_resource = null
		worker.state = worker.State.FIND_RESOURCE
		worker.find_nearest_resource()
		assert(worker.target_resource == null)
		worker.navigation_agent.target_position = worker.position
		resource.release(world)
		for frame in range(150):
			worker._physics_process(0.1)
			await physics_frame
			if worker.target_resource == resource: break
		assert(worker.target_resource == resource and resource.reserved_by == worker)
		print("[通过] ", id, " 无资源待命、成熟后恢复、预约释放后恢复")
		worker.queue_free()
		workplace.queue_free()
		resource.queue_free()
		await process_frame
	world.queue_free()
	await process_frame
	quit()
