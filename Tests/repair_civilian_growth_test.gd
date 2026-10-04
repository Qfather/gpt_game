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
	mesh.vertices = PackedVector3Array([Vector3(-40,0,-40),Vector3(-40,0,40),Vector3(40,0,40),Vector3(40,0,-40)])
	mesh.add_polygon(PackedInt32Array([0,1,2,3]))
	region.navigation_mesh = mesh
	world.add_child(region)
	var base: BuildingBase = load("res://Scene/building/base.tscn").instantiate()
	world.add_child(base)
	for id: String in ["Wall", "Gate", "House"]:
		var building: BuildingBase = load("res://Scene/building/game/%s.tscn" % id.to_lower()).instantiate()
		building.building_data = load("res://data/buildings/%sData.tres" % id)
		world.add_child(building)
		building.position = Vector3(20,0,20)
		building.take_damage(51)
		var damaged: float = building.get_health()
		building.repair(25)
		_expect(is_equal_approx(building.get_health(), damaged + 25), id + " 维修增加实际显示的血量")
		building.queue_free()
	var resident: CharacterBody3D = load("res://Scene/unit/villager.tscn").instantiate()
	world.add_child(resident)
	resident.set_physics_process(false)
	resident.position = Vector3(8,0,0)
	for frame: int in range(10):
		await physics_frame
	var enemy: EnemyBase = load("res://Scene/unit/enemy_base.tscn").instantiate()
	enemy.enemy_data = load("res://data/enemies/raid/SlimeData.tres").duplicate(true)
	world.add_child(enemy)
	enemy.set_process(false)
	enemy.set_physics_process(false)
	enemy.position = Vector3(9,0.65,0)
	enemy.raid_active = true
	for objective: int in [EnemyData.RaidObjective.DESTROY_BUILDINGS, EnemyData.RaidObjective.STEAL_RESOURCES]:
		enemy.enemy_data.raid_objective = objective
		enemy.update_targeting()
		_expect(enemy.target == resident, "袭扰目标 %s 仍攻击附近居民" % objective)
	var before: float = resident.get_health()
	resident.carried_resource_id = &"wood"
	resident.carried_amount = 2.0
	enemy.attack_cooldown = 0.0
	enemy._physics_process(0.1)
	_expect(resident.get_health() < before and resident.carried_amount == 2.0, "抢资源的敌人遇到居民会造成伤害，而非只偷取携带物")
	_expect(resident._process_civilian_retreat(0.016) and resident.state == resident.State.RETREAT_TO_BASE, "居民发现危险后主动撤退，不必先受伤")
	var tree: ResourceBase = load("res://Scene/resource/tree.tscn").instantiate()
	tree.growth_duration = 1.0
	world.add_child(tree)
	tree.set_process(false)
	tree.position = Vector3(8,0,0)
	for frame: int in range(10):
		await physics_frame
	var probe := CharacterBody3D.new()
	var shape := CollisionShape3D.new()
	shape.shape = SphereShape3D.new()
	probe.add_child(shape)
	world.add_child(probe)
	probe.collision_mask = 1
	probe.position = Vector3(6,0.5,0)
	await physics_frame
	_expect(probe.move_and_collide(Vector3(4,0,0)) == null, "未成熟资源不会阻挡角色穿过")
	tree._process(1.0)
	_expect((tree.get_node("StaticBody3D").collision_layer & 1) == 0, "成熟区域内还有居民时不突然恢复阻挡")
	resident.position = Vector3(30,0,0)
	enemy.position = Vector3(30,0,5)
	probe.position = Vector3(30,0,10)
	await physics_frame
	tree._process(0.6)
	_expect((tree.get_node("StaticBody3D").collision_layer & 1) != 0, "居民离开后成熟资源恢复阻挡")
	world.queue_free()
	await process_frame
	quit(1 if failed else 0)
