@tool
extends EditorPlugin

const CONFIG_PATH := "res://data/world/MapGeneration_V0.tres"

var config: MapGenerationConfig
var dock: VBoxContainer
var shape_picker: OptionButton
var seed_field: SpinBox
var preview: MapPreview2D
var outline_button: Button
var lake_button: Button
var _sliders: Dictionary = {}


func _enter_tree() -> void:
	config = load(CONFIG_PATH) as MapGenerationConfig
	if config == null:
		push_error("地图生成器插件无法读取地图配置：" + CONFIG_PATH)
		return
	_build_dock()
	add_control_to_dock(EditorPlugin.DOCK_SLOT_RIGHT_UL, dock)
	print("地图生成器编辑器面板已载入")


func _exit_tree() -> void:
	if dock:
		remove_control_from_docks(dock)
		dock.queue_free()


func _build_dock() -> void:
	dock = VBoxContainer.new()
	dock.name = "地图"
	dock.custom_minimum_size = Vector2(320.0, 520.0)
	var settings_scroll := ScrollContainer.new()
	settings_scroll.custom_minimum_size.y = 235.0
	settings_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	settings_scroll.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var settings := VBoxContainer.new()
	settings.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	settings_scroll.add_child(settings)
	var title := Label.new()
	title.text = "地图生成器 V0"
	settings.add_child(title)
	shape_picker = OptionButton.new()
	for shape_name in ["圆形", "椭圆", "正方形", "长方形", "三角形", "自定义"]:
		shape_picker.add_item(shape_name)
	shape_picker.item_selected.connect(_on_shape_selected)
	settings.add_child(_labeled_control("岛屿形状", shape_picker))
	_add_pair(settings, "宽度", "width", 8.0, 80.0, 1.0, "高度", "height", 8.0, 80.0, 1.0)
	_add_pair(settings, "据点 X", "base_x", -40.0, 40.0, 0.5, "据点 Z", "base_z", -40.0, 40.0, 0.5)
	_add_pair(settings, "自然强化", "naturalization", 0.0, 1.0, 0.01, "噪波缩放", "noise_scale", 0.2, 5.0, 0.05)
	_add_pair(settings, "湖泊数量", "lake_count", 0.0, 8.0, 1.0, "湖泊半径", "lake_radius", 1.0, 6.0, 0.1)
	_add_pair(settings, "树木密度", "tree_density", 0.0, 1.0, 0.01, "岩石密度", "stone_density", 0.0, 1.0, 0.01)
	_add_single(settings, "地形起伏", "terrain_relief", 0.0, 0.8, 0.01)
	var density_hint := Label.new()
	density_hint.text = "密度基准：树木8棵、岩石5块 / 100㎡陆地（100%）"
	density_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	settings.add_child(density_hint)
	dock.add_child(settings_scroll)
	var preview_area := Control.new()
	preview_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview = MapPreview2D.new()
	preview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	preview.custom_minimum_size = Vector2(280.0, 240.0)
	preview.outline_drawn.connect(_on_custom_outline_drawn)
	preview.lake_drawn.connect(_on_custom_lake_drawn)
	preview_area.add_child(preview)
	var actions := VBoxContainer.new()
	actions.position = Vector2(8.0, 8.0)
	actions.size = Vector2(304.0, 82.0)
	actions.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	seed_field = SpinBox.new()
	seed_field.min_value = 0
	seed_field.max_value = 2147483647
	seed_field.step = 1
	seed_field.prefix = "随机种子 "
	seed_field.custom_minimum_size.x = 180.0
	seed_field.value_changed.connect(_on_seed_changed)
	actions.add_child(seed_field)
	var row_one := HBoxContainer.new()
	for item in [["R轮廓", _randomize_outline], ["R资源", _randomize_resources], ["R据点", _randomize_base]]:
		row_one.add_child(_action_button(item[0], item[1]))
	actions.add_child(row_one)
	var row_two := HBoxContainer.new()
	outline_button = _action_button("绘制轮廓", _toggle_outline_drawing)
	lake_button = _action_button("绘制湖泊", _toggle_lake_drawing)
	row_two.add_child(outline_button)
	row_two.add_child(lake_button)
	row_two.add_child(_action_button("清除绘制", _clear_drawings))
	row_two.add_child(_action_button("保存", _save_config))
	actions.add_child(row_two)
	preview_area.add_child(actions)
	dock.add_child(preview_area)
	_refresh_controls()
	_refresh_preview()


func _add_pair(parent: VBoxContainer, label_a: String, key_a: String, min_a: float, max_a: float, step_a: float, label_b: String, key_b: String, min_b: float, max_b: float, step_b: float) -> void:
	var row := HBoxContainer.new()
	row.add_child(_slider_cell(label_a, key_a, min_a, max_a, step_a))
	row.add_child(_slider_cell(label_b, key_b, min_b, max_b, step_b))
	parent.add_child(row)


func _add_single(parent: VBoxContainer, label_text: String, key: String, minimum: float, maximum: float, step: float) -> void:
	parent.add_child(_slider_cell(label_text, key, minimum, maximum, step))


func _slider_cell(label_text: String, key: String, minimum: float, maximum: float, step: float) -> Control:
	var cell := VBoxContainer.new()
	cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var header := HBoxContainer.new()
	var label := Label.new()
	label.text = label_text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var value_label := Label.new()
	value_label.custom_minimum_size.x = 38.0
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	header.add_child(label)
	header.add_child(value_label)
	cell.add_child(header)
	var slider := HSlider.new()
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = step
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.value_changed.connect(_on_slider_changed.bind(key, value_label))
	cell.add_child(slider)
	_sliders[key] = {"slider": slider, "value_label": value_label}
	return cell


func _action_button(text_value: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text_value
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(callback)
	return button


func _labeled_control(label_text: String, control: Control) -> Control:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size.x = 90.0
	row.add_child(label)
	row.add_child(control)
	return row


func _refresh_controls() -> void:
	shape_picker.select(config.island_shape)
	seed_field.value = config.seed
	_set_slider("width", config.island_size.x)
	_set_slider("height", config.island_size.y)
	_set_slider("base_x", config.base_position.x)
	_set_slider("base_z", config.base_position.y)
	_set_slider("terrain_relief", config.terrain_relief)
	_set_slider("naturalization", config.naturalization)
	_set_slider("noise_scale", config.noise_scale)
	_set_slider("lake_count", config.lake_count)
	_set_slider("lake_radius", config.lake_radius)
	_set_slider("tree_density", config.tree_density)
	_set_slider("stone_density", config.stone_density)


func _set_slider(key: String, value: float) -> void:
	var controls: Dictionary = _sliders[key]
	var slider := controls["slider"] as HSlider
	slider.set_value_no_signal(value)
	_update_value_label(controls["value_label"] as Label, value)


func _update_value_label(label: Label, value: float) -> void:
	label.text = str(roundi(value)) if is_equal_approx(value, roundf(value)) else ("%.2f" % value).trim_suffix("0").trim_suffix(".")


func _on_slider_changed(value: float, key: String, value_label: Label) -> void:
	_update_value_label(value_label, value)
	match key:
		"width": config.island_size.x = value
		"height": config.island_size.y = value
		"base_x": config.base_position.x = value
		"base_z": config.base_position.y = value
		"terrain_relief": config.terrain_relief = value
		"naturalization": config.naturalization = value
		"noise_scale": config.noise_scale = value
		"lake_count": config.lake_count = int(value)
		"lake_radius": config.lake_radius = value
		"tree_density": config.tree_density = value
		"stone_density": config.stone_density = value
	_refresh_preview()


func _on_seed_changed(value: float) -> void:
	config.seed = int(value)
	_refresh_preview()


func _on_shape_selected(index: int) -> void:
	if index == MapGenerationConfig.IslandShape.CUSTOM and config.custom_outline.size() < 3:
		push_warning("先使用‘绘制轮廓’在地图预览中绘制")
		shape_picker.select(config.island_shape)
		return
	config.island_shape = index
	_refresh_preview()


func _toggle_outline_drawing() -> void:
	if preview.is_drawing_outline():
		preview.cancel_drawing()
		outline_button.text = "绘制轮廓"
	else:
		preview.start_outline_drawing()
		outline_button.text = "结束绘制"
		lake_button.text = "绘制湖泊"


func _toggle_lake_drawing() -> void:
	if preview.is_drawing_lake():
		preview.cancel_drawing()
		lake_button.text = "绘制湖泊"
	else:
		config.lake_count = 0
		config.custom_lakes.clear()
		_set_slider("lake_count", 0.0)
		_refresh_preview()
		preview.start_lake_drawing()
		lake_button.text = "结束绘制"
		outline_button.text = "绘制轮廓"


func _on_custom_outline_drawn(outline: PackedVector2Array) -> void:
	config.custom_outline = outline
	config.island_shape = MapGenerationConfig.IslandShape.CUSTOM
	config.naturalization = 0.0
	config.base_position = MapGenerationGeometry.find_custom_interior_point(config)
	shape_picker.select(MapGenerationConfig.IslandShape.CUSTOM)
	outline_button.text = "绘制轮廓"
	_refresh_controls()
	_refresh_preview()


func _on_custom_lake_drawn(lake: PackedVector2Array) -> void:
	var updated_lakes: Array[PackedVector2Array] = []
	updated_lakes.assign(config.custom_lakes)
	updated_lakes.append(lake)
	config.custom_lakes = updated_lakes
	config.emit_changed()
	_refresh_preview()


func _clear_drawings() -> void:
	preview.cancel_drawing()
	config.custom_outline = PackedVector2Array()
	config.custom_lakes.clear()
	if config.island_shape == MapGenerationConfig.IslandShape.CUSTOM:
		config.island_shape = MapGenerationConfig.IslandShape.CIRCLE
		shape_picker.select(MapGenerationConfig.IslandShape.CIRCLE)
	outline_button.text = "绘制轮廓"
	lake_button.text = "绘制湖泊"
	_refresh_preview()


func _randomize_outline() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	config.seed = rng.randi_range(0, 2147483647)
	seed_field.value = config.seed
	_refresh_preview()


func _randomize_resources() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	config.resource_seed = rng.randi_range(0, 2147483647)
	_refresh_preview()


func _randomize_base() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var lake_rng := RandomNumberGenerator.new()
	lake_rng.seed = config.seed
	var lakes := MapGenerationGeometry.generate_lakes(config, Vector2.ZERO, lake_rng)
	for _attempt in range(200):
		var candidate := Vector2(rng.randf_range(-config.island_size.x * 0.46, config.island_size.x * 0.46), rng.randf_range(-config.island_size.y * 0.46, config.island_size.y * 0.46))
		if MapGenerationGeometry.is_land(config, candidate, 5.0) and MapGenerationGeometry.lake_clearance(config, lakes, candidate) >= 5.0:
			config.base_position = candidate
			_set_slider("base_x", candidate.x)
			_set_slider("base_z", candidate.y)
			_refresh_preview()
			return
	push_warning("没有找到合适的随机据点位置；请增大岛屿或减小湖泊")


func _save_config() -> void:
	var error := ResourceSaver.save(config, CONFIG_PATH)
	if error == OK:
		print("地图配置已保存：", CONFIG_PATH)
	else:
		push_error("地图配置保存失败：" + error_string(error))


func _refresh_preview() -> void:
	if preview:
		preview.configure(config)
