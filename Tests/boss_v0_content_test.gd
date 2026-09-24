extends SceneTree

const DEMON: EnemyData = preload("res://data/enemies/rift/DemonBossData.tres")
const SPIDER: EnemyData = preload("res://data/enemies/rift/SpiderBossData.tres")


func _init() -> void:
	_validate_boss(DEMON, "恶魔BOSS", 12)
	_validate_boss(SPIDER, "蜘蛛BOSS", 12)
	print("BOSS V0 内容测试通过")
	quit()


func _validate_boss(data: EnemyData, expected_name: String, minimum_meshes: int) -> void:
	_expect(data.is_boss, "%s 已标记为BOSS" % expected_name)
	_expect(data.faction == EnemyData.Faction.RIFT, "%s 属于裂缝阵营" % expected_name)
	_expect(data.display_name == expected_name, "%s 显示名称正确" % expected_name)
	_expect(data.visual_scene != null, "%s 配置了模型场景" % expected_name)
	if data.visual_scene == null:
		return
	var visual: Node = data.visual_scene.instantiate()
	_expect(visual != null, "%s 模型场景可实例化" % expected_name)
	if visual == null:
		return
	var meshes: Array[Node] = visual.find_children("*", "MeshInstance3D", true, false)
	_expect(meshes.size() >= minimum_meshes, "%s 模型由多个基础网格组成" % expected_name)
	visual.free()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		push_error("失败：" + message)
		quit(1)
