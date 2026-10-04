extends SceneTree

var failed: bool = false

func _init() -> void:
	call_deferred("_schedule")

func _schedule() -> void:
	create_timer(5).timeout.connect(_run)

func _expect(value: bool, message: String) -> void:
	print("[", "通过" if value else "失败", "] ", message)
	if not value: failed = true

func _properties(node: Node, result: Dictionary) -> void:
	if node is EditorProperty:
		result[node.get_edited_property()] = node.label
	for child: Node in node.get_children(true): _properties(child, result)

func _run() -> void:
	var panel: Control = load("res://addons/resource_editor/level_environment_panel.gd").new()
	root.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var level: LevelFlowData = load("res://data/levels/LevelFlow_40min_Hard.tres").duplicate(true)
	panel.edit_preset(level)
	panel.resource_inspector.expand_all_folding()
	await create_timer(0.3).timeout
	var labels: Dictionary = {}
	_properties(panel.resource_inspector, labels)
	for key: String in ["regrowth_enabled", "regrowth_mode", "regrowth_wait_min", "regrowth_wait_max", "growth_time_min", "growth_time_max", "mature_scale_min", "mature_scale_max"]:
		_expect(labels.get(key) == panel.LABELS[key], "资源检查器显示中文配置：" + panel.LABELS[key])
	level.map_resources[0].regrowth_wait_min = 20.0
	level.map_resources[0].regrowth_wait_max = 40.0
	level.map_resources[0].growth_time_min = 180.0
	level.map_resources[0].growth_time_max = 300.0
	level.map_resources[1].regrowth_enabled = false
	var path: String = "res://.godot/regrowth_level_editor.tres"
	_expect(ResourceSaver.save(level, path) == OK, "再生设置随关卡统一保存")
	var loaded: LevelFlowData = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP)
	_expect(loaded.map_resources[0].regrowth_wait_min == 20.0 and loaded.map_resources[0].regrowth_wait_max == 40.0 and loaded.map_resources[0].growth_time_max == 300.0, "关卡重载保留树木再生与生长时间")
	_expect(not loaded.map_resources[1].regrowth_enabled, "不同资源条目可以独立关闭再生")
	panel.resource_inspector.get_v_scroll_bar().value = panel.resource_inspector.get_v_scroll_bar().max_value
	await create_timer(0.3).timeout
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/resource_regrowth_editor_preview.png")
	panel.queue_free()
	await process_frame
	quit(1 if failed else 0)
