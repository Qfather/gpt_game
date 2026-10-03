extends SceneTree

class TestMap extends MapGenerateRuntime:
	func _ready() -> void:
		add_to_group("map_generate_runtime")

var failed := false

func _init() -> void:
	call_deferred("_run")

func _expect(value: bool, text: String) -> void:
	print("[", "通过" if value else "失败", "] ", text)
	if not value:
		failed = true
		push_error(text)

func _run() -> void:
	Engine.time_scale = 4.0
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world
	var region := NavigationRegion3D.new()
	region.name = "NavigationRegion3D"
	world.add_child(region)
	var runtime := TestMap.new()
	world.add_child(runtime)
	runtime._navigation_faces = PackedVector3Array([Vector3(-25,0,-25),Vector3(25,0,-25),Vector3(-25,0,25),Vector3(25,0,-25),Vector3(25,0,25),Vector3(-25,0,25)])
	var data := TreasureCampData.new()
	data.guard_leash_radius = 10.0
	data.guard_health_regen = 1.5
	var enemy_data: EnemyData = load("res://data/enemies/raid/SlimeData.tres").duplicate(true)
	enemy_data.max_health = 100.0
	enemy_data.detection_range = 20.0
	enemy_data.move_speed = 4.0
	var camp: TreasureCamp = load("res://Scene/world/treasure_camp.tscn").instantiate()
	var homes: Array[Vector3] = [Vector3(2,0,0)]
	camp.configure_camp(data, {"guards": [enemy_data], "rewards": {&"wood": 3}}, homes, 0.0)
	world.add_child(camp)
	camp.set_process(false)
	var guard: EnemyBase = camp.guards[0]
	guard.set_process(false)
	guard.set_physics_process(false)
	var worker: Node3D = load("res://Scene/unit/villager.tscn").instantiate()
	world.add_child(worker)
	worker.set_process(false)
	worker.set_physics_process(false)
	worker.global_position = Vector3(6,0,0)
	var mesh := runtime._new_navigation_mesh()
	NavigationServer3D.bake_from_source_geometry_data(mesh, runtime._navigation_geometry())
	region.navigation_mesh = mesh
	for i in range(10): await physics_frame
	guard.update_targeting()
	_expect(guard.target == worker and not worker.has_combat_role(), "靠近营地的普通居民触发守卫警戒")
	worker.assign_job(worker.Job.HUNTER, null)
	guard.update_targeting()
	_expect(guard.target == worker, "猎户也能触发守卫警戒")
	var start: Vector3 = guard.global_position
	for i in range(15):
		guard.update_targeting()
		guard._physics_process(1.0 / 15.0)
		await physics_frame
	_expect(guard.global_position.distance_to(start) > 0.5, "守卫沿导航主动接近玩家单位")
	worker.global_position = guard.global_position + Vector3(0.8,0,0)
	var player_health: float = worker.get_health()
	guard.attack_cooldown = 0.0
	guard.update_targeting()
	guard._physics_process(0.1)
	_expect(worker.get_health() < player_health, "守卫实际攻击靠近的玩家单位")
	guard.take_damage(20.0)
	var wounded: float = guard.current_health
	guard._physics_process(1.0)
	_expect(guard.current_health == wounded, "战斗中不回血")
	guard.attack_range = 4.0
	guard.global_position = Vector3(8,0,0)
	worker.global_position = Vector3(11,0,0)
	guard.update_targeting()
	_expect(guard.target == null and guard.returning_to_camp, "目标超出营地半径后立即放弃追击并返营")
	worker.global_position = Vector3(7,0,4)
	guard.update_targeting()
	_expect(guard.target == null, "返营途中不被范围内目标反复拉走")
	guard._physics_process(1.0)
	_expect(guard.current_health == wounded, "返营途中不回血")
	for i in range(160):
		guard.update_targeting()
		guard._physics_process(1.0 / 15.0)
		if not guard.returning_to_camp: break
		await physics_frame
	_expect(not guard.returning_to_camp and guard._flat_distance(guard.global_position, guard.home_position) <= 0.8, "守卫实际返回原守卫位置")
	worker.global_position = Vector3(15,0,0)
	guard.update_targeting()
	var before_heal: float = guard.current_health
	guard._physics_process(2.0)
	_expect(is_equal_approx(guard.current_health - before_heal, 3.0), "回营脱战后按每秒1.5点缓慢回血")
	_expect(is_equal_approx(guard.health_component.current_health, guard.current_health), "回血同步健康组件和面板数据")
	camp.guard_health_regen = 0.0
	before_heal = guard.current_health
	guard._physics_process(5.0)
	_expect(guard.current_health == before_heal, "回血配置为0可关闭")
	camp.guard_health_regen = 1.5
	guard._physics_process(1000.0)
	_expect(guard.current_health == guard.max_health, "回血不超过生命上限")
	guard.global_position = Vector3(11,0,0)
	worker.global_position = Vector3(8,0,0)
	guard.update_targeting()
	_expect(guard.target == null and guard.returning_to_camp, "守卫自身越界时也强制返营")
	data.guard_leash_radius = 20.0
	data.guard_health_regen = 8.0
	_expect(camp.guard_leash_radius == 10.0 and camp.guard_health_regen == 1.5, "生成时复制配置，后续模板变化不改变已生成营地")
	worker.global_position = Vector3(20,0,0)
	guard.global_position = guard.home_position
	guard.returning_to_camp = false
	guard.take_damage(1000.0)
	guard._physics_process(100.0)
	_expect(guard.is_dead() and guard.current_health == 0.0, "死亡守卫不会回血复活")
	world.queue_free()
	await process_frame
	print("营地守卫警戒、边界返营与回血测试", "失败" if failed else "通过")
	quit(1 if failed else 0)
