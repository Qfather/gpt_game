extends RefCounted

static func play(visual: Node3D, source: Node3D) -> void:
	if not is_instance_valid(visual) or not is_instance_valid(source) or not visual.is_inside_tree(): return
	var state: Dictionary = visual.get_meta("hit_recoil", {"origin": visual.position})
	var previous: Tween = state.get("tween")
	if previous != null and previous.is_valid(): previous.kill()
	var direction: Vector3 = visual.global_position - source.global_position
	direction.y = 0
	var offset: Vector3 = visual.get_parent().global_basis.inverse() * direction.normalized() * 0.15
	visual.position = state.origin
	var tween := visual.create_tween()
	state.tween = tween
	visual.set_meta("hit_recoil", state)
	tween.tween_property(visual, "position", state.origin + offset, 0.06)
	tween.tween_property(visual, "position", state.origin, 0.16)
	tween.tween_callback(func() -> void: visual.remove_meta("hit_recoil"))
