extends SceneTree

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world
	var catalog := BuildingCatalog.new()
	world.add_child(catalog)
	for data: BuildingData in catalog.buildings.values():
		assert(catalog.validate(data).is_empty(), str(data.id) + catalog.validate(data))
	var invalid: BuildingData = catalog.buildings[&"militia_camp"].duplicate(true)
	invalid.building_scene = load("res://Scene/unit/villager.tscn")
	assert(not catalog.validate(invalid).is_empty(), "误选单位场景不能作为功能建筑")
	for id: StringName in [&"lumber_camp", &"quarry", &"farm", &"house", &"militia_camp", &"dirt_road", &"stone_road", &"torch", &"wood_wall"]:
		assert(catalog.can_build(catalog.buildings[id]))
	for id: StringName in [&"hunter_hut", &"barracks", &"arrow_tower", &"swordsman_camp", &"archer_camp"]:
		assert(not catalog.is_unlocked(catalog.buildings[id]))
	assert(catalog.get_pool(&"standard").size() == 5)
	assert(catalog.get_pool(&"missing").is_empty())
	var advanced := catalog.buildings[&"swordsman_camp"].duplicate(true) as BuildingData
	advanced.id = &"test_t2"
	advanced.tier = 2
	advanced.upgrade_from_id = &"swordsman_camp"
	advanced.blueprint_pool = &"advanced"
	catalog.buildings[advanced.id] = advanced
	assert(catalog.get_pool(&"advanced").is_empty())
	assert(not catalog.choose_blueprint(&"hunter_hut"), "不能选择未发出的蓝图")
	var direct: BuildingData = catalog.buildings[&"hunter_hut"].duplicate(true)
	direct.id = &"test_direct_prerequisite"
	direct.upgrade_from_id = &"militia_camp"
	direct.blueprint_pool = &"direct"
	catalog.buildings[direct.id] = direct
	assert(catalog.validate(direct).is_empty(), "直接建造的前置关联不要求同占地")
	assert(not catalog.get_upgrade_children(&"militia_camp").has(direct), "直接建造的关联不会变成营地升级选项")
	var hud: GameHUD = load("res://Scene/ui/hud.tscn").instantiate()
	world.add_child(hud)
	await process_frame
	assert(hud.menu_buildings.any(func(data: BuildingData) -> bool: return data.id == &"militia_camp"))
	assert(not hud.menu_buildings.any(func(data: BuildingData) -> bool: return data.tier == 1))
	for iteration: int in range(5):
		var remaining: int = catalog.get_pool(&"standard").size()
		hud.show_blueprint_choices()
		assert(paused and hud.blueprint_window.visible)
		assert(catalog.offered.size() == mini(3, remaining))
		var ids: Array[StringName] = []
		for data: BuildingData in catalog.offered:
			assert(not ids.has(data.id))
			ids.append(data.id)
		var offer := catalog.offered.duplicate()
		hud._close_blueprint_choices()
		assert(not paused)
		hud.show_blueprint_choices()
		assert(catalog.offered == offer, "关闭再开不能刷新选项")
		if DisplayServer.get_name() != "headless" and iteration == 0:
			await RenderingServer.frame_post_draw
			hud.blueprint_window.get_texture().get_image().save_png("res://.godot/blueprint_cards.png")
		var chosen: BuildingData = catalog.offered[0]
		# 点击真实按钮，由窗口选择回调解锁并恢复原暂停状态。
		var cards: HBoxContainer = hud.blueprint_window.get_child(0).get_child(1)
		cards.get_child(0).pressed.emit()
		assert(not paused and catalog.is_unlocked(chosen))
		assert(catalog.get_pool(&"standard").size() == remaining - 1)
		assert(catalog.can_build(chosen) == chosen.allow_direct_build)
		assert(hud.menu_buildings.has(chosen) == chosen.allow_direct_build)
	assert(catalog.get_pool(&"advanced").size() == 1)
	paused = true
	hud.show_blueprint_choices()
	assert(catalog.offered.is_empty())
	hud._close_blueprint_choices()
	assert(paused, "原来暂停的游戏关闭抽取后仍暂停")
	paused = false
	var fresh := BuildingCatalog.new()
	assert(fresh.unlocked.is_empty(), "新局蓝图不继承")
	fresh.free()
	advanced.upgrade_from_id = advanced.id
	assert(not catalog.validate(advanced).is_empty())
	world.queue_free()
	await process_frame
	print("蓝图、三选一HUD、重复抽取、前置池与新局重置测试通过")
	quit()
