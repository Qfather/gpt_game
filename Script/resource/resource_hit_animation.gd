@tool
extends RefCounted

var tween: Tween
var target: Node3D
var rest: Transform3D

func reset() -> void:
	if tween != null:
		tween.kill()
		if is_instance_valid(target): target.transform = rest
		tween = null

func play(visual: Node3D, effect: ResourceHitEffect, attacker_position: Vector3) -> void:
	reset()
	if effect == null or effect.kind == ResourceHitEffect.Kind.NONE or visual == null: return
	target = visual
	rest = visual.transform
	var away: Vector3 = visual.global_position - attacker_position
	away.y = 0.0
	if away.length_squared() < 0.001: away = Vector3.RIGHT
	var parent_3d: Node3D = visual.get_parent() as Node3D
	if parent_3d != null: away = parent_3d.global_basis.inverse() * away
	away = away.normalized()
	var hit: Transform3D = effect.displaced(rest, away)
	tween = visual.create_tween()
	tween.tween_method(func(weight: float) -> void: visual.transform = rest.interpolate_with(hit, weight), 0.0, 1.0, effect.hit_time()).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_method(func(weight: float) -> void: visual.transform = hit.interpolate_with(rest, weight), 0.0, 1.0, effect.return_time()).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func() -> void:
		visual.transform = rest
		tween = null
	)
