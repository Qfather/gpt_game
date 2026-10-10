extends SceneTree

# 有渲染模式运行，仅生成静态图片，不修改单位配置或覆盖正式图标。
func _initialize() -> void:
	call_deferred("_generate")

func _generate() -> void:
	var preview = load("res://addons/resource_editor/building_scene_preview.gd").new()
	root.add_child(preview)
	DirAccess.make_dir_recursive_absolute("res://assets/icons/units")
	for file: String in DirAccess.get_files_at("res://data/units"):
		if not file.ends_with(".tres"): continue
		var data: UnitData = load("res://data/units/" + file)
		if data.icon != null: continue
		preview.show_scene(data.visual_scene, data.visual_tint)
		await process_frame
		await RenderingServer.frame_post_draw
		var image: Image = preview.viewport.get_texture().get_image()
		image.resize(96, 96, Image.INTERPOLATE_LANCZOS)
		var error := image.save_png("res://assets/icons/units/%s.png" % data.id)
		if error != OK:
			push_error("单位图标生成失败：%s" % data.id)
			quit(1)
			return
		print("已生成单位图标：", data.id)
	preview.queue_free()
	quit(0)
