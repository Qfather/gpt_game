extends SceneTree

var failed: bool = false


func _initialize() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		push_error(message)


func _run() -> void:
	await create_timer(3.0).timeout
	var panel: Control = load("res://addons/resource_editor/building_editor_panel.gd").new()
	panel.autosave.enabled = false
	root.add_child(panel)
	var original: BuildingData = load("res://data/buildings/BaseData.tres")
	var scene_path: String = "res://.godot/building_save_scope_base.tscn"
	var data_path: String = "res://.godot/building_save_scope_base.tres"
	_expect(ResourceSaver.save(original.building_scene.duplicate(), scene_path) == OK, "建立隔离场景")
	var copy: BuildingData = original.duplicate(true)
	copy.building_scene = load(scene_path)
	_expect(ResourceSaver.save(copy, data_path) == OK, "建立隔离配置")
	panel.buildings.append(load(data_path))
	panel.select_building(panel.buildings.size() - 1)
	await process_frame
	await process_frame
	panel.autosave.enabled = true
	var scene_time: int = FileAccess.get_modified_time(scene_path)
	var scene_text: String = FileAccess.get_file_as_string(scene_path)
	await create_timer(1.1).timeout
	panel.current.surface_drying_range += 0.5
	panel.inspector.property_edited.emit("surface_drying_range")
	await create_timer(0.7).timeout
	var saved: BuildingData = ResourceLoader.load(data_path, "", ResourceLoader.CACHE_MODE_IGNORE)
	_expect(saved.surface_drying_range == copy.surface_drying_range + 0.5, "通用属性自动保存")
	_expect(FileAccess.get_modified_time(scene_path) == scene_time, "只改通用属性不能重写场景时间")
	_expect(FileAccess.get_file_as_string(scene_path) == scene_text, "只改通用属性不能改变场景内容")
	var field: SpinBox = panel.field_controls[".:base_housing_capacity"]
	var next_capacity: int = int(field.value) + 1
	field.value = next_capacity
	await create_timer(0.7).timeout
	var packed: PackedScene = ResourceLoader.load(scene_path, "", ResourceLoader.CACHE_MODE_IGNORE)
	var restored: Node = packed.instantiate()
	_expect(restored.base_housing_capacity == next_capacity, "专属参数自动保存到场景")
	restored.free()
	_expect(FileAccess.get_modified_time(scene_path) > scene_time, "专属参数改变时更新场景时间")
	scene_time = FileAccess.get_modified_time(scene_path)
	await create_timer(1.1).timeout
	panel.current.surface_drying_noise = 0.42
	panel.inspector.property_edited.emit("surface_drying_noise")
	# 切换对象会立即补保存通用属性，不能再次重写已经保存的场景。
	panel.select_building(0)
	saved = ResourceLoader.load(data_path, "", ResourceLoader.CACHE_MODE_IGNORE)
	_expect(saved.surface_drying_noise == 0.42, "切换建筑前补保存通用属性")
	_expect(FileAccess.get_modified_time(scene_path) == scene_time, "专属参数保存后清除场景修改标记")
	panel.autosave.enabled = false
	panel.queue_free()
	await process_frame
	if not failed:
		print("建筑保存范围测试通过：通用属性不重写场景，专属参数保存读回，切换前补保存不重写场景")
	quit(1 if failed else 0)
