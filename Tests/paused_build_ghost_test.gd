extends SceneTree

const MAIN_SCENE: PackedScene = preload("res://Scene/main.tscn")
const BUILDING_DATA: BuildingData = preload("res://data/buildings/LumberCampData.tres")


func _initialize() -> void:
	call_deferred("_run_test")


func _run_test() -> void:
	var main_scene: Node = MAIN_SCENE.instantiate()
	root.add_child(main_scene)
	await process_frame
	var ghost: BuildingGhost = main_scene.get_node("Systems/BuildingGhost")
	var hud: GameHUD = main_scene.get_node("UI/HUD")
	ghost.select_building(BUILDING_DATA)
	_expect(ghost.is_placement_active(), "选择建筑后放置预览处于活动状态")
	var preview_visible_before_pause: bool = ghost.visible
	hud.pause_game()
	await process_frame
	_expect(ghost.is_placement_active(), "暂停不清除当前放置状态")
	_expect(ghost.visible == preview_visible_before_pause, "暂停不改变放置预览的显示状态")
	_expect(ghost.process_mode == Node.PROCESS_MODE_ALWAYS, "暂停期间预览仍可处理输入和刷新")
	_expect(hud.pause_button.text == "继续", "暂停按钮切换为继续")
	hud._on_pause_button_pressed()
	_expect(not paused, "再次点击暂停按钮可以恢复游戏")
	_expect(ghost.is_placement_active(), "恢复游戏后继续保留当前放置状态")
	paused = false
	main_scene.queue_free()
	print("暂停建造预览测试通过")
	quit()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		push_error("失败：" + message)
		quit(1)
