extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world
	var buildings: Array[ResourceBuildingBase] = []
	var ids: Array[String] = ["lumber_camp", "quarry", "hunter_hut", "farm"]
	for index in range(ids.size()):
		var building: ResourceBuildingBase = load("res://Scene/building/game/%s.tscn" % ids[index]).instantiate()
		world.add_child(building)
		building.position = [Vector3(-3,0,0),Vector3(3,0,0),Vector3(0,0,-5),Vector3(0,0,5)][index]
		building.set_process(false)
		building._process(1.1)
		assert(building.resource_warning.visible == (ids[index] != "farm"))
		buildings.append(building)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.position = Vector3(10,12,16)
	camera.look_at(Vector3(0,1,0))
	camera.current = true
	var light := DirectionalLight3D.new()
	world.add_child(light)
	light.rotation_degrees = Vector3(-45,-30,0)
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/resource_warning_preview.png")
	var camp: ResourceBuildingBase = buildings[0]
	var tree: ResourceBase = load("res://Scene/resource/tree.tscn").instantiate()
	world.add_child(tree)
	tree.position = camp.position + Vector3(2,0,0)
	tree.resource_amount = 5
	tree.reserved_by = world
	camp.storage.add(&"wood", 10000)
	camp._process(1.1)
	assert(not camp.resource_warning.visible) # 有资源即正常，不因被预约或仓库满而报耗尽。
	buildings[1]._process(1.1)
	assert(buildings[1].resource_warning.visible) # 树木不能满足采石场。
	tree.resource_amount = 0
	camp._process(1.1)
	assert(camp.resource_warning.visible)
	tree.resource_amount = 5
	tree.position = camp.position + Vector3(camp.work_radius + 2,0,0)
	camp._process(1.1)
	assert(camp.resource_warning.visible)
	tree.position = camp.position + Vector3(2,0,0)
	camp._process(1.1)
	assert(not camp.resource_warning.visible)
	tree.queue_free()
	camp.set_meta("fog_hidden", true)
	camp._process(1.1)
	assert(not camp.resource_warning.visible and bool(camp.resource_warning.get_meta("fog_visible")))
	camp.set_meta("fog_hidden", false)
	camp._process(1.1)
	assert(camp.resource_warning.visible)
	var prey_data: Resource = load("res://data/wildlife/rabbit.tres")
	var animal: Node3D = prey_data.scene.instantiate()
	animal.data = prey_data
	world.add_child(animal)
	animal.position = buildings[2].position + Vector3(3,0,0)
	buildings[2]._process(1.1)
	assert(not buildings[2].resource_warning.visible)
	animal.health = 0
	buildings[2]._process(1.1)
	assert(buildings[2].resource_warning.visible)
	world.queue_free()
	await process_frame
	print("资源建筑提醒测试通过：耗尽／恢复、范围与资源类型、预约和满仓不误报、猎物生死、农田生长不误报、迷雾隐藏")
	quit()
