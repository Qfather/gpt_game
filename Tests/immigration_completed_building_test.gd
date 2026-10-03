extends SceneTree

var failed: bool = false

func _init() -> void:
	call_deferred("_run")

func _expect(value: bool, message: String) -> void:
	print("[", "通过" if value else "失败", "] ", message)
	failed = failed or not value

func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world
	var base: Node3D = load("res://Scene/building/base.tscn").instantiate()
	world.add_child(base)
	var manager := PopulationManager.new()
	manager.level_config = manager.level_config.duplicate(true)
	world.add_child(manager)
	manager.set_process(false)
	var group := ImmigrationGroup.new()
	group.food_amount = 0
	group.required_buildings.append(load("res://data/buildings/FarmData.tres"))
	manager.level_config.immigration_rules.groups.assign([group])
	manager.current_immigration_group = group
	manager.refresh_population()
	var site := ConstructionSite.new()
	site.setup(group.required_buildings[0], Vector2i(5,5), 0, false)
	world.add_child(site)
	site.set_process(false)
	for state: int in [ConstructionSite.State.WAITING_RESOURCES, ConstructionSite.State.READY_TO_BUILD, ConstructionSite.State.BUILDING]:
		site.state = state
		_expect(not manager._has_required_building(group.required_buildings[0]), "未建成农场不计入建筑需求：状态 %d" % state)
		_expect(not manager.can_start_immigration(), "未建成农场不能触发移民")
		_expect(manager._get_building_requirements_text().contains("缺少"), "移民面板显示农场缺少")
	manager._update_immigration_countdown(1)
	_expect(not manager.immigration_countdown_active, "农场未完工时不开始倒计时")
	site._complete_construction()
	await process_frame
	_expect(manager._has_required_building(group.required_buildings[0]), "真实施工完工后满足农场需求")
	_expect(manager.can_start_immigration(), "农场完工后允许移民")
	_expect(manager._get_building_requirements_text().contains("已满足"), "完工后移民面板显示已满足")
	manager._update_immigration_countdown(1)
	_expect(manager.immigration_countdown_active, "农场完工后开始倒计时")
	var farm: BuildingBase = get_first_node_in_group("resource_buildings")
	farm.demolition_state = BuildingBase.DemolitionState.WAITING_FOR_WORKER
	manager._update_immigration_countdown(1)
	_expect(not manager.can_start_immigration() and not manager.immigration_countdown_active, "拆除农场后条件失效并取消倒计时")
	world.queue_free()
	await process_frame
	print("移民建筑完工测试", "失败" if failed else "通过")
	quit(1 if failed else 0)
