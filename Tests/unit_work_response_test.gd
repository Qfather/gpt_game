extends SceneTree

const Facing = preload("res://Script/unit/unit_facing.gd")
var failed: bool = false

func _init() -> void:
	call_deferred("_run")

func _expect(condition: bool, message: String) -> void:
	print("[通过] " if condition else "[失败] ", message)
	failed = failed or not condition

func _worker(world: Node3D, position: Vector3) -> CharacterBody3D:
	var worker: CharacterBody3D = load("res://Scene/unit/villager.tscn").instantiate()
	world.add_child(worker)
	worker.position = position
	worker.set_physics_process(false)
	return worker

func _enemy(world: Node3D, position: Vector3) -> EnemyBase:
	var enemy: EnemyBase = load("res://Scene/unit/enemy_base.tscn").instantiate()
	enemy.enemy_data = load("res://data/enemies/raid/WolfData.tres")
	world.add_child(enemy)
	enemy.position = position
	enemy.set_process(false)
	enemy.set_physics_process(false)
	return enemy

func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world
	var region := NavigationRegion3D.new()
	var mesh := NavigationMesh.new()
	mesh.vertices = PackedVector3Array([Vector3(-30,0,-30), Vector3(-30,0,30), Vector3(30,0,30), Vector3(30,0,-30)])
	mesh.add_polygon(PackedInt32Array([0,1,2,3]))
	region.navigation_mesh = mesh
	world.add_child(region)
	var base: Node3D = load("res://Scene/building/base.tscn").instantiate()
	world.add_child(base)
	base.position = Vector3(-12,0,0)
	var soldier: CharacterBody3D = _worker(world, Vector3(-8,0,0))
	soldier.set_combat_role(CombatRole.Type.SWORDSMAN)
	soldier.combat_damage = 1000.0
	soldier.idle_reposition_timer = 9.0
	var first := _enemy(world, soldier.position + Vector3(0,0,0.5))
	var second := _enemy(world, soldier.position + Vector3(0.5,0,0))
	for frame: int in range(10): await physics_frame
	soldier.combat_target = first
	soldier._process_combat(0.016)
	_expect(first.is_dead(), "剑士击杀第一名敌人")
	soldier._process_combat(0.016)
	_expect(soldier.combat_target == second and second.is_dead(), "下一帧切换并攻击另一名敌人，无5秒等待")
	soldier._process_combat(0.016)
	_expect(soldier.state == soldier.State.RETURN_TO_IDLE, "敌人清空后立即返回据点，不等待随机待命计时")
	var camp: ResourceBuildingBase = load("res://Scene/building/game/lumber_camp.tscn").instantiate()
	world.add_child(camp)
	camp.set_process(false)
	var lumberjack := _worker(world, Vector3(0,0,2))
	camp.add_worker(lumberjack)
	lumberjack.state = lumberjack.State.IDLE
	lumberjack.idle_reposition_timer = 9.0
	var resting := _worker(world, Vector3(0,0,-2))
	camp.add_worker(resting)
	resting.state = resting.State.RESTING
	var tree: ResourceBase = load("res://Scene/resource/tree.tscn").instantiate()
	tree.growth_duration = 1.0
	world.add_child(tree)
	tree.position = Vector3(4,0,0)
	tree.set_process(false)
	tree._process(0.5)
	_expect(lumberjack.state == lumberjack.State.IDLE, "幼树不唤醒工人")
	tree._process(0.5)
	_expect(lumberjack.state == lumberjack.State.FIND_RESOURCE and resting.state == resting.State.RESTING, "树成熟即唤醒空闲伐木工，不打断休息")
	lumberjack.find_nearest_resource()
	_expect(lumberjack.target_resource == tree and lumberjack.state == lumberjack.State.MOVE_TO_RESOURCE, "新成熟树立即被预约采集")
	var farm: Farm = load("res://Scene/building/game/farm.tscn").instantiate()
	world.add_child(farm)
	farm.position = Vector3(10,0,0)
	farm.set_process(false)
	var farmer := _worker(world, Vector3(10,0,2))
	farm.add_worker(farmer)
	farmer.state = farmer.State.IDLE
	for child: Node in farm.get_children():
		if child is FarmField: child.set_state(FarmField.State.GROWING)
	var panel: VillagerPanel = load("res://UI/unit_panel/villager_panel.tscn").instantiate()
	root.add_child(panel)
	panel.current_unit = farmer
	panel.refresh()
	_expect(panel.state_label.text == "状态：等待庄稼成熟", "农民面板显示等待庄稼成熟")
	farm.get_node("FieldA").set_state(FarmField.State.MATURE)
	_expect(not farmer.is_waiting_for_crop(), "有成熟田地时不显示等待")
	panel.queue_free()
	var tower: Barracks = load("res://Scene/building/game/arrow_tower.tscn").instantiate()
	world.add_child(tower)
	tower.position = Vector3(0,0,12)
	tower.set_process(false)
	var archer := _worker(world, tower.position)
	archer.set_combat_role(CombatRole.Type.ARCHER)
	archer.enter_garrison(tower)
	var origin: Vector3 = archer.position
	var start_yaw: float = archer.visual_root.global_rotation.y
	if DisplayServer.get_name() != "headless":
		root.size = Vector2i(1000, 700)
		var camera := Camera3D.new()
		world.add_child(camera)
		camera.position = tower.position + Vector3(5, 6, 8)
		camera.look_at(tower.position + Vector3.UP * 2.5)
		camera.make_current()
		var light := DirectionalLight3D.new()
		world.add_child(light)
		light.rotation_degrees = Vector3(-45, -30, 0)
	for turn: int in range(4):
		archer.tower_look_timer = 0.0
		archer._process_tower_combat(0.016)
		Facing.update(archer.visual_root, 0.4)
		var yaw: float = archer.visual_root.global_rotation.y
		_expect(is_equal_approx(wrapf(yaw - start_yaw, -PI, PI), wrapf((turn + 1) * PI / 2.0, -PI, PI)), "塔上巡视转向第%d个方向" % (turn + 1))
		if DisplayServer.get_name() != "headless":
			await process_frame
			RenderingServer.force_draw(false)
			_expect(root.get_texture().get_image().save_png("res://.godot/archer_watch_%d.png" % (turn + 1)) == OK, "巡视画面截图保存")
	_expect(archer.position.is_equal_approx(origin), "巡视只转模型，不移动驻塔位置")
	var threat := _enemy(world, tower.position + Vector3(0,0,-2))
	archer.combat_attack_cooldown = 1.0
	archer._process_tower_combat(0.016)
	Facing.update(archer.visual_root, 0.4)
	var aim: Vector3 = threat.global_position - archer.global_position
	aim.y = 0.0
	_expect(archer.visual_root.global_basis.z.dot(aim.normalized()) > 0.99, "敌人出现即停止巡视并瞄准，冷却不影响瞄准")
	world.queue_free()
	await process_frame
	print("单位工作响应测试", "失败" if failed else "通过")
	quit(1 if failed else 0)
