extends SceneTree

class ReferenceFog extends "res://Tests/support/fog_cpu_reference.gd":
	pass

func _init() -> void:
	var actual = load("res://Script/world/fog_of_war.gd").new()
	var reference = ReferenceFog.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 418
	for multiplier: float in [1.0, 0.6, 1.5]:
		for fog in [actual, reference]:
			fog.extent = Vector2(80, 64)
			fog.visibility_multiplier = multiplier
			fog.explored = Image.create(256, 256, false, Image.FORMAT_L8)
			fog.visibility_map = Image.create(256, 256, false, Image.FORMAT_L8)
			fog.visual_map = Image.create(256, 256, false, Image.FORMAT_RGBA8)
		for refresh in range(3):
			for fog in [actual, reference]:
				fog.visibility_map.copy_from(fog.explored)
				fog.visual_map.fill(Color(0, 1, 0, 0))
				fog.fully_visible_pixels.resize(256 * 256)
				fog.fully_visible_pixels.fill(0)
				fog.merging_visibility = true
			var trees: Array[Vector3] = [Vector3(3, 2, 1), Vector3(-4, 1.5, 4), Vector3(8, 2.5, -3)]
			for source in range(20):
				var point := Vector3(rng.randf_range(-8, 8), 0, rng.randf_range(-8, 8))
				var radius: float = rng.randf_range(8, 18)
				actual._reveal_at(point, radius, trees)
				reference._reveal_at(point, radius, trees)
				for image_name: String in ["explored", "visibility_map", "visual_map"]:
					if actual.get(image_name).get_data() != reference.get(image_name).get_data():
						push_error("迷雾像素不等价：%s 倍率%s 刷新%s 视野源%s" % [image_name, multiplier, refresh, source])
						actual.free()
						reference.free()
						quit(1)
						return
	actual.free()
	reference.free()
	print("迷雾像素等价通过：3种视野倍率、连续3次刷新、20个重叠视野源及树遮挡，全部图像逐字节一致")
	quit()
