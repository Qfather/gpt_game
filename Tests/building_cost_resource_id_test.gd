extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if not Engine.is_editor_hint():
		_verify_runtime()
		await process_frame
		quit()
		return
	await create_timer(5).timeout
	var panel: Control = load("res://addons/resource_editor/building_editor_panel.gd").new()
	root.add_child(panel)
	var quarry: BuildingData = load("res://data/buildings/QuarryData.tres")
	assert(quarry.construction_cost == {&"wood": 20.0})
	var scene_path: String = "res://.godot/cost_resource_id_quarry.tscn"
	var data_path: String = "res://.godot/cost_resource_id_quarry.tres"
	assert(ResourceSaver.save(quarry.building_scene.duplicate(), scene_path) == OK)
	var copy: BuildingData = quarry.duplicate(true)
	copy.building_scene = load(scene_path)
	assert(ResourceSaver.save(copy, data_path) == OK)
	panel.buildings.append(load(data_path))
	panel.select_building(panel.buildings.size() - 1)
	panel.current.construction_cost.clear()
	panel.current.construction_cost[&"木材"] = 20.0
	assert(not panel.save_current())
	assert(panel.status.text.contains("未知资源ID「木材」"))
	var unchanged: BuildingData = ResourceLoader.load(data_path, "", ResourceLoader.CACHE_MODE_IGNORE)
	assert(unchanged.construction_cost == {&"wood": 20.0})
	panel.current.construction_cost.clear()
	panel.current.construction_cost[&"wood"] = 20.0
	panel.current.training_cost[&"不存在"] = 1.0
	assert(not panel.save_current())
	panel.current.training_cost.clear()
	assert(panel.save_current())
	var saved: BuildingData = ResourceLoader.load(data_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP)
	assert(saved.construction_cost == {&"wood": 20.0})
	panel.queue_free()
	await process_frame
	print("建筑材料编辑测试通过：中文名称拒绝保存、wood 20保存读回")
	quit()


func _verify_runtime() -> void:
	var saved: BuildingData = load("res://data/buildings/QuarryData.tres")
	var site: ConstructionSite = load("res://Scene/building/construction_site.tscn").instantiate()
	site.setup(saved, Vector2i.ZERO, 0, false)
	site.set_activation_deferred_until_unpause(true)
	root.add_child(site)
	assert(site.required_resources == {&"wood": 20.0})
	assert(site.debug_deliver_resource(&"stone", 20.0) == 0.0)
	assert(site.debug_deliver_resource(&"wood", 19.0) == 19.0)
	assert(site.state == ConstructionSite.State.WAITING_RESOURCES)
	assert(site.debug_deliver_resource(&"wood", 1.0) == 1.0)
	assert(site.state == ConstructionSite.State.READY_TO_BUILD)
	site.queue_free()
	print("建筑材料运行测试通过：工地只接受20木材，19木材不足，20木材可施工")
