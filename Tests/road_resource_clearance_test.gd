extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var grid := BuildGrid.new()
	grid.grid_min = Vector2i(-3, -3)
	grid.grid_max = Vector2i(4, 4)
	world.add_child(grid)
	var roads = load("res://Script/world/road_manager.gd").new()
	roads.grid = grid
	world.add_child(roads)
	for id in ["tree", "stone"]:
		var resource: ResourceBase = load("res://Scene/resource/%s.tscn" % id).instantiate()
		world.add_child(resource)
		resource.position = Vector3(1.5, 0, 1.4)
		resource.rotation.y = PI / 4.0
		var road_box := AABB(Vector3(1, 0, 0), Vector3(1, 2, 1))
		assert(resource.overlaps_clearance_box(road_box, Transform3D.IDENTITY), "复现：点击范围会挡住旁边道路")
		assert(not resource.overlaps_clearance_box(road_box, Transform3D.IDENTITY, true), "实体碰撞外缘不阻止铺路")
		assert(roads.can_place(Vector2i(1, 0)))
		assert(roads.plan_stroke(Vector2i(0, 0), Vector2i(2, 0)) == [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)], "道路可直穿资源实体外的空隙")
		resource.position.z = 0.8
		assert(not roads.can_place(Vector2i(1, 0)), "资源实体占地仍禁止铺路")
		assert(roads.plan_stroke(Vector2i(0, 0), Vector2i(1, 0)).is_empty(), "终点重叠资源仍拒绝整条道路")
		resource.queue_free()
		await process_frame
		assert(roads.can_place(Vector2i(1, 0)), "资源移除后道路缓存正确恢复")
		print(id, "：点击外缘可铺路、旋转实体仍阻挡、完整路线判定与缓存更新通过")
	world.queue_free()
	await process_frame
	quit()
