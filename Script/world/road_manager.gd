extends Node3D

signal roads_changed

enum Kind { DIRT = 1, STONE = 2 }
const CHUNK_SIZE: int = 8
const DIRECTIONS: Array[Vector2i] = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
const SHAPE_MASKS: Array[int] = [0, 1, 5, 3, 11, 15]
const ROAD_DATA: Array[BuildingData] = [null, preload("res://data/buildings/DirtRoadData.tres"), preload("res://data/buildings/StoneRoadData.tres")]

class RoadGraph extends AStar3D:
	func _estimate_cost(from_id: int, to_id: int) -> float:
		return get_point_position(from_id).distance_to(get_point_position(to_id)) * 0.35

var grid: BuildGrid
var cells: Dictionary = {}
var placement_order: Array[Vector2i] = []
var revision: int = 0
var chunks: Dictionary = {}
var shape_materials: Dictionary = {}
var graph := RoadGraph.new()
var graph_ids: Dictionary = {}
var graph_inputs: Array = []
var query_frame: int = -1
var queries_this_frame: int = 0
var route_queries: int = 0
var pending: Dictionary = {}
var dispatch_timer: float = 0.0
var stroke_graph := AStar2D.new()
var stroke_ids: Dictionary = {}
var stroke_graph_inputs: Array = []
var stroke_graph_builds: int = 0
var stroke_resource_inputs: Array = []
var stroke_resource_cells: Dictionary = {}
var stroke_resource_footprints: Dictionary = {}
var stroke_blocked: Dictionary = {}
var construction_obstacle_frame: int = -1


func _process(delta: float) -> void:
	if pending.is_empty(): return
	dispatch_timer += delta
	if dispatch_timer < 0.5: return
	dispatch_timer = 0.0
	var manager: TaskManager = get_tree().get_first_node_in_group("task_manager") as TaskManager
	if manager == null: return
	for cell: Vector2i in pending:
		var task: GameTask = pending[cell]
		if task.state in [GameTask.State.CLAIMED, GameTask.State.IN_PROGRESS] and (not is_instance_valid(task.assigned_worker) or task.assigned_worker.is_dead()):
			manager.release_task(task)
		if task.state == GameTask.State.AVAILABLE: manager.request_dispatch()

# 地形只建一次四向图，资源占地变化时才重新计算碰撞覆盖格。
func refresh_stroke_obstacles() -> void:
	construction_obstacle_frame = Engine.get_physics_frames()
	var inputs: Array = []
	var resources: Array[ResourceBase] = []
	for node: Node in get_tree().get_nodes_in_group("resources"):
		var resource: ResourceBase = node as ResourceBase
		if resource == null or resource.is_queued_for_deletion(): continue
		var bounds: AABB = resource.get_build_obstacle_bounds(true)
		if bounds.size == Vector3.ZERO: continue
		resources.append(resource)
		inputs.append([resource.get_instance_id(), bounds, resource.global_transform])
	if inputs == stroke_resource_inputs: return
	stroke_resource_inputs = inputs
	stroke_resource_cells.clear()
	var footprints: Dictionary = {}
	for resource: ResourceBase in resources:
		var bounds: AABB = resource.get_build_obstacle_bounds(true)
		var id: int = resource.get_instance_id()
		var snapshot: Array = [bounds, resource.global_transform]
		if stroke_resource_footprints.has(id) and stroke_resource_footprints[id][0] == snapshot:
			footprints[id] = stroke_resource_footprints[id]
			stroke_resource_cells.merge(footprints[id][1])
			continue
		var covered: Dictionary = {}
		var minimum: Vector2i = grid.world_to_grid(bounds.position)
		var maximum: Vector2i = grid.world_to_grid(bounds.end)
		for y: int in range(minimum.y, maximum.y + 1):
			for x: int in range(minimum.x, maximum.x + 1):
				var cell := Vector2i(x, y)
				var center: Vector3 = grid.grid_to_world(cell)
				var box := AABB(Vector3(center.x - grid.cell_size * 0.5, bounds.position.y, center.z - grid.cell_size * 0.5), Vector3(grid.cell_size, bounds.size.y, grid.cell_size))
				if resource.overlaps_clearance_box(box, Transform3D.IDENTITY, true): covered[cell] = true
		footprints[id] = [snapshot, covered]
		stroke_resource_cells.merge(covered)
	stroke_resource_footprints = footprints

func _refresh_stroke_graph(ignored_cells: Array[Vector2i] = [], ignore_resources: bool = false) -> void:
	var inputs: Array = [grid.grid_min, grid.grid_max, grid.cell_size, grid.global_position, grid.buildability_rule, grid.ground_height_rule]
	if inputs != stroke_graph_inputs:
		stroke_graph_inputs = inputs
		stroke_graph.clear()
		stroke_ids.clear()
		stroke_blocked.clear()
		stroke_resource_inputs.clear()
		stroke_resource_cells.clear()
		stroke_resource_footprints.clear()
		stroke_graph_builds += 1
		for y: int in range(grid.grid_min.y, grid.grid_max.y + 1):
			for x: int in range(grid.grid_min.x, grid.grid_max.x + 1):
				var cell := Vector2i(x, y)
				if not grid.is_cell_buildable(cell, true): continue
				var id: int = stroke_ids.size()
				stroke_ids[cell] = id
				stroke_graph.add_point(id, Vector2(cell))
		for cell: Vector2i in stroke_ids:
			for offset: Vector2i in [Vector2i.RIGHT, Vector2i.DOWN]:
				var neighbor: Vector2i = cell + offset
				if stroke_ids.has(neighbor) and absf(grid.get_ground_height(cell) - grid.get_ground_height(neighbor)) <= 0.1:
					stroke_graph.connect_points(stroke_ids[cell], stroke_ids[neighbor])
	if not ignore_resources: refresh_stroke_obstacles()
	var blocked: Dictionary = {} if ignore_resources else stroke_resource_cells.duplicate()
	blocked.merge(grid.occupied_cells, true)
	for cell: Vector2i in ignored_cells:
		if ignore_resources or not stroke_resource_cells.has(cell): blocked.erase(cell)
	for cell: Vector2i in stroke_blocked:
		if not blocked.has(cell) and stroke_ids.has(cell): stroke_graph.set_point_disabled(stroke_ids[cell], false)
	for cell: Vector2i in blocked:
		if not stroke_blocked.has(cell) and stroke_ids.has(cell): stroke_graph.set_point_disabled(stroke_ids[cell], true)
	stroke_blocked = blocked

# 不返回部分路径：两端无法连通时交给预览显示整条红色。
func plan_stroke(from: Vector2i, to: Vector2i, ignored_cells: Array[Vector2i] = [], ignore_resources: bool = false) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	_refresh_stroke_graph(ignored_cells, ignore_resources)
	if not stroke_ids.has(from) or not stroke_ids.has(to) or stroke_blocked.has(from) or stroke_blocked.has(to): return result
	for point: Vector2 in stroke_graph.get_point_path(stroke_ids[from], stroke_ids[to]): result.append(Vector2i(point))
	return result

func _ready() -> void:
	add_to_group("road_manager")
	if grid == null: grid = get_node("../Systems/BuildGrid")

func can_place(cell: Vector2i) -> bool:
	refresh_stroke_obstacles()
	return can_work_cell(cell)

# 同一物理帧的全部施工居民共用资源占地；建筑占地仍逐次检查。
func can_work_cell(cell: Vector2i) -> bool:
	if construction_obstacle_frame != Engine.get_physics_frames(): refresh_stroke_obstacles()
	return not stroke_resource_cells.has(cell) and grid.is_area_free(cell, Vector2i.ONE, 0, true, true)

func _base() -> Node:
	return get_tree().get_first_node_in_group("bases")

func available_stone() -> int:
	var base: Node = _base()
	return floori(base.get_resource(&"stone")) if is_instance_valid(base) else 0

func affordable_count(kind: int) -> int:
	var count: int = 2147483647
	var base: Node = _base()
	for resource_id: StringName in ROAD_DATA[kind].construction_cost:
		var amount: float = ROAD_DATA[kind].construction_cost[resource_id]
		if amount > 0:
			count = mini(count, floori(base.get_resource(resource_id) / amount) if is_instance_valid(base) else 0)
	return count

# 材料在标记时从据点扣除，待建状态只存数据，不生成逐格工地节点。
func queue_cells(requested: Array[Vector2i], kind: int, require_complete: bool = true) -> int:
	var manager: TaskManager = get_tree().get_first_node_in_group("task_manager") as TaskManager
	if manager == null: return 0
	var changed: Array[Vector2i] = []
	for cell: Vector2i in requested:
		if not can_place(cell): return 0
		if cells.get(cell, 0) >= kind or pending.has(cell): continue
		changed.append(cell)
	if require_complete and affordable_count(kind) < changed.size(): return 0
	var count: int = mini(changed.size(), affordable_count(kind))
	changed.resize(count)
	for cell: Vector2i in changed:
		for resource_id: StringName in ROAD_DATA[kind].construction_cost:
			_base().take_resource(resource_id, ROAD_DATA[kind].construction_cost[resource_id])
		var task: GameTask = manager.create_task(GameTask.TaskType.BUILD_ROAD, self, self)
		task.data = {"cell": cell, "position": grid.grid_to_world(cell), "kind": kind, "progress": 0.0, "duration": ROAD_DATA[kind].construction_time}
		pending[cell] = task
	_clear_road_decorations(changed)
	_commit(changed)
	manager.request_dispatch()
	return count

func work_cell(task: GameTask, worker: Node3D, delta: float) -> void:
	var cell: Vector2i = task.data.cell
	if pending.get(cell) != task or task.assigned_worker != worker: return
	if not can_work_cell(cell):
		_cancel_pending(cell)
		_commit([cell])
		return
	if worker.global_position.distance_to(task.data.position) > 0.65: return
	task.data.progress += delta
	if task.data.progress < task.data.duration: return
	pending.erase(cell)
	if not cells.has(cell): placement_order.append(cell)
	cells[cell] = task.data.kind
	_commit([cell])
	var manager: TaskManager = get_tree().get_first_node_in_group("task_manager") as TaskManager
	manager.complete_task(task)
	worker.return_to_idle()

func _cancel_pending(cell: Vector2i) -> void:
	var task: GameTask = pending[cell]
	pending.erase(cell)
	var manager: TaskManager = get_tree().get_first_node_in_group("task_manager") as TaskManager
	manager.cancel_task(task)

func queue_upgrade_all() -> int:
	var requested: Array[Vector2i] = []
	for cell: Vector2i in placement_order:
		if cells[cell] == Kind.DIRT and can_place(cell): requested.append(cell)
	return queue_cells(requested, Kind.STONE, false)

func place_cells(requested: Array[Vector2i], kind: int) -> int:
	var changed: Array[Vector2i] = []
	for cell: Vector2i in requested:
		if cells.get(cell, 0) >= kind or not can_place(cell): continue
		if kind == Kind.STONE:
			if available_stone() < 1: break
			_base().take_resource(&"stone", 1.0)
		if not cells.has(cell): placement_order.append(cell)
		cells[cell] = kind
		changed.append(cell)
	_clear_road_decorations(changed)
	_commit(changed)
	return changed.size()

func _clear_road_decorations(changed: Array[Vector2i]) -> void:
	if changed.is_empty(): return
	var road_cells: Dictionary = {}
	for cell: Vector2i in changed: road_cells[cell] = true
	# 只在确认铺设时扫描一次簇散布装饰，预览和拆路不触发。
	for node: Node in get_tree().get_nodes_in_group("vegetation"):
		if not node is Node3D or node is ResourceBase or node.is_queued_for_deletion(): continue
		var decoration: Node3D = node as Node3D
		var cell: Vector2i = grid.world_to_grid(decoration.global_position)
		if not road_cells.has(cell) or absf(decoration.global_position.y - grid.get_ground_height(cell)) > 0.8: continue
		decoration.hide()
		decoration.queue_free()

func upgrade_all() -> int:
	return place_cells(placement_order.duplicate(), Kind.STONE)

func remove_cells(requested: Array[Vector2i]) -> void:
	var changed: Array[Vector2i] = []
	for cell: Vector2i in requested:
		var had_pending: bool = pending.has(cell)
		if had_pending: _cancel_pending(cell)
		if not cells.erase(cell) and not had_pending: continue
		placement_order.erase(cell)
		changed.append(cell)
	_commit(changed)

func dirt_count() -> int:
	return cells.values().count(Kind.DIRT)

func move_speed(position: Vector3, base_speed: float) -> float:
	var cell: Vector2i = grid.world_to_grid(position)
	if not cells.has(cell) or grid.occupied_cells.has(cell): return base_speed
	if absf(position.y - grid.get_ground_height(cell)) > 0.8: return base_speed
	return ROAD_DATA[cells[cell]].road_move_speed(base_speed)

func speed_multiplier(position: Vector3) -> float:
	return move_speed(position, 1.0)

func _commit(changed: Array[Vector2i]) -> void:
	if changed.is_empty(): return
	revision += 1
	var dirty: Dictionary = {}
	for cell: Vector2i in changed:
		for offset: Vector2i in [Vector2i.ZERO, Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
			var neighbor: Vector2i = cell + offset
			dirty[Vector2i(floori(float(neighbor.x) / CHUNK_SIZE), floori(float(neighbor.y) / CHUNK_SIZE))] = true
	for chunk: Vector2i in dirty: _rebuild_chunk(chunk)
	roads_changed.emit()

# 返回形态索引与顺时针旋转次数；土路、石路可互相连接。
func tile_shape(cell: Vector2i) -> Vector2i:
	var mask: int = 0
	for index: int in range(4):
		var neighbor: Vector2i = cell + DIRECTIONS[index]
		if cells.has(neighbor) and absf(grid.get_ground_height(cell) - grid.get_ground_height(neighbor)) < 0.1:
			mask |= 1 << index
	for shape: int in range(SHAPE_MASKS.size()):
		var rotated: int = SHAPE_MASKS[shape]
		for turns: int in range(4):
			if rotated == mask: return Vector2i(shape, turns)
			rotated = ((rotated << 1) & 15) | (rotated >> 3)
	return Vector2i.ZERO

func _rebuild_chunk(chunk: Vector2i) -> void:
	var surfaces: Dictionary = {}
	var half: float = grid.cell_size * 0.5
	for y: int in range(chunk.y * CHUNK_SIZE, (chunk.y + 1) * CHUNK_SIZE):
		for x: int in range(chunk.x * CHUNK_SIZE, (chunk.x + 1) * CHUNK_SIZE):
			var cell := Vector2i(x, y)
			if not cells.has(cell) and not pending.has(cell): continue
			var shape: Vector2i = tile_shape(cell)
			var key: Vector2i = Vector2i.ZERO if pending.has(cell) else Vector2i(cells[cell], shape.x)
			if not surfaces.has(key):
				var arrays: Array = []
				arrays.resize(Mesh.ARRAY_MAX)
				arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array()
				arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array()
				arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array()
				surfaces[key] = arrays
			var center: Vector3 = grid.grid_to_world(cell) + Vector3.UP * 0.03
			var corners: Array[Vector3] = [center + Vector3(-half, 0, -half), center + Vector3(half, 0, -half), center + Vector3(half, 0, half), center + Vector3(-half, 0, half)]
			var uvs: Array[Vector2] = [Vector2.ZERO, Vector2.RIGHT, Vector2.ONE, Vector2.DOWN]
			for index: int in [0, 1, 3, 1, 2, 3]:
				surfaces[key][Mesh.ARRAY_VERTEX].append(corners[index])
				surfaces[key][Mesh.ARRAY_NORMAL].append(Vector3.UP)
				surfaces[key][Mesh.ARRAY_TEX_UV].append(uvs[posmod(index - shape.y, 4)])
	if surfaces.is_empty():
		if chunks.has(chunk):
			chunks[chunk].queue_free()
			chunks.erase(chunk)
		return
	if not chunks.has(chunk):
		var instance := MeshInstance3D.new()
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(instance)
		chunks[chunk] = instance
	var mesh := ArrayMesh.new()
	for key: Vector2i in surfaces:
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, surfaces[key])
		if not shape_materials.has(key):
			var material: StandardMaterial3D
			if key.x == 0:
				material = StandardMaterial3D.new()
				material.albedo_color = Color(0.8, 0.65, 0.25)
				material.roughness = 1.0
			else:
				material = ROAD_DATA[key.x].road_shape_material(key.y)
			shape_materials[key] = material
		mesh.surface_set_material(mesh.get_surface_count() - 1, shape_materials[key])
	chunks[chunk].mesh = mesh

func _refresh_graph(map: RID) -> void:
	var inputs: Array = [revision, NavigationServer3D.map_get_iteration_id(map), hash(grid.occupied_cells), map]
	if inputs == graph_inputs: return
	graph_inputs = inputs
	graph.clear()
	graph_ids.clear()
	for cell: Vector2i in placement_order:
		if grid.occupied_cells.has(cell): continue
		var point: Vector3 = grid.grid_to_world(cell)
		var nearest: Vector3 = NavigationServer3D.map_get_closest_point(map, point)
		if Vector2(nearest.x - point.x, nearest.z - point.z).length() > 0.2 or absf(nearest.y - point.y) > 0.75: continue
		var id: int = graph.get_available_point_id()
		graph_ids[cell] = id
		graph.add_point(id, nearest, 0.4 if cells[cell] == Kind.DIRT else 0.35)
	for cell: Vector2i in graph_ids:
		for offset: Vector2i in [Vector2i.RIGHT, Vector2i.DOWN]:
			var neighbor: Vector2i = cell + offset
			if graph_ids.has(neighbor) and absf(grid.get_ground_height(cell) - grid.get_ground_height(neighbor)) < 0.1:
				graph.connect_points(graph_ids[cell], graph_ids[neighbor])

func _nearest_roads(point: Vector3) -> Array[int]:
	var ids: Array[int] = []
	for id: int in graph.get_point_ids():
		var distance: float = point.distance_squared_to(graph.get_point_position(id))
		var index: int = 0
		while index < ids.size() and point.distance_squared_to(graph.get_point_position(ids[index])) <= distance: index += 1
		ids.insert(index, id)
		if ids.size() > 3: ids.pop_back()
	return ids

func _length(path: PackedVector3Array) -> float:
	var length: float = 0.0
	for index: int in range(1, path.size()): length += path[index - 1].distance_to(path[index])
	return length

func _path(map: RID, from: Vector3, to: Vector3) -> PackedVector3Array:
	var path: PackedVector3Array = NavigationServer3D.map_get_path(map, from, to, true)
	if path.is_empty(): return path
	var delta: Vector3 = path[-1] - to
	return path if Vector2(delta.x, delta.z).length() <= 0.25 and absf(delta.y) <= 0.75 else PackedVector3Array()

# null 表示本帧查询预算已满，调用者下一帧再试；空数组表示没有更合适的道路路线。
func preferred_path(from: Vector3, to: Vector3, map: RID) -> Variant:
	if cells.size() < 2 or NavigationServer3D.map_get_iteration_id(map) == 0: return PackedVector3Array()
	var frame: int = Engine.get_physics_frames()
	if frame != query_frame:
		query_frame = frame
		queries_this_frame = 0
	if queries_this_frame >= 2: return null
	queries_this_frame += 1
	route_queries += 1
	_refresh_graph(map)
	var direct: PackedVector3Array = _path(map, from, to)
	if direct.is_empty(): return PackedVector3Array()
	var best_cost: float = _length(direct)
	var best := PackedVector3Array()
	var approaches: Dictionary = {}
	var exits: Dictionary = {}
	for id: int in _nearest_roads(from): approaches[id] = _path(map, from, graph.get_point_position(id))
	for id: int in _nearest_roads(to): exits[id] = _path(map, graph.get_point_position(id), to)
	for entry: int in approaches:
		if approaches[entry].is_empty(): continue
		for exit: int in exits:
			if exits[exit].is_empty(): continue
			var ids: PackedInt64Array = graph.get_id_path(entry, exit)
			if ids.size() < 2: continue
			var road := PackedVector3Array()
			var cost: float = _length(approaches[entry]) + _length(exits[exit])
			for id: int in ids: road.append(graph.get_point_position(id))
			for index: int in range(1, ids.size()): cost += road[index - 1].distance_to(road[index]) * graph.get_point_weight_scale(ids[index])
			if cost >= best_cost: continue
			# 只保留转角，接入与离开道路仍使用原导航；逐段验证不跨越墙体或导航缺口。
			var corners := PackedVector3Array([road[0]])
			for index: int in range(1, road.size() - 1):
				if (road[index] - road[index - 1]).normalized().dot((road[index + 1] - road[index]).normalized()) < 0.99: corners.append(road[index])
			corners.append(road[-1])
			var connected: bool = true
			for index: int in range(1, corners.size()):
				var segment: PackedVector3Array = _path(map, corners[index - 1], corners[index])
				if segment.is_empty() or _length(segment) > corners[index - 1].distance_to(corners[index]) + 0.25:
					connected = false
					break
			if not connected: continue
			best = approaches[entry].duplicate()
			best.append_array(corners)
			best.append_array(exits[exit])
			best_cost = cost
	return best

func overlaps_resource(geometry: Dictionary) -> bool:
	var center: Vector2 = geometry.center
	var radius: float = geometry.radius
	var minimum: Vector2i = grid.world_to_grid(Vector3(center.x - radius, geometry.height, center.y - radius))
	var maximum: Vector2i = grid.world_to_grid(Vector3(center.x + radius, geometry.height, center.y + radius))
	for y: int in range(minimum.y, maximum.y + 1):
		for x: int in range(minimum.x, maximum.x + 1):
			var cell := Vector2i(x, y)
			if (not cells.has(cell) and not pending.has(cell)) or absf(grid.get_ground_height(cell) - float(geometry.height)) > 1.0: continue
			var origin: Vector3 = grid.grid_to_world(cell)
			var half: float = grid.cell_size * 0.5
			var outline := PackedVector2Array([Vector2(origin.x - half, origin.z - half), Vector2(origin.x + half, origin.z - half), Vector2(origin.x + half, origin.z + half), Vector2(origin.x - half, origin.z + half)])
			var gap: float = ResourceSpacing.circle_gap(center, radius, outline) if geometry.circle else ResourceSpacing.gap(geometry.outline, outline)
			if gap <= 0.05: return true
	return false
