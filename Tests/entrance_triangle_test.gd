extends SceneTree
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	for scene: String in ["house", "arrow_tower", "archer_camp", "lumber_camp", "farm"]:
		var building: BuildingBase = load("res://Scene/building/game/%s.tscn" % scene).instantiate()
		root.add_child(building)
		var bounds: AABB = BuildingBase.get_entrance_footprint(building)
		var entrance: Vector3 = building.to_local(building.get_entrance_position())
		var arrow: MeshInstance3D = BuildingBase.create_entrance_arrow(entrance, bounds)
		building.add_child(arrow)
		var vertices: PackedVector3Array = arrow.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		assert(vertices.size() == 3)
		assert(is_equal_approx(vertices[0].distance_to(vertices[1]), bounds.size.x))
		assert(is_equal_approx(vertices[2].distance_to((vertices[0] + vertices[1]) * 0.5), 0.3))
		assert(is_equal_approx(vertices[0].distance_to(vertices[2]), vertices[1].distance_to(vertices[2])))
		assert(is_equal_approx(vertices[0].z, bounds.end.z) and is_equal_approx(arrow.position.y, 0.03))
		for turns: int in range(4):
			building.rotation.y = turns * PI * 0.5
			building.scale.x = -1 if turns % 2 == 1 else 1
			assert(is_equal_approx(arrow.to_global(vertices[0]).distance_to(arrow.to_global(vertices[1])), bounds.size.x))
		building.free()
	print("建筑方向三角形测试通过：同宽底边、正面边缘、前方0.3米、等腰、贴地、旋转镜像")
	quit()
