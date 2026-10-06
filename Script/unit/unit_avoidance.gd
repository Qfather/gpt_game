extends RefCounted

var check_time: float = 0.0
var turn_time: float = 0.0
var turn_direction := Vector3.ZERO
var blocker: WeakRef
var shape := SphereShape3D.new()


func steer(body: CharacterBody3D, agent: NavigationAgent3D, desired: Vector3, delta: float) -> Vector3:
	var forward := Vector3(desired.x, 0, desired.z).normalized()
	if forward == Vector3.ZERO: return desired
	check_time -= delta
	turn_time -= delta
	if check_time <= 0.0:
		check_time = 0.15
		shape.radius = 0.85
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = shape
		query.transform = Transform3D(Basis.IDENTITY, body.global_position + Vector3(0, 0.8, 0) + forward * 0.65)
		query.collision_mask = 2
		query.exclude = [body.get_rid()]
		var nearest: CharacterBody3D
		var nearest_distance: float = INF
		for hit: Dictionary in body.get_world_3d().direct_space_state.intersect_shape(query, 8):
			var other: CharacterBody3D = hit.collider as CharacterBody3D
			if other == null or not other.is_visible_in_tree() or other.is_queued_for_deletion(): continue
			if body.get("target") == other: continue
			var offset: Vector3 = other.global_position - body.global_position
			offset.y = 0
			if offset.dot(forward) <= 0.0: continue
			var predicted: Vector3 = offset + (other.velocity - desired) * 0.3
			predicted.y = 0
			if predicted.length() > 0.8 and offset.length() > 0.65: continue
			if offset.length_squared() < nearest_distance:
				nearest = other
				nearest_distance = offset.length_squared()
		blocker = weakref(nearest) if nearest != null else null
	var other: CharacterBody3D = blocker.get_ref() as CharacterBody3D if blocker != null else null
	if not is_instance_valid(other): return desired
	var offset: Vector3 = other.global_position - body.global_position
	offset.y = 0
	if offset.dot(forward) <= 0.0 or offset.length() > 1.6: return desired
	if other.has_method("yield_to_unit"):
		other.yield_to_unit(body, forward)
	var speed: float = Vector2(desired.x, desired.z).length()
	# 同向跟随先减速，避免后方角色不断推挤前方角色。
	if other.velocity.length() > 0.1 and other.velocity.normalized().dot(forward) > 0.7:
		return desired * clampf((offset.length() - 0.4) / 0.8, 0.0, 1.0)
	if turn_time <= 0.0:
		var right := Vector3(-forward.z, 0, forward.x)
		turn_direction = Vector3.ZERO
		for side: Vector3 in [right, -right]:
			if can_step(body, agent, side * 0.85):
				turn_direction = side
				break
		turn_time = 0.7
	if turn_direction != Vector3.ZERO:
		var adjusted: Vector3 = forward * 0.35 + turn_direction * 0.85
		if can_step(body, agent, adjusted.normalized() * 0.4):
			return Vector3(adjusted.x * speed, desired.y, adjusted.z * speed)
	# 窄处保持固定优先级，避免双方同时前进或同时退让。
	if body.get_instance_id() > other.get_instance_id():
		return -forward * speed * 0.45 if can_step(body, agent, -forward * 0.5) else Vector3.ZERO
	return desired * 0.45


static func can_step(body: CharacterBody3D, agent: NavigationAgent3D, offset: Vector3) -> bool:
	var map: RID = agent.get_navigation_map()
	if NavigationServer3D.map_get_iteration_id(map) == 0: return false
	var destination: Vector3 = body.global_position + offset
	var projected: Vector3 = NavigationServer3D.map_get_closest_point(map, destination)
	if Vector2(projected.x - destination.x, projected.z - destination.z).length() > 0.2 or absf(projected.y - destination.y) > 0.8:
		return false
	return not body.test_move(body.global_transform, offset)
