extends RefCounted

var manager: Node
var target: Vector3 = Vector3.INF
var route := PackedVector3Array()
var index: int = 0
var revision: int = -1
var map_iteration: int = -1
var retry_msec: int = 0

func _manager(unit: Node) -> Node:
	if not is_instance_valid(manager): manager = unit.get_tree().get_first_node_in_group("road_manager")
	return manager

func move_speed(unit: Node3D, base_speed: float) -> float:
	return manager.move_speed(unit.global_position, base_speed) if is_instance_valid(_manager(unit)) else base_speed

func next_position(unit: Node3D, agent: NavigationAgent3D) -> Vector3:
	var ordinary: Vector3 = agent.get_next_path_position()
	if not is_instance_valid(_manager(unit)): return ordinary
	var iteration: int = NavigationServer3D.map_get_iteration_id(agent.get_navigation_map())
	var now: int = Time.get_ticks_msec()
	if (target.distance_squared_to(agent.target_position) > 0.25 or revision != manager.revision or map_iteration != iteration) and now >= retry_msec:
		var path: Variant = manager.preferred_path(unit.global_position, agent.target_position, agent.get_navigation_map())
		if path != null:
			route = path.duplicate()
			# 道路路径来自导航服务器，和普通代理路径一样减去单位高度补偿。
			for point_index: int in range(route.size()):
				route[point_index].y -= agent.path_height_offset
			index = 0
			target = agent.target_position
			revision = manager.revision
			map_iteration = iteration
			retry_msec = now + 500
	# 目标／障碍变化后不继续沿旧路线移动，等待分帧重规划。
	if target.distance_squared_to(agent.target_position) > 0.25 or revision != manager.revision or map_iteration != iteration: return ordinary
	while index < route.size() and unit.global_position.distance_to(route[index]) < 0.3: index += 1
	return route[index] if index < route.size() else ordinary

func invalidate() -> void:
	revision = -1
	retry_msec = 0
