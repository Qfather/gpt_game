extends SceneTree

class Defense extends BuildingBase:
	var broken: bool = false
	func _ready() -> void: add_to_group("buildings")
	func get_health() -> float: return 0.0 if broken else 100.0
	func is_destroyed() -> bool: return broken

class Intruder extends Node3D:
	func get_faction() -> int: return EnemyData.Faction.RAID
	func is_dead() -> bool: return false

var failed: bool = false

func _initialize() -> void: call_deferred("_run")
func _expect(value: bool, message: String) -> void:
	if not value:
		failed = true
		push_error(message)

func _run() -> void:
	var grid := BuildGrid.new()
	grid.grid_min = Vector2i(-8, -8)
	grid.grid_max = Vector2i(8, 8)
	root.add_child(grid)
	var alarm := SettlementAlarm.new()
	root.add_child(alarm)
	alarm.set_process(false)
	var walls: Array[Defense] = []
	for y: int in range(-3, 4):
		for x: int in range(-3, 4):
			if absi(x) != 3 and absi(y) != 3: continue
			if y == -3 and x >= -2 and x <= 1: continue
			var wall := Defense.new()
			wall.building_data = load("res://data/buildings/WoodWallData.tres")
			root.add_child(wall)
			wall.set_build_grid_occupancy(Vector2i(x, y), Vector2i.ONE, 0)
			walls.append(wall)
	var gate := Defense.new()
	gate.building_data = load("res://data/buildings/WoodGateData.tres")
	root.add_child(gate)
	gate.set_build_grid_occupancy(Vector2i(-2, -3), Vector2i(4, 1), 0)
	var inside: Vector3 = grid.grid_to_world(Vector2i.ZERO)
	_expect(alarm.is_protected(inside), "城墙与城门闭环没有形成保护区域")
	_expect(not alarm.is_protected(grid.grid_to_world(Vector2i(6, 0))), "墙外误判为受保护")
	var rebuilds: int = alarm.defense_rebuild_count
	for index: int in range(100): alarm.is_protected(inside)
	_expect(alarm.defense_rebuild_count == rebuilds, "查询居民保护状态重复重算城墙区域")
	walls[0].broken = true
	alarm.mark_defenses_dirty()
	_expect(not alarm.is_protected(inside), "城墙缺口没有解除保护")
	walls[0].broken = false
	alarm.mark_defenses_dirty()
	_expect(alarm.is_protected(inside), "补回城墙后没有恢复保护")
	gate.build_grid_rotation_step = 1
	alarm.mark_defenses_dirty()
	_expect(not alarm.is_protected(inside), "错误朝向的城门误判为完整连接")
	gate.build_grid_rotation_step = 0
	grid.ground_height_rule = func(cell: Vector2i) -> float: return 1.0 if cell == walls[0].build_grid_position else 0.0
	alarm.mark_defenses_dirty()
	_expect(not alarm.is_protected(inside), "高低差断开的墙误判为闭环")
	grid.ground_height_rule = Callable()
	alarm.mark_defenses_dirty()
	var enemy := Intruder.new()
	root.add_child(enemy)
	enemy.add_to_group("enemies")
	enemy.global_position = inside
	alarm.refresh_alarm()
	_expect(not alarm.is_protected(inside), "敌人进入墙内后仍认为安全")
	enemy.position = Vector3(7, 0, 7)
	alarm.refresh_alarm()
	_expect(alarm.is_protected(inside), "敌人离开保护区后没有恢复保护")
	print("城墙保护区域测试", "失败" if failed else "通过", "：闭环、城门轴向、缺口、高低差、敌人入侵、缓存复用")
	for node: Node in root.get_children(): node.queue_free()
	await process_frame
	quit(1 if failed else 0)
