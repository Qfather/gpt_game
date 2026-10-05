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
	quit(1 if failed else 0)
