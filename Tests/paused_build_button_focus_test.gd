extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var main: Node = load("res://Scene/main.tscn").instantiate()
	main.level_preset = main.level_preset.duplicate(true)
	main.level_preset.events.clear()
	main.level_preset.camp_config.enabled = false
	root.add_child(main)
	current_scene = main
	await process_frame
	var hud: GameHUD = main.get_node("UI/HUD")
	var ghost: BuildingGhost = main.get_node("Systems/BuildingGhost")
	var button: Button = hud.build_buttons.get_child(0)
	# 模拟上一次点过建造按钮，摆放结束或取消后按钮仍可能持有焦点。
	if button.focus_mode != Control.FOCUS_NONE:
		button.grab_focus()
	button.pressed.emit()
	ghost.cancel_preview()
	await _space()
	if not paused or ghost.is_placement_active():
		push_error("空格未暂停，或重新触发了上次的建筑按钮")
		paused = false
		quit(1)
		return
	await _space()
	if paused or ghost.is_placement_active():
		push_error("空格未恢复，或恢复后重新进入建筑放置")
		paused = false
		quit(1)
		return
	button.pressed.emit()
	if not ghost.is_placement_active():
		push_error("修改后建筑按钮无法正常选择建筑")
		quit(1)
		return
	ghost.cancel_preview()
	main.queue_free()
	await process_frame
	print("建造按钮空格回归通过：暂停恢复不重新选择建筑，鼠标按钮功能保留")
	quit()

func _space() -> void:
	var key := InputEventKey.new()
	key.keycode = KEY_SPACE
	key.physical_keycode = KEY_SPACE
	key.pressed = true
	Input.parse_input_event(key)
	await process_frame
	key = key.duplicate()
	key.pressed = false
	Input.parse_input_event(key)
	await process_frame
