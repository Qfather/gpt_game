extends SceneTree

func _initialize() -> void:
	var runtime := MapGenerateRuntime.new()
	var saved := ResourceLoader.load("res://addons/MapGenerate/自动岛屿.tres", "", ResourceLoader.CACHE_MODE_IGNORE) as WFCMapData
	assert(saved.surface != null)
	var settings := runtime._load_surface_settings()
	assert(settings != saved.surface)
	if saved.surface.layers[0].texture != null:
		assert(settings.layers[0].texture.resource_path == saved.surface.layers[0].texture.resource_path)
	else:
		assert(settings.layers[0].texture == null)
	assert(settings.resolution == saved.surface.resolution)
	var source := WFCMapData.new()
	source.surface = WFCSurfaceSettings.new()
	runtime.surface_source_map_path = "res://.godot/game_surface_settings_source.tres"
	assert(ResourceSaver.save(source, runtime.surface_source_map_path) == OK)
	assert(runtime._load_surface_settings().layers[0].texture == null)
	var image := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	image.fill(Color.GREEN)
	source.surface.layers[0].texture = ImageTexture.create_from_image(image)
	source.surface.layers[0].tile_size_m = 3.7
	assert(ResourceSaver.save(source, runtime.surface_source_map_path) == OK)
	settings = runtime._load_surface_settings()
	assert(settings.layers[0].texture != null and settings.layers[0].tile_size_m == 3.7, "再次保存后必须读取更新配置")
	runtime.surface_settings = WFCSurfaceSettings.new()
	assert(runtime._load_surface_settings().layers[0].texture == null, "显式专用配置优先")
	runtime.free()
	print("游戏地表配置同步通过：当前草贴图、保存更新、参数、专用配置优先")
	quit()
