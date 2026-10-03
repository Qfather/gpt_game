extends SceneTree

var failed: bool = false

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world
	var manager := TaskManager.new()
	world.add_child(manager)
	var base: Node3D = load("res://Scene/building/base.tscn").instantiate()
	world.add_child(base)
	var worker: Node3D = load("res://Scene/unit/villager.tscn").instantiate()
	world.add_child(worker)
	worker.set_physics_process(false)
	worker.collision_mask = 0
	var map: RID = NavigationServer3D.map_create()
	NavigationServer3D.map_set_active(map, true)
	var region: RID = NavigationServer3D.region_create()
	var mesh := NavigationMesh.new()
	mesh.vertices = PackedVector3Array([Vector3(-8, 4, -8), Vector3(-8, 4, 8), Vector3(8, 4, 8), Vector3(8, 4, -8)])
	mesh.add_polygon(PackedInt32Array([0, 1, 2, 3]))
	NavigationServer3D.region_set_navigation_mesh(region, mesh)
	NavigationServer3D.region_set_map(region, map)
	worker.navigation_agent.set_navigation_map(map)
	for index in range(10): await physics_frame
	worker.global_position = Vector3(0, 4, 0)
	worker.target_base = base
	var bundle: LootBundle = load("res://Scene/world/loot_bundle.tscn").instantiate()
	bundle.configure(&"wood", 3)
	bundle.position = Vector3(4, 0, 0)
	world.add_child(bundle)
	for index in range(3): await process_frame
	worker._start_current_task()
	_expect(worker.state == worker.State.MOVE_TO_LOOT, "领取回收战利品任务")
	for index in range(180):
		worker.move_to_loot_bundle()
		if worker.carried_amount > 0: break
		await physics_frame
	_expect(worker.carried_amount == 3 and worker.carried_resource_id == &"wood", "高地居民能拾取原始高度为零的战利品")
	_expect(worker.state == worker.State.MOVE_TO_BASE and worker.current_task == null, "拾取完成后解除任务并返回据点")
	await process_frame
	_expect(not is_instance_valid(bundle), "搬空包裹被释放")
	var enemy: EnemyBase = load("res://Scene/unit/enemy_base.tscn").instantiate()
	world.add_child(enemy)
	enemy.set_process(false)
	enemy.set_physics_process(false)
	enemy.navigation_agent.set_navigation_map(map)
	enemy.global_position = Vector3(2, 4.6, 2)
	enemy.stolen_resources[&"wood"] = 2
	enemy._drop_stolen_loot()
	var dropped: Node3D = get_first_node_in_group("loot_bundles") as Node3D
	_expect(dropped != null and is_equal_approx(dropped.global_position.y, 4), "高地敌人的掉落包裹位于导航地面")
	worker.carried_amount = 0
	worker.set_combat_role(CombatRole.Type.ARCHER)
	var hud: GameHUD = load("res://Scene/ui/hud.tscn").instantiate()
	world.add_child(hud)
	hud._refresh_population_display(1, 5)
	_expect(hud.archer_label.text == "弓箭手：1" and hud.swordsman_label.text == "剑士：0", "HUD 分别统计弓箭手与剑士")
	worker.set_combat_role(CombatRole.Type.SWORDSMAN)
	hud._refresh_population_display(1, 5)
	_expect(hud.archer_label.text == "弓箭手：0" and hud.swordsman_label.text == "剑士：1", "角色改变后统计更新")
	world.queue_free()
	await process_frame
	NavigationServer3D.free_rid(region)
	NavigationServer3D.free_rid(map)
	print("战利品导航及弓箭手统计测试", "失败" if failed else "通过")
	quit(1 if failed else 0)

func _expect(value: bool, message: String) -> void:
	print("[", "通过" if value else "失败", "] ", message)
	if not value:
		failed = true
		push_error(message)
