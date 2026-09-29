extends SceneTree

var failed: bool = false


func _initialize() -> void:
	call_deferred("_run")


func _expect(value: bool, message: String) -> void:
	if not value:
		failed = true
		push_error("失败：" + message)


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var scene: Node = load("res://Scene/main.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	for frame: int in range(10):
		await process_frame
	var hud: GameHUD = scene.get_node("UI/HUD") as GameHUD
	var director: EncounterDirector = scene.get_node("Systems/EncounterDirector") as EncounterDirector
	_expect(hud.wood_label.global_position.x > hud.population_label.global_position.x, "材料未在人口右侧")
	_expect(hud.game_clock.get_global_rect().get_center().x == 640, "时钟未在正上方中央")
	_expect(hud.get_node("ImmigrationPanel").get_global_rect().end.y <= 720, "移民面板超出屏幕")
	_expect(not hud.debug_scroll.visible, "调试工具未默认收起")
	var collapsed: float = hud.debug_panel.size.y
	hud.debug_toggle.pressed.emit()
	for frame: int in range(4):
		await process_frame
	_expect(hud.debug_scroll.visible and hud.debug_panel.size.y > collapsed, "调试工具无法展开")
	_expect(hud.debug_panel.get_global_rect().end.y < hud.threat_label.global_position.y, "调试工具遮住威胁提示")
	hud.debug_toggle.pressed.emit()
	for frame: int in range(4):
		await process_frame
	_expect(hud.debug_panel.size.y <= collapsed, "收起仍保留大块空白")
	paused = true
	director.elapsed_time = 125.0
	await process_frame
	await process_frame
	_expect(hud.game_clock.time_label.text == "02:05", "计时格式错误")
	await create_timer(0.1, true).timeout
	_expect(is_equal_approx(director.elapsed_time, 125), "暂停后时间继续增加")
	paused = false
	Engine.time_scale = 2.0
	var before: float = director.elapsed_time
	await create_timer(0.2, true, false, true).timeout
	_expect(director.elapsed_time - before > 0.3, "倍速未反映到游戏计时")
	Engine.time_scale = 1.0
	if "--preview" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/hud_layout.png")
		hud.debug_toggle.pressed.emit()
		for frame: int in range(4):
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/hud_layout_expanded.png")
	print("HUD布局测试", "失败" if failed else "通过")
	scene.queue_free()
	await process_frame
	quit(1 if failed else 0)
