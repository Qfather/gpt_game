extends SceneTree

class Resident extends "res://Script/unit/game/villager.gd":
	var searches: int = 0
	func _find_nearest_hostile(search_range: float = -1.0) -> Node3D:
		searches += 1
		return super._find_nearest_hostile(search_range)

class Intruder extends Node3D:
	var dead: bool = false
	var faction: int = EnemyData.Faction.RAID
	func get_faction() -> int: return faction
	func is_dead() -> bool: return dead
	func take_damage(_amount: float, _source: Node = null) -> float: return 0.0

var failed: bool = false
var main: Node
var worker: Node
var resident: Node
var tower: Watchtower

func _initialize() -> void: call_deferred("_run")
func _expect(value: bool, message: String) -> void:
	if not value:
		failed = true
		push_error(message)

func _unit(point: Vector3) -> Node:
	var unit: Node = load("res://Scene/unit/villager.tscn").instantiate()
	unit.set_script(Resident)
	main.add_child(unit)
	unit.global_position = point
	unit.hunger = 0.0
	unit.fatigue = 0.0
	return unit

func _wait_staffed() -> void:
	for frame: int in range(900):
		if tower.is_staffed(): return
		await physics_frame
	_expect(false, "居民没有实际走到瞭望塔并登上平台")

func _run() -> void:
	root.size = Vector2i(1280, 720)
	main = load("res://Scene/main.tscn").instantiate()
	main.level_preset = main.level_preset.duplicate(true)
	main.level_preset.layout_seed = 418
	main.level_preset.events.clear()
	main.level_preset.camp_config.enabled = false
	root.add_child(main)
	current_scene = main
	for frame: int in range(90): await physics_frame
	main.get_node("Systems/PopulationManager").set_process(false)
	main.get_node("Systems/EncounterDirector").set_process(false)
	for unit: Node in get_nodes_in_group("villagers"): unit.queue_free()
	await process_frame
	var base: Node3D = get_first_node_in_group("bases")
	var data: BuildingData = load("res://data/buildings/WatchtowerData.tres")
	tower = data.building_scene.instantiate()
	tower.set_building_data(data)
	main.add_child(tower)
	tower.global_position = base.global_position + Vector3(4, 0, 3)
	main.register_building(tower)
	var house: House = load("res://Scene/building/game/house.tscn").instantiate()
	house.set_building_data(load("res://data/buildings/HouseData.tres"))
	main.add_child(house)
	house.global_position = base.global_position + Vector3(-4, 0, 3)
	main.register_building(house)
	worker = _unit(base.global_position + Vector3(2, 0, 4))
	worker.home_building = base
	resident = _unit(base.global_position + Vector3(-2, 0, 5))
	resident.home_building = house
	resident.set_physics_process(false)
	var alarm: SettlementAlarm = get_first_node_in_group("settlement_alarm")
	alarm.set_process(false)
	var enemy := Intruder.new()
	main.add_child(enemy)
	enemy.add_to_group("enemies")
	enemy.global_position = tower.global_position + Vector3(3, 0, 0)
	alarm.refresh_alarm()
	_expect(not alarm.alarming, "无人瞭望塔也发出了警报")
	resident._process_civilian_retreat(0.016)
	_expect(resident.state != resident.State.RETREAT_TO_BASE, "没有有效瞭望塔、未被攻击的普通居民自行避难")
	_expect(resident.searches == 0, "普通居民仍主动扫描敌人")
	_expect(tower.add_worker(worker), "瞭望塔不能安排居民值班")
	_expect(not tower.is_staffed(), "工人尚未登塔就已经生效")
	await _wait_staffed()
	_expect(worker.visible and worker.collision_layer == 0, "登塔居民没有保持可见，或仍在碰撞阻塞路径")
	_expect(worker.global_position.distance_to(tower.get_interior_position()) < 0.1, "值班居民不在塔上平台")
	var old_transform: Transform3D = tower.global_transform
	tower.global_position += Vector3(1, 0, 0)
	worker.on_building_relocated(tower, old_transform)
	_expect(worker.global_position.distance_to(tower.get_interior_position()) < 0.1 and tower.is_staffed(), "搬迁瞭望塔后居民没有留在新平台")
	tower.global_transform = old_transform
	worker.on_building_relocated(tower, old_transform)
	var hud: Node = main.get_node("UI/HUD")
	_expect(hud.menu_buildings.has(data) and data.category == BuildingData.Category.STRATEGY, "瞭望塔没有进入战略建筑菜单")
	tower.building_clicked.emit(tower)
	_expect(main.selected_building_range.visible and is_equal_approx(main.selected_building_range.mesh.outer_radius, 20.0), "点击瞭望塔未显示20米范围")
	alarm.refresh_alarm()
	_expect(alarm.alarming, "有人值班时范围内敌人没有触发警报")
	if OS.get_cmdline_user_args().has("--visual"):
		var camera: GameCameraController = root.get_camera_3d()
		camera.focus_on_position(tower.global_position + Vector3(0, 2.0, 0))
		for distance: float in [11.0, 38.0]:
			camera.orbit_distance = distance
			for frame: int in range(20): await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://.godot/watchtower_%d.png" % int(distance))
	var grid: BuildGrid = get_first_node_in_group("build_grid")
	alarm.protected_cells[grid.world_to_grid(resident.global_position)] = 1
	resident._process_civilian_retreat(0.016)
	_expect(resident.state != resident.State.RETREAT_TO_BASE, "受城墙保护的居民仍响应避险")
	alarm.protected_cells.clear()
	resident.set_combat_role(CombatRole.Type.SWORDSMAN)
	_expect(not resident._process_civilian_retreat(0.016), "战斗单位响应普通居民避险")
	resident.set_combat_role(CombatRole.Type.NONE)
	resident._process_civilian_retreat(0.016)
	_expect(resident.shelter_target == house, "警报后居民没有固定返回自己的住所")
	resident.set_physics_process(true)
	for frame: int in range(900):
		if resident.state == resident.State.SHELTERED and not resident.passing_door: break
		await physics_frame
	_expect(resident.state == resident.State.SHELTERED and resident.indoor_building == house and not resident.visible, "居民没有实际回到自己的房屋内避险")
	_expect(resident.searches == 0, "避险途中或室内仍反复搜敌")
	enemy.global_position = tower.global_position + Vector3(20.01, 0, 0)
	alarm.safe_at_msec = 0
	alarm.refresh_alarm()
	_expect(not alarm.alarming, "20米之外的敌人触发警报")
	enemy.global_position = tower.global_position + Vector3(20, 10, 0)
	alarm.refresh_alarm()
	_expect(alarm.alarming, "20米水平边界没有触发警报")
	enemy.faction = EnemyData.Faction.SETTLEMENT
	alarm.safe_at_msec = 0
	alarm.refresh_alarm()
	_expect(not alarm.alarming, "友方触发了敌情警报")
	enemy.faction = EnemyData.Faction.RAID
	enemy.dead = true
	alarm.refresh_alarm()
	_expect(not alarm.alarming, "死亡敌人仍触发警报")
	for frame: int in range(180): await physics_frame
	_expect(resident.state != resident.State.SHELTERED, "警报解除后居民没有离开住所")
	resident.set_physics_process(false)
	resident.take_damage(5.0, enemy)
	_expect(resident.state == resident.State.RETREAT_TO_BASE and resident.shelter_target == house, "没有警报时受到攻击没有回家避险")
	worker.hunger = 90.0
	Engine.time_scale = 3.0
	worker.evaluate_needs()
	_expect(not tower.is_staffed(), "居民下塔进食时仍有警戒效果")
	for frame: int in range(900):
		if tower.is_staffed(): break
		await physics_frame
	_expect(tower.is_staffed(), "进食后居民没有重新登塔值班")
	if not tower.is_staffed(): print("值班回岗状态：", worker.State.keys()[worker.state], " hunger=", worker.hunger, " position=", worker.global_position, " target=", worker.navigation_agent.target_position, " indoor=", worker.indoor_building)
	Engine.time_scale = 1.0
	tower.remove_worker(worker)
	for frame: int in range(240): await physics_frame
	_expect(not tower.is_staffed() and worker.indoor_building != tower and worker.job == worker.Job.NONE, "撤下值班居民后没有下塔或释放岗位")
	tower.add_worker(worker)
	await _wait_staffed()
	worker.abandon_current_work()
	for frame: int in range(240): await physics_frame
	_expect(not tower.is_staffed() and worker.indoor_building == null and worker.workplace == null and worker.visible, "取消工作后值班居民没有实际下塔")
	tower.add_worker(worker)
	await _wait_staffed()
	tower.take_damage(100000.0)
	for frame: int in range(240): await physics_frame
	_expect(worker.workplace == null and worker.indoor_building == null and worker.visible, "塔被毁后值班居民没有撤离并恢复活动")
	print("瞭望塔报警测试", "失败" if failed else "通过", "：战略菜单、真实登塔、选中范围、20米边界、无塔仅受击避险、回家、无普通搜敌、解除警报、进食回岗、撤岗")
	main.queue_free()
	await process_frame
	quit(1 if failed else 0)
