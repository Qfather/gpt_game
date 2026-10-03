extends SceneTree
func _init() -> void:
	var fog = load("res://Script/world/fog_of_war.gd").new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 418
	for sample in range(12):
		var limits := PackedFloat32Array()
		limits.resize(fog.ANGLE_SAMPLES)
		for i in range(limits.size()): limits[i] = rng.randf_range(0.0, 24.0)
		var actual = fog._smooth_sight_limits(limits)
		for i in range(limits.size()):
			var expected: float = 0.0
			for offset in range(-12, 13): expected += limits[posmod(i + offset, limits.size())] * float(13 - absi(offset))
			expected /= 169.0
			if absf(actual[i] - expected) > 0.00001:
				push_error("迷雾平滑结果与原权重不一致")
				fog.free()
				quit(1)
				return
	fog.free()
	print("迷雾平滑等价测试通过：固定种子12组数据、全部720个角度含环形边界")
	quit()
