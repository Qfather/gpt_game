extends SceneTree

class ResidentFixture extends Node:
	var role: int = 0
	var idle: bool = false
	func get_combat_role() -> int: return role
	func is_idle_resident() -> bool: return idle

var failed: bool = false

func _initialize() -> void:
	call_deferred("_run")

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		push_error(message)

func _run() -> void:
	root.size = Vector2i(1280, 720)
	var manager := ResourceManager.new()
	root.add_child(manager)
	var storage := ResourceStorage.new()
	root.add_child(storage)
	var hud: GameHUD = load("res://Scene/ui/hud.tscn").instantiate()
	root.add_child(hud)
	await process_frame
	await process_frame
	var resources := ResourceEditorDataService.scan_resources()
	_expect(resources.size() == 8, "底部资源面板应扫描全部8种资源")
	for data: ResourceData in resources:
		_expect(data.icon != null, "资源缺少初始图标：" + String(data.id))
		_expect(hud.resource_labels.has(data.id), "HUD遗漏资源：" + String(data.id))
		if hud.resource_labels.has(data.id):
			var label: Label = hud.resource_labels[data.id]
			_expect(label.text == "0", "无库存时应只显示0")
			_expect(label.get_parent().tooltip_text == data.display_name, "资源悬停名称必须读取定义")
	storage.add(&"wood", 25)
	await process_frame
	await process_frame
	_expect(hud.resource_labels[&"wood"].text == "25", "库存变化后应刷新真实资源数值")
	for file: String in DirAccess.get_files_at("res://data/units"):
		if not file.ends_with(".tres"): continue
		var data: UnitData = load("res://data/units/" + file)
		_expect(data.icon != null, "单位应有静态模型图标：" + String(data.id))
		var copy: UnitData = data.duplicate()
		copy.icon = load("res://assets/icons/placeholder.svg")
		var path := "res://.godot/unit_icon_roundtrip.tres"
		_expect(ResourceSaver.save(copy, path) == OK, "单位替换图标可以保存")
		var saved: UnitData = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
		_expect(saved.icon.resource_path == "res://assets/icons/placeholder.svg", "单位替换图标可以重新读取")
	DirAccess.remove_absolute("res://.godot/unit_icon_roundtrip.tres")
	var fixtures: Array[Node] = []
	for role: int in [0, 0, 0, 1, 2, 3]:
		var resident := ResidentFixture.new()
		resident.role = role
		resident.idle = fixtures.is_empty()
		root.add_child(resident)
		resident.add_to_group("villagers")
		fixtures.append(resident)
	hud._refresh_population_display(6, 12)
	_expect(hud.resident_label.text == "3", "居民统一按非军事身份计数")
	_expect(hud.idle_resident_label.text == "1", "空闲居民必须单独计数")
	_expect(hud.militia_label.text == "1" and hud.swordsman_label.text == "1" and hud.archer_label.text == "1", "军事人数不应重复计入居民")
	_expect(hud.population_label.text == "6 / 12", "总人口保留住房容量")
	var population: Node = hud.population_label.get_parent().get_parent()
	_expect(population.get_child(-1) == hud.population_label.get_parent(), "总人口必须位于最右侧")
	_expect(hud.idle_resident_label.get_parent() == hud.resident_label.get_parent(), "空闲人数应位于居民条目下方")
	for width: int in [1280, 1920]:
		root.size = Vector2i(width, 720)
		await process_frame
		await process_frame
		var resource_panel: Control = hud.get_node("ResourceStatus")
		var population_panel: Control = hud.get_node("PopulationStatus")
		_expect(resource_panel.get_global_rect().end.x < hud.game_clock.get_global_rect().position.x, "资源不能覆盖计时器")
		_expect(population_panel.get_global_rect().position.x > hud.game_clock.get_global_rect().end.x, "人口不能覆盖计时器")
		_expect(resource_panel.position.x >= 0 and population_panel.get_global_rect().end.x < width, "两侧条目必须位于屏幕内")
		_expect(hud.debug_panel.position.y > resource_panel.get_global_rect().end.y, "调试工具不能遮挡资源数值")
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://.godot/hud_icons_%d.png" % width)
	if DisplayServer.get_name() != "headless":
		var motion := InputEventMouseMotion.new()
		motion.position = hud.resource_labels[&"wood"].get_parent().get_global_rect().get_center()
		root.push_input(motion)
		await create_timer(0.8).timeout
		var tooltip_shown := false
		for label: Node in root.find_children("*", "Label", true, false):
			if label.text == "木材" and label.is_visible_in_tree(): tooltip_shown = true
		_expect(tooltip_shown, "鼠标悬停资源条目应实际显示木材提示")
	for fixture: Node in fixtures: fixture.queue_free()
	hud.queue_free()
	manager.queue_free()
	storage.queue_free()
	await process_frame
	print("HUD图标与横排回归：", "失败" if failed else "通过")
	quit(1 if failed else 0)
