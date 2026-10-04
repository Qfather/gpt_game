extends SceneTree

const EXPECTED: Dictionary = {
	"ArcherCampData": Vector2i(3,3), "ArrowTowerData": Vector2i(2,2),
	"BarracksData": Vector2i(2,3), "BaseData": Vector2i(2,3),
	"FarmData": Vector2i(4,4), "GateData": Vector2i(3,1),
	"HouseData": Vector2i(2,2), "HunterHutData": Vector2i(2,2),
	"LumberCampData": Vector2i(2,2), "QuarryData": Vector2i(2,2),
	"SwordsmanCampData": Vector2i(3,3), "TorchData": Vector2i(1,1),
	"WallData": Vector2i(3,1)
}

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var invalid: bool = false
	for file: String in EXPECTED:
		var data: BuildingData = load("res://data/buildings/%s.tres" % file)
		if data.grid_size != EXPECTED[file]:
			invalid = true
			push_error("%s 占位 %s 与实际主体网格 %s 不一致" % [data.display_name, data.grid_size, EXPECTED[file]])
	if invalid:
		quit(1)
		return
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world
	var systems := Node3D.new()
	systems.name = "Systems"
	world.add_child(systems)
	var grid := BuildGrid.new()
	grid.name = "BuildGrid"
	systems.add_child(grid)
	var ghost := BuildingGhost.new()
	systems.add_child(ghost)
	for file: String in EXPECTED:
		var data: BuildingData = load("res://data/buildings/%s.tres" % file)
		if data.construction_cost.is_empty():
			# 据点不在建造菜单中；给测试工地提供未交付材料，避免空成本直接派工。
			data = data.duplicate(true)
			data.construction_cost = {&"wood": 1.0}
		ghost.select_building(data)
		assert(ghost.building_data == data)
		for rotation_step: int in range(4):
			for mirrored: bool in [false, true]:
				var rotated: Vector2i = grid.get_rotated_size(data.grid_size, rotation_step)
				assert(grid.occupy_area(Vector2i.ZERO, data.grid_size, rotation_step))
				var site: ConstructionSite = load("res://Scene/building/construction_site.tscn").instantiate()
				site.setup(data, Vector2i.ZERO, rotation_step, mirrored)
				site.set_activation_deferred_until_unpause(true)
				world.add_child(site)
				var marker: BoxMesh = site.site_mesh.mesh
				var marker_bounds: AABB = site.site_mesh.global_transform * marker.get_aabb()
				var click: BoxShape3D = site.get_node("ClickArea").get_child(0).shape
				assert(marker.size == Vector3(data.grid_size.x,0.25,data.grid_size.y))
				assert(is_equal_approx(marker_bounds.size.x, rotated.x) and is_equal_approx(marker_bounds.size.z, rotated.y))
				assert(click.size.x == data.grid_size.x and click.size.z == data.grid_size.y)
				assert(grid.occupied_cells.size() == data.grid_size.x * data.grid_size.y)
				site._complete_construction()
				await process_frame
				var completed: BuildingBase
				for node: Node in get_nodes_in_group("buildings"):
					if node is BuildingBase and not node is ConstructionSite and node.building_data == data:
						completed = node
				assert(is_instance_valid(completed) and completed.build_grid_size == data.grid_size)
				assert(completed.build_grid_rotation_step == rotation_step)
				assert(grid.occupied_cells.size() == data.grid_size.x * data.grid_size.y)
				assert(completed.release_build_grid_area())
				completed.queue_free()
				await process_frame
				assert(grid.occupied_cells.is_empty())
		print("[通过] ", data.display_name, " ", data.grid_size, " 四种旋转与镜像施工／竣工占位一致")
	world.queue_free()
	await process_frame
	print("全部13类建筑占位验证通过")
	quit()
