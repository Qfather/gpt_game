@tool
extends HSplitContainer

const LABELS: Dictionary = {
	"camp": "营地方案", "weight": "抽取权重", "start_time": "允许出现的开始时间（秒）",
	"end_time": "结束时间（秒，-1 不限）", "display_name": "营地名称", "scene": "营地场景（空为默认）",
	"footprint_radius": "营地占地半径（米）", "guard_leash_radius": "守卫活动半径（米）",
	"guard_health_regen": "守卫回营后每秒回血量（生命/秒，0关闭）",
	"minimum_guards": "守卫最小数量", "maximum_guards": "守卫最大数量", "guard_pool": "守卫随机池",
	"enemy": "怪物数据", "reward_draws": "奖励抽取次数（可重复累加）", "reward_pool": "奖励随机池",
	"resource": "奖励资源", "minimum_amount": "每次最小数量", "maximum_amount": "每次最大数量"
}

var preset: LevelFlowData
var enabled: CheckBox
var controls: Dictionary = {}
var pool_list: ItemList
var inspector: EditorInspector
var translate_timer: float = 0.0


func _init() -> void:
	var settings := VBoxContainer.new()
	settings.custom_minimum_size.x = 330.0
	add_child(settings)
	enabled = CheckBox.new()
	enabled.text = "启用营地生成"
	enabled.toggled.connect(func(value: bool) -> void:
		if preset != null:
			preset.camp_config.enabled = value
	)
	settings.add_child(enabled)
	_add_spin(settings, "首次刷新等待（秒）", "first_spawn_time", 0, 86400, 1)
	_add_spin(settings, "刷新最小间隔（秒）", "interval_min", 1, 86400, 1)
	_add_spin(settings, "刷新最大间隔（秒）", "interval_max", 1, 86400, 1)
	_add_spin(settings, "同时存在营地上限", "maximum_camps", 1, 20, 1)
	_add_spin(settings, "距据点最小距离（米）", "minimum_base_distance", 0, 1000, 1)
	_add_spin(settings, "距据点最大距离（米）", "maximum_base_distance", 1, 1000, 1)
	_add_spin(settings, "营地之间边缘留空（米）", "camp_spacing", 0, 100, 0.5)
	var help := Label.new()
	help.text = "仅在当前无视野区域刷新，包括已探索区域。\n内容按生成时的关卡时间抽取，此后固定。\n首次计时等待地图、导航和迷雾就绪。"
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	settings.add_child(help)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(column)
	var toolbar := HBoxContainer.new()
	column.add_child(toolbar)
	_button(toolbar, "添加营地", _add_entry)
	_button(toolbar, "移除选中项", _remove_entry)
	_button(toolbar, "复制方案为本关独有", _make_local)
	pool_list = ItemList.new()
	pool_list.custom_minimum_size.y = 95
	pool_list.item_selected.connect(_select_entry)
	column.add_child(pool_list)
	var hint := Label.new()
	hint.text = "展开营地方案编辑奖励和守卫池；权重是相对抽取权重。\n保存关卡会同时保存引用的营地配置与方案；仅改本关请先复制为本关独有。"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(hint)
	inspector = EditorInspector.new()
	inspector.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(inspector)


func _add_spin(parent: Node, caption: String, property: String, minimum: float, maximum: float, step: float) -> void:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var label := Label.new()
	label.text = caption
	label.custom_minimum_size.x = 200.0
	row.add_child(label)
	var spin := SpinBox.new()
	spin.min_value = minimum
	spin.max_value = maximum
	spin.step = step
	spin.value_changed.connect(func(value: float) -> void:
		if preset != null:
			preset.camp_config.set(property, int(value) if property == "maximum_camps" else value)
	)
	row.add_child(spin)
	controls[property] = spin


func _button(parent: Node, caption: String, action: Callable) -> void:
	var button := Button.new()
	button.text = caption
	button.pressed.connect(action)
	parent.add_child(button)


func edit_preset(value: LevelFlowData) -> void:
	inspector.edit(null)
	preset = value
	if preset.camp_config == null:
		preset.camp_config = CampSpawnConfig.new()
	enabled.set_pressed_no_signal(preset.camp_config.enabled)
	for property: String in controls:
		controls[property].set_value_no_signal(float(preset.camp_config.get(property)))
	_refresh_list()
	if pool_list.item_count > 0:
		pool_list.select(0)
		_select_entry(0)


func _refresh_list() -> void:
	pool_list.clear()
	for entry: CampPoolEntry in preset.camp_config.camp_pool:
		pool_list.add_item(entry.camp.display_name if entry != null and entry.camp != null else "空营地方案")


func _select_entry(index: int) -> void:
	inspector.edit(preset.camp_config.camp_pool[index])


func _add_entry() -> void:
	var entry := CampPoolEntry.new()
	entry.camp = TreasureCampData.new()
	var guard := CampGuardEntry.new()
	guard.enemy = preload("res://data/enemies/raid/SlimeData.tres")
	entry.camp.guard_pool.append(guard)
	var reward := CampRewardEntry.new()
	reward.resource = preload("res://data/resources/wood.tres")
	entry.camp.reward_pool.append(reward)
	preset.camp_config.camp_pool.append(entry)
	_refresh_list()
	pool_list.select(pool_list.item_count - 1)
	_select_entry(pool_list.item_count - 1)


func _remove_entry() -> void:
	var selected: PackedInt32Array = pool_list.get_selected_items()
	if selected.is_empty():
		return
	inspector.edit(null)
	preset.camp_config.camp_pool.remove_at(selected[0])
	_refresh_list()


func _make_local() -> void:
	var selected: PackedInt32Array = pool_list.get_selected_items()
	if selected.is_empty():
		return
	if not preset.camp_config.resource_path.is_empty() and not preset.camp_config.resource_path.contains("::"):
		preset.camp_config = preset.camp_config.duplicate(false) as CampSpawnConfig
		var entries: Array[CampPoolEntry] = []
		for item: CampPoolEntry in preset.camp_config.camp_pool:
			entries.append(item.duplicate(false) as CampPoolEntry)
		preset.camp_config.camp_pool = entries
	var entry: CampPoolEntry = preset.camp_config.camp_pool[selected[0]].duplicate(false) as CampPoolEntry
	var data: TreasureCampData = entry.camp.duplicate(false) as TreasureCampData
	data.guard_pool = []
	for guard: CampGuardEntry in entry.camp.guard_pool:
		data.guard_pool.append(guard.duplicate(false) as CampGuardEntry)
	data.reward_pool = []
	for reward: CampRewardEntry in entry.camp.reward_pool:
		data.reward_pool.append(reward.duplicate(false) as CampRewardEntry)
	entry.camp = data
	preset.camp_config.camp_pool[selected[0]] = entry
	_select_entry(selected[0])


func _process(delta: float) -> void:
	if not is_visible_in_tree() or preset == null:
		return
	translate_timer += delta
	if translate_timer < 0.5:
		return
	translate_timer = 0.0
	_translate(inspector)
	for index: int in range(pool_list.item_count):
		var entry: CampPoolEntry = preset.camp_config.camp_pool[index]
		pool_list.set_item_text(index, entry.camp.display_name if entry != null and entry.camp != null else "空营地方案")


func _translate(node: Node) -> void:
	if node is EditorProperty and LABELS.has(node.get_edited_property()):
		node.label = LABELS[node.get_edited_property()]
	for child: Node in node.get_children(true):
		_translate(child)
