extends SceneTree

var _failed: bool = false


func _initialize() -> void:
	var manager: PopulationManager = PopulationManager.new()
	get_root().add_child(manager)
	await process_frame

	_expect(
		ResourceLoader.exists("res://Scene/unit/villager.tscn"),
		"正式 Villager 场景可以读取"
	)
	_expect(
		ResourceLoader.exists("res://Scene/unit/migrant.tscn"),
		"Migrant 场景可以读取"
	)
	_expect(
		manager.has_method("_on_migrant_arrived"),
		"PopulationManager 具备 Migrant 抵达转换入口"
	)

	manager.free()
	if _failed:
		printerr("House / Population V1 阶段 6 测试失败")
		quit(1)
		return

	print("House / Population V1 阶段 6 基础测试通过")
	quit()


func _expect(condition: bool, description: String) -> void:
	if condition:
		print("[通过] ", description)
		return

	_failed = true
	printerr("[失败] ", description)
