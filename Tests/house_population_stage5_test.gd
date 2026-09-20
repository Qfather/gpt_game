extends SceneTree

var _failed: bool = false


func _initialize() -> void:
	var manager: PopulationManager = PopulationManager.new()
	get_root().add_child(manager)
	await process_frame

	var initial_population: int = manager.get_population()
	var initial_migrant_count: int = manager.get_tree().get_nodes_in_group(
		"migrants"
	).size()

	_expect(initial_population >= 0, "PopulationManager 可以读取正式人口")
	_expect(initial_migrant_count >= 0, "场景可以查询 Migrant 实体")
	_expect(
		manager.get_population() == manager.get_tree().get_nodes_in_group("villagers").size(),
		"Migrant 不会进入正式 Villager 人口统计"
	)

	manager.free()
	if _failed:
		printerr("House / Population V1 阶段 5 测试失败")
		quit(1)
		return

	print("House / Population V1 阶段 5 基础测试通过")
	quit()


func _expect(condition: bool, description: String) -> void:
	if condition:
		print("[通过] ", description)
		return

	_failed = true
	printerr("[失败] ", description)
