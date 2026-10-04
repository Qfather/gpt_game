extends SceneTree

const PoolResource = preload("res://Script/unit/name_pool.gd")
var failed := false

func _init() -> void:
	call_deferred("_run")

func _expect(value: bool, text: String) -> void:
	print("[", "通过" if value else "失败", "] ", text)
	if not value:
		failed = true
		push_error(text)

func _run() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 418
	var pool := PoolResource.new()
	pool.surnames = PackedStringArray(["欧阳"])
	pool.given_names = PackedStringArray(["青禾"])
	_expect(pool.generate(rng) == "欧阳青禾", "复姓与完整名字正确组合")
	pool.given_names = []
	pool.characters = PackedStringArray(["青", "禾"])
	for i in range(20):
		var result: String = pool.generate(rng)
		_expect(result.begins_with("欧阳") and result.length() == 4 and result[2] in ["青", "禾"] and result[3] in ["青", "禾"], "空名字池抽取两个备用字")
	pool.surnames = []
	pool.characters = []
	_expect(not pool.generate(rng).is_empty(), "所有人类池留空时内置回退可生成名字")
	pool.mode = PoolResource.Mode.FULL_NAME
	pool.full_names = PackedStringArray(["碎牙", "枯灯"])
	var first: String = pool.generate(rng)
	var second: String = pool.generate(rng, {first: true})
	_expect(first != second and pool.generate(rng, {first: true, second: true}) in [first, second], "完整名称池避免重复，用尽后允许重名")
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world
	var region := NavigationRegion3D.new()
	var mesh := NavigationMesh.new()
	mesh.vertices = PackedVector3Array([Vector3(-30,0,-30),Vector3(-30,0,30),Vector3(30,0,30),Vector3(30,0,-30)])
	mesh.add_polygon(PackedInt32Array([0,1,2,3]))
	region.navigation_mesh = mesh
	world.add_child(region)
	var base: Node3D = load("res://Scene/building/base.tscn").instantiate()
	world.add_child(base)
	var seen: Dictionary = {}
	var resident: Node3D
	for i in range(30):
		resident = load("res://Scene/unit/villager.tscn").instantiate()
		world.add_child(resident)
		resident.set_physics_process(false)
		_expect(not resident.character_name.is_empty() and not seen.has(resident.character_name), "居民生成姓名且尽量不重复")
		seen[resident.character_name] = true
	var original: String = resident.character_name
	resident.set_combat_role(CombatRole.Type.SWORDSMAN)
	resident.set_combat_role(CombatRole.Type.ARCHER)
	resident.set_unit_data(resident.HUNTER_DATA)
	_expect(resident.character_name == original and resident.get_named_display_name().contains(original), "剑士、弓箭手和猎户转职保留原姓名")
	var enemy: EnemyBase = load("res://Scene/unit/enemy_base.tscn").instantiate()
	enemy.enemy_data = enemy.enemy_data.duplicate(true)
	enemy.enemy_data.fixed_name = "裂隙之主"
	world.add_child(enemy)
	enemy.set_process(false)
	enemy.set_physics_process(false)
	_expect(enemy.character_name == "裂隙之主" and enemy.get_named_display_name().contains(enemy.get_display_name()), "敌人固定名字与类型分别保留")
	var guard: EnemyBase = load("res://Scene/unit/enemy_base.tscn").instantiate()
	guard.set_script(load("res://Script/world/camp_guard.gd"))
	guard.enemy_data = load("res://data/enemies/raid/SlimeData.tres")
	world.add_child(guard)
	guard.set_process(false)
	guard.set_physics_process(false)
	_expect(not guard.character_name.is_empty(), "营地守卫继承敌人命名")
	var names = preload("res://Script/unit/character_names.gd")
	_expect(names.ENEMY_POOL.full_names.has(guard.character_name), "普通营地守卫使用全局怪物名称池")
	var boss: EnemyBase = load("res://Scene/unit/enemy_base.tscn").instantiate()
	boss.enemy_data = load("res://data/enemies/rift/DemonBossData.tres").duplicate(true)
	world.add_child(boss)
	boss.set_process(false)
	boss.set_physics_process(false)
	_expect(names.BOSS_POOL.full_names.has(boss.character_name), "首领自动使用全局BOSS名称池")
	var fixed_boss: EnemyBase = load("res://Scene/unit/enemy_base.tscn").instantiate()
	fixed_boss.enemy_data = boss.enemy_data.duplicate(true)
	fixed_boss.enemy_data.fixed_name = "固定首领测试"
	world.add_child(fixed_boss)
	fixed_boss.set_process(false)
	fixed_boss.set_physics_process(false)
	_expect(fixed_boss.character_name == "固定首领测试", "首领固定名字优先于全局随机名称")
	var manager := PopulationManager.new()
	world.add_child(manager)
	manager.set_process(false)
	var migrant: Node3D = load("res://Scene/unit/migrant.tscn").instantiate()
	world.add_child(migrant)
	migrant.set_physics_process(false)
	var migrant_name: String = migrant.character_name
	manager._on_migrant_arrived(migrant, base)
	var arrived: Node3D = get_nodes_in_group("villagers").back()
	_expect(arrived.character_name == migrant_name, "移民到达变成居民后保留姓名")
	world.queue_free()
	await process_frame
	quit(1 if failed else 0)
