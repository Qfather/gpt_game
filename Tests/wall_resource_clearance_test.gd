extends SceneTree

var failed: bool = false


func _initialize() -> void:
	call_deferred("_run")


func _expect(value: bool, message: String) -> void:
	if not value:
		failed = true
		push_error("失败：" + message)


func _resource(path: String, at: Vector3) -> ResourceBase:
	var resource: ResourceBase = load(path).instantiate() as ResourceBase
	root.add_child(resource)
	resource.position = at
	return resource


func _run() -> void:
	var scene: Node = load("res://Scene/main.tscn").instantiate()
	scene.level_preset = scene.level_preset.duplicate(true)
	scene.level_preset.map_resources.clear()
	root.add_child(scene)
	current_scene = scene
	await process_frame
	await process_frame
	scene.get_node("Villagers").free()
	var runtime: Node = scene.get_node("Systems/MapGenerateRuntime")
	for child: Node in runtime.get_node("GeneratedTerrain").get_children():
		_expect(not child is CanvasLayer, "地图重新生成控件仍存在")
	var ghost: BuildingGhost = scene.get_node("Systems/BuildingGhost") as BuildingGhost
	var grid: BuildGrid = ghost.build_grid
	grid.buildability_rule = Callable()
	grid.ground_height_rule = Callable()
	grid.occupied_cells.clear()
	var data: BuildingData = load("res://data/buildings/WallData.tres")
	var original_time: float = data.construction_time
	var center := Vector3(1.5, 0, 0.5)
	var tree: ResourceBase = _resource("res://Scene/resource/tree.tscn", center)
	var stone: ResourceBase = _resource("res://Scene/resource/stone.tscn", center + Vector3(1, 0, 0))
	var beside: ResourceBase = _resource("res://Scene/resource/tree.tscn", center + Vector3(0, 0, 1.35))
	var margin_tree: ResourceBase = _resource("res://Scene/resource/tree.tscn", center + Vector3(0, 0, 1.1))
	tree.reserved_by = ghost
	var transform := Transform3D(Basis.IDENTITY, center)
	_expect(not grid.is_area_free(Vector2i.ZERO, data.grid_size), "普通建筑未被资源阻挡")
	_expect(grid.is_area_free(Vector2i.ZERO, data.grid_size, 0, true), "城墙不能覆盖资源")
	_expect(ghost._get_wall_clearance_resources(data, transform).size() == 3, "外扩清障范围错误")
	_expect(not tree.is_queued_for_deletion(), "预览阶段提前清除资源")
	_expect(ghost._create_construction_site(data, Vector2i.ZERO, 0, false, transform, false, true), "城墙放置失败")
	var site: ConstructionSite
	for child: Node in ghost.get_parent().get_children():
		if child is ConstructionSite:
			site = child as ConstructionSite
	_expect(site != null and is_equal_approx(site.building_data.construction_time, original_time * 1.5), "多资源墙段未只增加50%时间")
	_expect(is_equal_approx(data.construction_time, original_time), "共享建筑配置被污染")
	_expect(tree.resource_amount == 0 and tree.reserved_by == null and tree.is_queued_for_deletion(), "资源量或预约未清理")
	_expect(stone.is_queued_for_deletion() and not beside.is_queued_for_deletion(), "误删旁边资源或未删石头")
	_expect(margin_tree.is_queued_for_deletion(), "未清除施工空间内资源")
	for index: int in range(3):
		var offset: Vector3 = site._create_random_edge_offset(index, 3)
		_expect(absf(offset.x) <= 1.7 and absf(offset.z) <= 0.45, "站位没有为居民身体保留清障余量")
	var extra: ResourceBase = _resource("res://Scene/resource/tree.tscn", center)
	_expect(not ghost._create_construction_site(data, Vector2i.ZERO, 0, false, transform, false, true), "重复占地未拒绝")
	_expect(not extra.is_queued_for_deletion(), "放置失败仍删除资源")
	extra.free()
	_expect(site.cancel_construction(), "无法取消工地")
	_expect(site.is_queued_for_deletion() and site.cancellation_workers.is_empty(), "空材料工地未直接取消")
	_expect(not grid.occupied_cells.has(Vector2i.ZERO), "直接取消未释放占地")
	await process_frame
	_expect(not is_instance_valid(site), "空材料工地仍需等待居民")
	_expect(not is_instance_valid(tree) and not is_instance_valid(stone), "取消后恢复了已清除资源")
	var empty_transform := Transform3D(Basis.IDENTITY, Vector3(7.5, 0, 0.5))
	_expect(ghost._create_construction_site(data, Vector2i(6, 0), 0, false, empty_transform, false, true), "空地城墙失败")
	for child: Node in ghost.get_parent().get_children():
		if child is ConstructionSite:
			_expect(is_equal_approx(child.building_data.construction_time, original_time), "空地城墙错误增加施工时间")
			child.delivered_resources[&"wood"] = 5.0
			_expect(child.cancel_construction(), "已有材料工地无法取消")
			_expect(not child.is_queued_for_deletion() and child.state == ConstructionSite.State.CANCELLING, "已有材料工地被直接删除")
	var rotated_center := Vector3(0, 0, 8)
	var rotated: ResourceBase = _resource("res://Scene/resource/stone.tscn", rotated_center + Vector3(0, 0, 1))
	var outside: ResourceBase = _resource("res://Scene/resource/stone.tscn", rotated_center + Vector3(2, 0, 0))
	var basis := Basis(Vector3.UP, PI * 0.5).scaled(Vector3(-1, 1, 1))
	var hits: Array[ResourceBase] = ghost._get_wall_clearance_resources(data, Transform3D(basis, rotated_center))
	_expect(hits.has(rotated) and not hits.has(outside), "旋转镜像后的清障范围错误")
	beside.free()
	rotated.free()
	outside.free()
	scene.queue_free()
	await process_frame
	print("城墙清障测试", "失败" if failed else "通过", "：成功清障、失败不清、旁边保留、预约释放、时间倍率、旋转镜像、取消不恢复、移除地图控件")
	quit(1 if failed else 0)
