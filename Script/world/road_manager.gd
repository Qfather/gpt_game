extends Node3D

signal roads_changed

enum Kind { DIRT = 1, STONE = 2 }
const CHUNK_SIZE: int = 8
const COLORS: Array[Color] = [Color.BLACK, Color(0.43, 0.28, 0.13), Color(0.55, 0.59, 0.63)]

class RoadGraph extends AStar3D:
	func _estimate_cost(from_id: int, to_id: int) -> float:
		return get_point_position(from_id).distance_to(get_point_position(to_id)) * 0.35

var grid: BuildGrid
var cells: Dictionary = {}
var placement_order: Array[Vector2i] = []
var revision: int = 0
var chunks: Dictionary = {}
var graph := RoadGraph.new()
var graph_ids: Dictionary = {}
var graph_inputs: Array = []
var query_frame: int = -1
var queries_this_frame: int = 0
var route_queries: int = 0

func _ready() -> void:
	add_to_group("road_manager")
	if grid == null: grid = get_node("../Systems/BuildGrid")

func can_place(cell: Vector2i) -> bool:
	return grid.is_area_free(cell, Vector2i.ONE, 0, false, true)

func _base() -> Node:
	return get_tree().get_first_node_in_group("bases")

func available_stone() -> int:
	var base: Node = _base()
	return floori(base.get_resource(&"stone")) if is_instance_valid(base) else 0

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
	_commit(changed)
	return changed.size()

func upgrade_all() -> int:
	return place_cells(placement_order.duplicate(), Kind.STONE)

func remove_cells(requested: Array[Vector2i]) -> void:
	var changed: Array[Vector2i] = []
	for cell: Vector2i in requested:
		if not cells.erase(cell): continue
		placement_order.erase(cell)
		changed.append(cell)
	_commit(changed)

func dirt_count() -> int:
	return cells.values().count(Kind.DIRT)

func speed_multiplier(position: Vector3) -> float:
	var cell: Vector2i = grid.world_to_grid(position)
	if not cells.has(cell) or grid.occupied_cells.has(cell): return 1.0
	if absf(position.y - grid.get_ground_height(cell)) > 0.8: return 1.0
	return 1.05 if cells[cell] == Kind.DIRT else 1.10

func _commit(changed: Array[Vector2i]) -> void:
	if changed.is_empty(): return
	revision += 1
	var dirty: Dictionary = {}
	for cell: Vector2i in changed:
		dirty[Vector2i(floori(float(cell.x) / CHUNK_SIZE), floori(float(cell.y) / CHUNK_SIZE))] = true
	for chunk: Vector2i in dirty: _rebuild_chunk(chunk)
	roads_changed.emit()

func _rebuild_chunk(chunk: Vector2i) -> void:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var half: float = grid.cell_size * 0.5
	for y: int in range(chunk.y * CHUNK_SIZE, (chunk.y + 1) * CHUNK_SIZE):
		for x: int in range(chunk.x * CHUNK_SIZE, (chunk.x + 1) * CHUNK_SIZE):
			var cell := Vector2i(x, y)
			if not cells.has(cell): continue
			var center: Vector3 = grid.grid_to_world(cell) + Vector3.UP * 0.03
			var corners: Array[Vector3] = [center + Vector3(-half, 0, -half), center + Vector3(half, 0, -half), center + Vector3(half, 0, half), center + Vector3(-half, 0, half)]
			for index: int in [0, 1, 3, 1, 2, 3]:
				vertices.append(corners[index])
				normals.append(Vector3.UP)
				colors.append(COLORS[cells[cell]])
	if vertices.is_empty():
		if chunks.has(chunk):
			chunks[chunk].queue_free()
			chunks.erase(chunk)
		return
	if not chunks.has(chunk):
		var instance := MeshInstance3D.new()
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var material := StandardMaterial3D.new()
		material.vertex_color_use_as_albedo = true
		material.roughness = 1.0
		instance.material_override = material
		add_child(instance)
		chunks[chunk] = instance
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
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
			if not cells.has(cell) or absf(grid.get_ground_height(cell) - float(geometry.height)) > 1.0: continue
			var origin: Vector3 = grid.grid_to_world(cell)
			var half: float = grid.cell_size * 0.5
			var outline := PackedVector2Array([Vector2(origin.x - half, origin.z - half), Vector2(origin.x + half, origin.z - half), Vector2(origin.x + half, origin.z + half), Vector2(origin.x - half, origin.z + half)])
			var gap: float = ResourceSpacing.circle_gap(center, radius, outline) if geometry.circle else ResourceSpacing.gap(geometry.outline, outline)
			if gap <= 0.05: return true
	return false
