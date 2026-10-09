extends SceneTree

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	var main: Node3D = load("res://Scene/main.tscn").instantiate()
	main.level_preset = main.level_preset.duplicate(true)
	main.level_preset.layout_seed = 418
	main.level_preset.events.clear()
	main.level_preset.camp_config.enabled = false
	root.add_child(main)
	current_scene = main
	for frame: int in range(20): await physics_frame
	paused = true
	var catalog := BuildingCatalog.for_tree(self)
	var base: Node3D = get_first_node_in_group("bases")
	var data: BuildingData = catalog.buildings[&"militia_camp"]
	var camp: SwordsmanCamp = data.building_scene.instantiate()
	camp.set_building_data(data)
	main.get_node("buildings").add_child(camp)
	camp.position = base.position + Vector3(5, 0, 0)
	var panel: ResourceBuildingPanel = main.resource_building_panel
	panel.open_building(camp)
	await create_timer(0.4).timeout
	panel.refresh()
	assert(panel.upgrade_choices.get_child_count() == 2)
	for button: Button in panel.upgrade_choices.get_children(): assert(button.disabled)
	assert(panel.training_choices.get_child_count() == 1 and not panel.hire_button.visible)
	await _capture("blueprint_militia_panel")
	catalog.offered = [catalog.buildings[&"swordsman_camp"]]
	assert(catalog.choose_blueprint(&"swordsman_camp"))
	panel.refresh()
	var enabled := 0
	for button: Button in panel.upgrade_choices.get_children():
		if not button.disabled: enabled += 1
	assert(enabled == 1, "仅获得对应分支权限")
	await _capture("blueprint_militia_unlocked_panel")
	var sword: SwordsmanCamp = catalog.buildings[&"swordsman_camp"].building_scene.instantiate()
	sword.set_building_data(catalog.buildings[&"swordsman_camp"])
	main.get_node("buildings").add_child(sword)
	panel.open_building(sword)
	await create_timer(0.4).timeout
	panel.refresh()
	assert(panel.training_choices.get_child_count() == 2)
	assert(not panel.upgrade_choices.visible and not panel.hire_button.visible)
	await _capture("blueprint_sword_training_panel")
	paused = false
	main.queue_free()
	await process_frame
	print("实际游戏建筑面板：锁定／解锁分支、多个训练按钮与屏幕布局通过")
	quit()

func _capture(name: String) -> void:
	await process_frame
	var panel: ResourceBuildingPanel = current_scene.resource_building_panel
	var button_rect: Rect2 = panel.close_button.get_global_rect()
	assert(button_rect.end.y <= root.get_visible_rect().size.y, "关闭按钮不能落在屏幕下方")
	assert(button_rect.end.x <= root.get_visible_rect().size.x, "新增按钮不能撑宽面板导致右侧截断")
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/" + name + ".png")
