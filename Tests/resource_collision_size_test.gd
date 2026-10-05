extends SceneTree

class TestRuntime extends MapGenerateRuntime:
	func _ready() -> void: pass


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world
	var runtime := TestRuntime.new()
	world.add_child(runtime)
	var resources := Node3D.new()
	resources.name = "GeneratedResources"
	runtime.add_child(resources)
	var probe := CharacterBody3D.new()
	probe.collision_mask = 1
	probe.collision_layer = 2
	var probe_shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.08
	probe_shape.shape = sphere
	probe.add_child(probe_shape)
	world.add_child(probe)
	for id: String in ["tree", "stone"]:
		var resource: ResourceBase = load("res://Scene/resource/%s.tscn" % id).instantiate()
		resource.position.z = 0.0 if id == "tree" else 4.0
		resources.add_child(resource)
		var solid: CollisionShape3D = resource.get_node("StaticBody3D/CollisionShape3D")
		var click: CollisionShape3D = resource.get_node("ClickArea/CollisionShape3D")
		assert(solid.scale.is_equal_approx(Vector3(0.5, 1, 0.5)))
		assert(click.scale.is_equal_approx(Vector3.ONE))
		assert(resource.get_build_obstacle_bounds().size.x == 1.0)
		var center: Vector3 = solid.global_position
		await physics_frame
		probe.global_position = center + Vector3(-2, 0, 0.4)
		assert(probe.move_and_collide(Vector3(4, 0, 0)) == null, "旧碰撞外缘应该允许通行")
		probe.global_position = center + Vector3(-2, 0, 0)
		assert(probe.move_and_collide(Vector3(4, 0, 0)) != null, "资源中心仍必须阻挡")
		var ray := PhysicsRayQueryParameters3D.create(center + Vector3(-2, 0, 0.4), center + Vector3(2, 0, 0.4), 4)
		ray.collide_with_areas = true
		var result: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(ray)
		assert(not result.is_empty() and result.collider == click.get_parent(), "原点击外缘仍可拾取")
		print(id, "：实体缩小、边缘通行、中心阻挡、点击与摆放范围保留通过")
	runtime._navigation_faces = PackedVector3Array([Vector3(-8,0,-6), Vector3(8,0,-6), Vector3(-8,0,8), Vector3(8,0,-6), Vector3(8,0,8), Vector3(-8,0,8)])
	var region := NavigationRegion3D.new()
	world.add_child(region)
	var lengths: Array[float] = []
	for original_size: bool in [false, true]:
		if original_size:
			var solid: CollisionShape3D = resources.get_child(0).get_node("StaticBody3D/CollisionShape3D")
			solid.scale = Vector3.ONE
		var mesh: NavigationMesh = runtime._new_navigation_mesh()
		NavigationServer3D.bake_from_source_geometry_data(mesh, runtime._navigation_geometry())
		region.navigation_mesh = mesh
		for frame: int in range(6): await physics_frame
		var path: PackedVector3Array = NavigationServer3D.map_get_path(region.get_navigation_map(), Vector3(-3,0,0), Vector3(3,0,0), true)
		assert(not path.is_empty())
		var length: float = 0.0
		for index: int in range(1, path.size()): length += path[index - 1].distance_to(path[index])
		lengths.append(length)
	assert(lengths[0] < lengths[1] - 0.05, "导航必须读取缩小后的实体范围")
	print("资源导航同步缩小通过：新路径=", lengths[0], " 旧路径=", lengths[1])
	world.queue_free()
	await process_frame
	quit()
