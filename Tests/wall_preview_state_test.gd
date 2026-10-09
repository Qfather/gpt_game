extends SceneTree

var failed: bool = false

func _initialize() -> void:
	call_deferred("_run")

func _expect(value: bool, message: String) -> void:
	print("[", "通过" if value else "失败", "] ", message)
	if not value:
		failed = true
		push_error(message)

func _refresh(ghost: BuildingGhost) -> void:
	ghost.wall_preview_refresh_msec = 0
	ghost._update_wall_preview()

func _capture(name: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/wall_preview_" + name + ".png")

func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world
	if DisplayServer.get_name() != "headless":
		var camera := Camera3D.new()
		world.add_child(camera)
		camera.position = Vector3(4, 4, 5)
		camera.look_at(Vector3(0.5, 0.6, 0.5))
		camera.current = true
		var floor := MeshInstance3D.new()
		var plane := PlaneMesh.new()
		plane.size = Vector2(12, 12)
		floor.mesh = plane
		floor.position.y = -0.02
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = Color(0.12, 0.14, 0.16)
		floor.material_override = material
		world.add_child(floor)
	var systems := Node3D.new()
	systems.name = "Systems"
	world.add_child(systems)
	var grid := BuildGrid.new()
	grid.name = "BuildGrid"
	systems.add_child(grid)
	var roads = load("res://Script/world/road_manager.gd").new()
	roads.grid = grid
	world.add_child(roads)
	var storage := ResourceStorage.new()
	storage.starting_wood = 0
	storage.starting_stone = 0
	world.add_child(storage)
	var ghost := BuildingGhost.new()
	systems.add_child(ghost)
	ghost.set_process(false)
	for path: String in ["res://data/buildings/WallData.tres", "res://data/buildings/WoodWallData.tres"]:
		var data: BuildingData = load(path)
		ghost.select_building(data)
		ghost.grid_position = Vector2i.ZERO
		ghost.wall_dragging = true
		ghost.wall_drag_start = Vector2i.ZERO
		storage.take(&"wood", storage.get_amount(&"wood"))
		storage.take(&"stone", storage.get_amount(&"stone"))
		_refresh(ghost)
		_expect(ghost.is_valid_position and ghost.ghost_material.albedo_color.is_equal_approx(Color(1, 0.85, 0.1, 0.45)), "%s 合法位置但缺材料显示黄色" % data.id)
		_expect(ghost.relocation_cost_label.text.contains("材料不足"), "缺材料文字提示")
		if data.id == &"wall": await _capture("yellow")
		for resource_id: StringName in data.construction_cost:
			storage.add(resource_id, float(data.construction_cost[resource_id]))
		_refresh(ghost)
		_expect(ghost.ghost_material.albedo_color.is_equal_approx(Color(0.2, 1, 0.2, 0.45)), "%s 材料齐全显示绿色" % data.id)
		if data.id == &"wall": await _capture("green")
		ghost.grid_position = Vector2i.RIGHT
		_refresh(ghost)
		_expect(ghost.ghost_material.albedo_color.is_equal_approx(Color(1, 0.85, 0.1, 0.45)), "整条拖拽路线按新增墙段总成本检查材料")
		ghost.grid_position = grid.grid_max + Vector2i.ONE
		_refresh(ghost)
		_expect(not ghost.is_valid_position and ghost.ghost_material.albedo_color.is_equal_approx(Color(1, 0.15, 0.15, 0.45)), "%s 无法建造时优先显示红色" % data.id)
		if data.id == &"wall" and DisplayServer.get_name() != "headless":
			ghost.grid_position = Vector2i.ZERO
			grid.occupied_cells[Vector2i.ZERO] = true
			_refresh(ghost)
			await _capture("red")
			grid.occupied_cells.erase(Vector2i.ZERO)
		_expect(not ghost.entrance_arrow.visible, "城墙预览不显示方向箭头")
		var site: ConstructionSite = load("res://Scene/building/construction_site.tscn").instantiate()
		site.setup(data, Vector2i.ZERO, 0, false)
		site.set_activation_deferred_until_unpause(true)
		world.add_child(site)
		_expect(site.find_child("EntranceArrow", true, false) == null, "%s 已放置施工工地不生成方向箭头" % data.id)
		site.free()
	world.free()
	quit(1 if failed else 0)
