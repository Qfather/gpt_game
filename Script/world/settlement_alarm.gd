class_name SettlementAlarm
extends Node

const CONNECTIONS: Script = preload("res://Script/building/wall_connections.gd")
const DIRECTIONS: Array[Vector2i] = [Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1), Vector2i(-1, 0), Vector2i(1, 0), Vector2i(-1, 1), Vector2i(0, 1), Vector2i(1, 1)]
var alarming: bool = false
var timer: float = 0.0
var safe_at_msec: int = 0
var defenses_dirty: bool = true
var defense_rebuild_count: int = 0
var protected_cells: Dictionary = {}
var breached_regions: Dictionary = {}
var alarm_label: Label

func _ready() -> void:
	add_to_group("settlement_alarm")
	var hud: Node = get_node_or_null("../../UI/HUD")
	if hud != null:
		alarm_label = Label.new()
		alarm_label.text = "瞭望塔警报：未受城墙保护的居民回家避险"
		alarm_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
		alarm_label.position = Vector2(-240, 105)
		alarm_label.size = Vector2(480, 30)
		alarm_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		alarm_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		alarm_label.add_theme_color_override("font_color", Color(1.0, 0.65, 0.15))
		alarm_label.hide()
		hud.add_child(alarm_label)

func _process(delta: float) -> void:
	timer += delta / maxf(Engine.time_scale, 0.001)
	if timer < 0.2: return
	timer = 0.0
	refresh_alarm()

func mark_defenses_dirty() -> void:
	defenses_dirty = true

func refresh_alarm() -> void:
	if defenses_dirty: _rebuild_defenses()
	breached_regions.clear()
	var enemies: Array[Vector3] = []
	for enemy: Node in get_tree().get_nodes_in_group("enemies"):
		if not enemy is Node3D or enemy.is_queued_for_deletion() or (enemy.has_method("is_dead") and enemy.is_dead()): continue
		if not enemy.has_method("get_faction"): continue
		if not EnemyData.are_factions_hostile(EnemyData.Faction.SETTLEMENT, enemy.get_faction()): continue
		enemies.append(enemy.global_position)
		var region: int = _region_at(enemy.global_position)
		if region > 0: breached_regions[region] = true
	var danger: bool = false
	for tower: Node in get_tree().get_nodes_in_group("watchtowers"):
		if not tower.is_staffed(): continue
		for point: Vector3 in enemies:
			if Vector2(point.x - tower.global_position.x, point.z - tower.global_position.z).length_squared() <= tower.work_radius * tower.work_radius:
				danger = true
				break
		if danger: break
	if danger:
		safe_at_msec = Time.get_ticks_msec() + 2000
		alarming = true
	elif Time.get_ticks_msec() >= safe_at_msec:
		alarming = false
	if is_instance_valid(alarm_label): alarm_label.visible = alarming

func _region_at(point: Vector3) -> int:
	var grid: BuildGrid = get_tree().get_first_node_in_group("build_grid") as BuildGrid
	return int(protected_cells.get(grid.world_to_grid(point), 0)) if grid != null else 0

func is_protected(point: Vector3) -> bool:
	if defenses_dirty: _rebuild_defenses()
	var region: int = _region_at(point)
	return region > 0 and not breached_regions.has(region)

func _linked(a: Vector2i, b: Vector2i, layout: Dictionary, grid: BuildGrid) -> bool:
	if absf(grid.get_ground_height(a) - grid.get_ground_height(b)) > 0.1: return false
	if layout[a] == layout[b]: return true
	for pair: Array in [[a, b], [b, a]]:
		var building: BuildingBase = layout[pair[0]]
		if not building.building_data.is_gate(): continue
		var area: Array[Vector2i] = grid._get_area_cells(building.build_grid_position, building.build_grid_size, building.build_grid_rotation_step)
		var axis := Vector2i.RIGHT if building.build_grid_rotation_step % 2 == 0 else Vector2i.DOWN
		if pair[1] != area[0] - axis and pair[1] != area[-1] + axis: return false
	return true

func _rebuild_defenses() -> void:
	defenses_dirty = false
	defense_rebuild_count += 1
	protected_cells.clear()
	var grid: BuildGrid = get_tree().get_first_node_in_group("build_grid") as BuildGrid
	if grid == null: return
	var layout: Dictionary = CONNECTIONS.cells(get_tree())
	if layout.is_empty(): return
	# 去掉未连接的端点，只有完整闭环才能作为屏障；高低差和城门轴向参与连接判定。
	var links: Dictionary = {}
	var queue: Array[Vector2i] = []
	for cell: Vector2i in layout:
		var neighbors: Array[Vector2i] = []
		for direction: Vector2i in CONNECTIONS.DIRECTIONS:
			var next: Vector2i = cell + direction
			if layout.has(next) and _linked(cell, next, layout, grid): neighbors.append(next)
		links[cell] = neighbors
		if neighbors.size() < 2: queue.append(cell)
	var index: int = 0
	while index < queue.size():
		var cell: Vector2i = queue[index]
		index += 1
		if not links.has(cell): continue
		for neighbor: Vector2i in links[cell]:
			if not links.has(neighbor): continue
			links[neighbor].erase(cell)
			if links[neighbor].size() < 2: queue.append(neighbor)
		links.erase(cell)
	if links.is_empty(): return
	var bounds := Rect2i(grid.grid_min, grid.grid_max - grid.grid_min + Vector2i.ONE)
	var outside: Dictionary = {}
	queue.clear()
	for y: int in range(grid.grid_min.y, grid.grid_max.y + 1):
		for x: int in range(grid.grid_min.x, grid.grid_max.x + 1):
			var cell := Vector2i(x, y)
			if x != grid.grid_min.x and x != grid.grid_max.x and y != grid.grid_min.y and y != grid.grid_max.y: continue
			if not links.has(cell):
				outside[cell] = true
				queue.append(cell)
	index = 0
	while index < queue.size():
		var cell: Vector2i = queue[index]
		index += 1
		for direction: Vector2i in DIRECTIONS:
			var next: Vector2i = cell + direction
			if not bounds.has_point(next) or links.has(next) or outside.has(next): continue
			outside[next] = true
			queue.append(next)
	var region: int = 0
	for y: int in range(grid.grid_min.y, grid.grid_max.y + 1):
		for x: int in range(grid.grid_min.x, grid.grid_max.x + 1):
			var start := Vector2i(x, y)
			if links.has(start) or outside.has(start) or protected_cells.has(start): continue
			region += 1
			queue.assign([start])
			protected_cells[start] = region
			index = 0
			while index < queue.size():
				var cell: Vector2i = queue[index]
				index += 1
				for direction: Vector2i in DIRECTIONS:
					var next: Vector2i = cell + direction
					if not bounds.has_point(next) or links.has(next) or outside.has(next) or protected_cells.has(next): continue
					protected_cells[next] = region
					queue.append(next)
