extends SceneTree

var failed: bool = false

func _init() -> void:
	call_deferred("_run")

func _expect(value: bool, message: String) -> void:
	print("[", "通过" if value else "失败", "] ", message)
	if not value:
		failed = true
		push_error(message)

func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world
	var region := NavigationRegion3D.new()
	var mesh := NavigationMesh.new()
	mesh.vertices = PackedVector3Array([Vector3(-8,0,-10),Vector3(-8,0,-1),Vector3(8,0,-1),Vector3(8,0,-10),Vector3(-8,0,1),Vector3(-8,0,10),Vector3(8,0,10),Vector3(8,0,1)])
	mesh.add_polygon(PackedInt32Array([0,1,2,3]))
	mesh.add_polygon(PackedInt32Array([4,5,6,7]))
	region.navigation_mesh = mesh
	world.add_child(region)
	var base: BuildingBase = load("res://Scene/building/base.tscn").instantiate()
	base.set_building_data(load("res://data/buildings/BaseData.tres"))
	world.add_child(base)
	base.position = Vector3(0,0,5)
	var wall: Wall = load("res://Scene/building/game/wall.tscn").instantiate()
	wall.set_building_data(load("res://data/buildings/WallData.tres"))
	world.add_child(wall)
	wall.scale.x = 6.0
	var enemy: EnemyBase = load("res://Scene/unit/enemy_base.tscn").instantiate()
	enemy.enemy_data = load("res://data/enemies/raid/SlimeData.tres").duplicate(true)
	enemy.enemy_data.raid_objective = EnemyData.RaidObjective.NONE
	world.add_child(enemy)
	enemy.position = Vector3(0,0.65,-4)
	enemy.raid_active = true
	enemy.damage = 30.0
	enemy.attack_interval = 0.15
	enemy.move_speed = 4.0
	for frame: int in range(180):
		await physics_frame
		if wall.get_health() < wall.get_max_health(): break
	_expect(wall.get_health() < wall.get_max_health(), "前往据点的路径被封死后，怪物实际攻击挡路城墙")
	_expect(enemy.target == wall, "普通索敌更新不会不断把目标从挡路城墙切回据点")
	var defender: Node3D = load("res://Scene/unit/villager.tscn").instantiate()
	defender.combat_role = CombatRole.Type.SWORDSMAN
	world.add_child(defender)
	defender.set_physics_process(false)
	defender.position = Vector3(1,0,-2)
	for frame in range(5): await physics_frame
	enemy.update_targeting()
	_expect(enemy.target == defender, "同侧战斗单位接近时优先与其交战")
	defender.queue_free()
	await process_frame
	for frame: int in range(300):
		await physics_frame
		if not is_instance_valid(wall): break
	_expect(not is_instance_valid(wall), "怪物持续攻击直到城墙被摧毁")
	enemy.update_targeting()
	_expect(enemy.target == base, "城墙释放后安全恢复原据点目标")
	enemy.set_process(false)
	enemy.set_physics_process(false)
	wall = load("res://Scene/building/game/wall.tscn").instantiate()
	wall.set_building_data(load("res://data/buildings/WallData.tres"))
	world.add_child(wall)
	wall.scale.x = 6.0
	var worker: Node3D = load("res://Scene/unit/villager.tscn").instantiate()
	world.add_child(worker)
	worker.set_physics_process(false)
	worker.position = Vector3(0,0,0.9)
	enemy.position = Vector3(0,0.65,-0.9)
	enemy.attack_range = 2.0
	enemy.attack_cooldown = 0.0
	enemy._set_target(worker)
	var worker_health: float = worker.get_health()
	await physics_frame
	enemy._physics_process(0.1)
	enemy._physics_process(0.1)
	_expect(worker.get_health() == worker_health and wall.get_health() < wall.get_max_health(), "目标虽在攻击范围内，也先攻击遮挡城墙，不隔墙伤害居民")
	wall.queue_free()
	await process_frame
	enemy._set_target(worker)
	_expect(enemy.target == worker, "外部删除挡路城墙后引用检查安全，目标可正常切换")
	world.queue_free()
	await process_frame
	quit(1 if failed else 0)
