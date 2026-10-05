extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var original: BuildingData = load("res://data/buildings/HouseData.tres")
	var original_cost: Dictionary = original.construction_cost.duplicate()
	var data: BuildingData = original.duplicate(true)
	data.construction_cost = {&"wood": 13.5, &"stone": 2.25}
	var path: String = "res://.godot/building_material_configuration.tres"
	assert(ResourceSaver.save(data, path) == OK)
	var saved: BuildingData = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	var hud := GameHUD.new()
	var tooltip: String = hud._get_building_tooltip_body(saved)
	assert(tooltip.contains("木材 13.5") and tooltip.contains("石材 2.25"))
	var site: ConstructionSite = load("res://Scene/building/construction_site.tscn").instantiate()
	site.setup(original, Vector2i.ZERO, 0, false)
	site.set_activation_deferred_until_unpause(true)
	root.add_child(site)
	assert(site.get_required_amount(&"wood") == original_cost[&"wood"])
	assert(hud._get_building_tooltip_body(original).contains("木材 " + str(original_cost[&"wood"])))
	site.setup(saved, Vector2i.ZERO, 0, false)
	assert(site.get_required_amount(&"wood") == 13.5)
	assert(site.get_required_amount(&"stone") == 2.25)
	assert(site.receive_delivery(&"wood", 5.5) == 5.5)
	assert(site.get_construction_material_text().contains("木材：5.5 / 13.5"))
	assert(site.state == ConstructionSite.State.WAITING_RESOURCES)
	assert(site.receive_delivery(&"wood", 100.0) == 8.0)
	assert(site.state == ConstructionSite.State.WAITING_RESOURCES)
	assert(site.receive_delivery(&"stone", 100.0) == 2.25)
	assert(site.state == ConstructionSite.State.READY_TO_BUILD)
	# 修改配置后的下一份工地读取新需求，既有工地保留开工时的材料快照。
	saved.construction_cost = {&"stone": 7.0}
	var next_site: ConstructionSite = load("res://Scene/building/construction_site.tscn").instantiate()
	next_site.setup(saved, Vector2i(4, 0), 0, false)
	next_site.set_activation_deferred_until_unpause(true)
	root.add_child(next_site)
	assert(next_site.get_required_amount(&"wood") == 0.0)
	assert(next_site.get_required_amount(&"stone") == 7.0)
	assert(site.get_required_amount(&"wood") == 13.5)
	var free_data: BuildingData = saved.duplicate(true)
	free_data.construction_cost.clear()
	next_site.setup(free_data, Vector2i(4, 0), 0, false)
	assert(next_site.required_resources.is_empty())
	assert(next_site.state == ConstructionSite.State.READY_TO_BUILD)
	assert(original.construction_cost == original_cost)
	hud.free()
	site.queue_free()
	next_site.queue_free()
	await process_frame
	print("建筑材料配置测试通过：保存读回、HUD与工地小数显示、材料数量限制、改配后新工地及免费建筑")
	quit()
