extends SceneTree

class CountingFog extends "res://Script/world/fog_of_war.gd":
	var refresh_count: int = 0
	func _ready() -> void:
		set_process(false)
		initialized = true
	func refresh_visibility() -> void:
		refresh_count += 1

var failed: bool = false

func _init() -> void:
	call_deferred("_run")

func _expect(value: bool, text: String) -> void:
	print("[", "通过" if value else "失败", "] ", text)
	if not value:
		failed = true
		push_error(text)

func _run() -> void:
	var counter := CountingFog.new()
	root.add_child(counter)
	for i in range(60): counter._process(1.0 / 60.0)
	var normal_count: int = counter.refresh_count
	counter.refresh_count = 0
	counter.timer = 0.0
	Engine.time_scale = 3.0
	for i in range(60): counter._process(3.0 / 60.0)
	_expect(normal_count > 0 and counter.refresh_count == normal_count, "1倍和3倍速相同真实时间的迷雾刷新次数一致")
	counter.free()
	Engine.time_scale = 1.0
	var main: Node3D = load("res://Scene/main.tscn").instantiate()
	main.level_preset = main.level_preset.duplicate(true)
	main.level_preset.layout_seed = 418
	main.level_preset.events.clear()
	main.level_preset.camp_config.enabled = false
	root.add_child(main)
	current_scene = main
	await create_timer(1.5, true, false, true).timeout
	var hud: GameHUD = main.get_node("UI/HUD")
	for speed: float in [1.0, 3.0]:
		Engine.time_scale = speed
		hud.fps_label.text = "等待更新"
		await create_timer(0.7, true, false, true).timeout
		_expect(hud.fps_label.text.begins_with("帧率：") and hud.fps_label.text.ends_with(" FPS"), "%s倍速帧率正常更新" % speed)
	paused = true
	hud.fps_label.text = "等待更新"
	await create_timer(0.7, true, false, true).timeout
	_expect(hud.fps_label.text.begins_with("帧率："), "暂停时仍显示帧率")
	_expect(Engine.get_frames_per_second() > 0, "GPU运行取得有效帧率")
	var rect: Rect2 = hud.fps_label.get_global_rect()
	_expect(root.get_visible_rect().encloses(rect), "帧率标签完整位于窗口内")
	_expect(rect.position.y >= hud.archer_label.get_global_rect().end.y, "帧率位于弓箭手统计下方")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/hud_fps_preview.png")
	paused = false
	Engine.time_scale = 1.0
	main.queue_free()
	await process_frame
	quit(1 if failed else 0)
