extends SceneTree

class Resident extends "res://Script/unit/game/villager.gd":
	var searches: int = 0
	func _find_nearest_hostile(search_range: float = -1.0) -> Node3D:
		searches += 1
		return super._find_nearest_hostile(search_range)

var failed: bool = false
func _initialize() -> void: call_deferred("_run")
func _expect(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		push_error(message)

func _run() -> void:
	root.size = Vector2i(1280, 720)
	var main: Node = load("res://Scene/main.tscn").instantiate()
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
	var alarm: SettlementAlarm = get_first_node_in_group("settlement_alarm")
	alarm.set_process(false)
	var data: BuildingData = load("res://data/buildings/ArrowTowerData.tres")
	var tower: Barracks = data.building_scene.instantiate()
	tower.set_building_data(data)
	main.add_child(tower)
	tower.global_position = base.global_position + Vector3(4, 0, 3)
	main.register_building(tower)
	tower.set_process(false)
	tower.add_food(&"grain", 20)
	var house: House = load("res://Scene/building/game/house.tscn").instantiate()
	house.set_building_data(load("res://data/buildings/HouseData.tres"))
	main.add_child(house)
	house.global_position = base.global_position + Vector3(-4, 0, 3)
	main.register_building(house)
	var resident: Node = load("res://Scene/unit/villager.tscn").instantiate()
	resident.set_script(Resident)
	main.add_child(resident)
	resident.global_position = base.global_position + Vector3(-2, 0, 5)
	resident.home_building = house
	resident.set_physics_process(false)
	var archer: Node = load("res://Scene/unit/villager.tscn").instantiate()
	main.add_child(archer)
	archer.set_physics_process(false)
	archer.set_combat_role(CombatRole.Type.ARCHER)
	archer.global_position = base.global_position + Vector3(2, 0, 4)
	var enemy: EnemyBase = load("res://Scene/unit/enemy_base.tscn").instantiate()
	main.add_child(enemy)
	enemy.set_process(false)
	enemy.set_physics_process(false)
	enemy.global_position = tower.global_position + Vector3(18, 0, 0)
	alarm.refresh_alarm()
	_expect(not alarm.alarming, "空箭塔不应报警")
	resident._process_civilian_retreat(0.016)
	_expect(resident.state != resident.State.RETREAT_TO_BASE and resident.searches == 0, "无有效塔时普通居民不应主动搜敌避险")
	_expect(archer.try_assign_to_barracks(tower) and not tower.is_staffed(), "预约登塔不能提前启用警戒")
	for frame: int in range(900):
		if archer.garrisoned_in == tower: break
		archer.move_to_barracks()
		await physics_frame
	_expect(tower.is_staffed() and archer.visible and archer.global_position.distance_to(tower.get_garrison_position(archer)) < 0.1, "弓箭手没有实际登塔启用警戒")
	alarm.refresh_alarm()
	_expect(alarm.alarming, "有人箭塔没有发现20米内敌人")
	var health: float = enemy.current_health
	archer._process_tower_combat(1.0)
	for frame: int in range(30): await physics_frame
	_expect(enemy.current_health == health, "警戒范围内、射程外不应射击")
	resident._process_civilian_retreat(0.016)
	_expect(resident.shelter_target == house, "警报没有让居民回自己住所")
	resident.set_physics_process(true)
	for frame: int in range(900):
		if resident.state == resident.State.SHELTERED and not resident.passing_door: break
		await physics_frame
	_expect(resident.state == resident.State.SHELTERED and not resident.visible and resident.searches == 0, "居民没有实际进屋或仍反复搜敌")
	tower.building_clicked.emit(tower)
	_expect(main.selected_building_range.visible and is_equal_approx(main.selected_building_range.mesh.outer_radius, 20.0), "选中箭塔未显示20米警戒范围")
	for entry: BuildingData in main.get_node("UI/HUD").menu_buildings:
		_expect(entry.id != &"watchtower", "独立瞭望塔仍出现在菜单")
	if OS.get_cmdline_user_args().has("--visual"):
		var camera: GameCameraController = root.get_camera_3d()
		camera.focus_on_position(tower.global_position + Vector3.UP * 2)
		camera.orbit_distance = 28
		for frame: int in range(20): await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/arrow_tower_alarm.png")
	enemy.global_position = tower.global_position + Vector3(3, 0, 0)
	archer.combat_attack_cooldown = 0
	archer._process_tower_combat(1.0)
	for frame: int in range(90):
		if enemy.current_health < health: break
		await physics_frame
	_expect(enemy.current_health < health, "敌人进入原有射程后箭塔未射击命中")
	archer.state = archer.State.GARRISON_EATING
	alarm.safe_at_msec = 0
	alarm.refresh_alarm()
	_expect(not tower.is_staffed() and not alarm.alarming, "进食离岗时仍警戒")
	archer.state = archer.State.GARRISONED
	enemy.global_position = tower.global_position + Vector3(20.01, 0, 0)
	alarm.safe_at_msec = 0
	alarm.refresh_alarm()
	_expect(not alarm.alarming, "20米外仍报警")
	enemy.global_position = tower.global_position + Vector3(20, 10, 0)
	alarm.refresh_alarm()
	_expect(alarm.alarming, "水平20米边界未报警")
	for id: String in ["WallTowerData", "WoodWallTowerData"]:
		var wall_data: BuildingData = load("res://data/buildings/%s.tres" % id)
		var wall_tower: Barracks = wall_data.building_scene.instantiate()
		wall_tower.set_building_data(wall_data)
		main.add_child(wall_tower)
		wall_tower.set_process(false)
		archer.leave_garrison()
		archer.stun_remaining = 0.0
		if is_instance_valid(archer.garrison_target): archer.garrison_target.remove_unit_from_rosters(archer)
		_expect(wall_tower.register_garrison(archer), "弓箭手无法预约墙上箭塔")
		archer.garrison_target = wall_tower
		wall_tower.enter_garrison(archer)
		_expect(wall_tower.is_in_group("alarm_towers") and wall_tower.is_staffed() and wall_tower.alarm_radius == 20, "墙上箭塔没有继承警戒")
		wall_tower.take_damage(100000)
		_expect(not wall_tower.is_staffed(), "摧毁塔后仍有警戒")
		await process_frame
	main.queue_free()
	await process_frame
	print("箭塔警戒测试", "失败" if failed else "通过", "：真实登塔、20米、射程内命中、居民回家、无普通搜敌、进食离岗、墙塔继承、删除独立瞭望塔")
	quit(1 if failed else 0)
