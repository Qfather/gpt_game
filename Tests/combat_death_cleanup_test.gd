extends SceneTree

var _failed: bool = false


func _initialize() -> void:
	var manager: PopulationManager = PopulationManager.new()
	get_root().add_child(manager)
	var villager_scene: PackedScene = preload("res://Scene/unit/villager.tscn")
	var villager: Node = villager_scene.instantiate()
	villager.set_combat_role(CombatRole.Type.SWORDSMAN)
	get_root().add_child(villager)
	await process_frame

	villager.take_damage(9999.0)
	await process_frame
	_expect(
		not get_nodes_in_group("villagers").has(villager),
		"剑士死亡后会立即移出居民组"
	)
	_expect(manager.get_population() == 0, "死亡剑士不会继续计入人口 HUD")

	if is_instance_valid(villager):
		villager.free()
	manager.free()
	if _failed:
		printerr("Combat 死亡清理测试失败")
		quit(1)
		return

	print("Combat 死亡清理测试通过")
	quit()


func _expect(condition: bool, description: String) -> void:
	if condition:
		print("[通过] ", description)
		return

	_failed = true
	printerr("[失败] ", description)
