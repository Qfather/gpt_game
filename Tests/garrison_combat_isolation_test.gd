extends SceneTree

var _failed: bool = false


func _initialize() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	var barracks: Barracks = Barracks.new()
	get_root().add_child(barracks)

	var villager_scene: PackedScene = preload("res://Scene/unit/villager.tscn")
	var swordsman: Node = villager_scene.instantiate()
	swordsman.set_combat_role(CombatRole.Type.SWORDSMAN)
	get_root().add_child(swordsman)
	await process_frame

	swordsman.enter_garrison(barracks)
	barracks.garrisoned_units.clear()
	swordsman.state = swordsman.State.IDLE
	var fake_enemy: Node3D = Node3D.new()
	get_root().add_child(fake_enemy)
	swordsman.combat_target = fake_enemy

	_expect(not swordsman._process_combat(0.1), "军营内剑士不会进入战斗处理")
	_expect(swordsman.combat_target == null, "驻军会清除错误取得的战斗目标")
	_expect(swordsman.state == swordsman.State.GARRISONED, "幽灵 IDLE 状态恢复为驻军状态")
	_expect(not swordsman.visible, "驻军修复后继续隐藏在军营内部")
	_expect(barracks.get_garrison_count() == 1, "军营重新收录仍属于自己的驻军")

	fake_enemy.free()
	swordsman.free()
	barracks.free()

	if _failed:
		printerr("驻军战斗隔离测试失败")
		quit(1)
		return

	print("驻军战斗隔离测试通过")
	quit()


func _expect(condition: bool, description: String) -> void:
	if condition:
		print("[通过] ", description)
		return

	_failed = true
	printerr("[失败] ", description)
