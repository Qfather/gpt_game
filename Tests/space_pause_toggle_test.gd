extends SceneTree

var failed: bool = false

func _init() -> void:
	call_deferred("_run")

func _expect(value: bool, message: String) -> void:
	print("[通过] " if value else "[失败] ", message)
	failed = failed or not value

func _space(pressed: bool, echo: bool = false) -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_SPACE
	event.physical_keycode = KEY_SPACE
	event.pressed = pressed
	event.echo = echo
	root.push_input(event)

func _run() -> void:
	var main: Node = load("res://Scene/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	for frame: int in range(5): await process_frame
	var hud: GameHUD = main.get_node("UI/HUD")
	for while_paused: bool in [false, true]:
		paused = while_paused
		hud.pause_button.grab_focus()
		var hide_event := InputEventKey.new()
		hide_event.keycode = KEY_H
		hide_event.pressed = true
		root.push_input(hide_event)
		_expect(not main.get_node("UI").visible and not hud.visible and not main.get_node("UI/FloatingTextManager").visible, "H隐藏所有UI画布层：暂停=%s" % while_paused)
		if not while_paused and DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://.godot/hud-hidden.png")
		hide_event.echo = true
		root.push_input(hide_event)
		_expect(not hud.visible, "长按H不会反复切换")
		hide_event.echo = false
		root.push_input(hide_event)
		_expect(main.get_node("UI").visible and hud.visible and main.get_node("UI/FloatingTextManager").visible, "再次按H恢复所有UI画布层")
	paused = false
	for focused: bool in [false, true]:
		if focused: hud.pause_button.grab_focus()
		else: root.gui_release_focus()
		_space(true)
		_expect(paused and hud.pause_button.text == "继续", "按下空格暂停：按钮焦点=%s" % focused)
		_space(true, true)
		_expect(paused, "长按重复事件不切换暂停")
		_space(false)
		_expect(paused, "松开空格仍保持暂停")
		_space(true)
		_expect(not paused and hud.pause_button.text == "暂停", "再次按下空格恢复")
		_space(false)
		_expect(not paused, "再次松开不改变运行状态")
	var controls: Node = hud.get_node("PanelContainer/VBoxContainer/HBoxContainer")
	_expect(controls.get_node_or_null("Speed5Button") == null and controls.get_node_or_null("Speed10Button") == null, "移除5倍和10倍按钮")
	root.gui_release_focus()
	for speed: int in [1, 2, 3]:
		controls.get_node("Speed%dButton" % speed).pressed.emit()
		_expect(Engine.time_scale == float(speed) and not paused, "保留%d倍按钮" % speed)
		var event := InputEventKey.new()
		event.keycode = KEY_1 + speed - 1
		event.pressed = true
		Engine.time_scale = 1.0
		root.push_input(event)
		_expect(Engine.time_scale == float(speed), "保留数字%d快捷键" % speed)
	for key: Key in [KEY_4, KEY_5]:
		var event := InputEventKey.new()
		event.keycode = key
		event.pressed = true
		root.push_input(event)
		_expect(Engine.time_scale == 3.0, "旧加速快捷键不再改变倍速")
	Engine.time_scale = 1.0
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/hud-speed-three.png")
	quit(1 if failed else 0)
