class_name ResourceSpacing
extends RefCounted


static func projected_box(bounds: AABB, transform: Transform3D) -> PackedVector2Array:
	var outline := PackedVector2Array()
	for x: float in [bounds.position.x, bounds.end.x]:
		for y: float in [bounds.position.y, bounds.end.y]:
			for z: float in [bounds.position.z, bounds.end.z]:
				var point: Vector3 = transform * Vector3(x, y, z)
				outline.append(Vector2(point.x, point.z))
	return Geometry2D.convex_hull(outline)


static func transformed(outline: PackedVector2Array, position: Vector2, yaw: float) -> PackedVector2Array:
	var result := PackedVector2Array()
	for point: Vector2 in outline:
		result.append(point.rotated(-yaw) + position)
	return result


static func gap(a: PackedVector2Array, b: PackedVector2Array) -> float:
	if Geometry2D.is_point_in_polygon(a[0], b) or Geometry2D.is_point_in_polygon(b[0], a):
		return 0.0
	var distance: float = INF
	for i: int in range(a.size()):
		var start: Vector2 = a[i]
		var end: Vector2 = a[(i + 1) % a.size()]
		for j: int in range(b.size()):
			var other_start: Vector2 = b[j]
			var other_end: Vector2 = b[(j + 1) % b.size()]
			if Geometry2D.segment_intersects_segment(start, end, other_start, other_end) != null:
				return 0.0
			distance = minf(distance, start.distance_to(Geometry2D.get_closest_point_to_segment(start, other_start, other_end)))
			distance = minf(distance, other_start.distance_to(Geometry2D.get_closest_point_to_segment(other_start, start, end)))
	return distance


static func circle_gap(center: Vector2, radius: float, outline: PackedVector2Array) -> float:
	if Geometry2D.is_point_in_polygon(center, outline):
		return 0.0
	var distance: float = INF
	for i: int in range(outline.size()):
		distance = minf(distance, center.distance_to(Geometry2D.get_closest_point_to_segment(center, outline[i], outline[(i + 1) % outline.size()])))
	return maxf(0.0, distance - radius)
