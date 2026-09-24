@tool
extends EditorProperty

const RESOURCE_DATABASE: ResourceDatabase = preload(
	"res://data/resources/resource_database.tres"
)

var resource_option: OptionButton


func configure_choice(property: String, label: String, choice_kind: String) -> void:
	set_label(label)
	resource_option = OptionButton.new()
	resource_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_add_option("随机（不指定）", &"")
	match choice_kind:
		"resource":
			for resource_data: ResourceData in RESOURCE_DATABASE.resources:
				if resource_data == null or resource_data.id.is_empty():
					continue
				_add_option(
					"%s（%s）" % [resource_data.display_name, resource_data.id],
					resource_data.id
				)
		"building":
			_add_option("据点", &"base")
			var building_files: PackedStringArray = DirAccess.get_files_at("res://data/buildings")
			building_files.sort()
			for file_name: String in building_files:
				if not file_name.ends_with(".tres"):
					continue
				var building_data: BuildingData = load(
					"res://data/buildings/" + file_name
				) as BuildingData
				if building_data != null and not building_data.id.is_empty():
					_add_option(
						"%s（%s）" % [building_data.display_name, building_data.id],
						building_data.id
					)
		"unit":
			_add_option("居民", &"villager")
			_add_option("剑士", &"swordsman")
			for folder: String in ["raid", "rift"]:
				var enemy_files: PackedStringArray = DirAccess.get_files_at(
					"res://data/enemies/" + folder
				)
				enemy_files.sort()
				for file_name: String in enemy_files:
					if not file_name.ends_with(".tres"):
						continue
					var enemy_data: EnemyData = load(
						"res://data/enemies/%s/%s" % [folder, file_name]
					) as EnemyData
					if enemy_data != null and not enemy_data.id.is_empty():
						_add_option(
							"%s（%s）" % [enemy_data.display_name, enemy_data.id],
							enemy_data.id
						)
	add_child(resource_option)
	add_focusable(resource_option)
	resource_option.item_selected.connect(_on_option_selected)


func configure_objective() -> void:
	set_label("袭扰行为")
	resource_option = OptionButton.new()
	resource_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	resource_option.add_item("无")
	resource_option.add_item("击杀单位")
	resource_option.add_item("破坏建筑")
	resource_option.add_item("偷取资源")
	for index: int in range(resource_option.item_count):
		resource_option.set_item_metadata(index, index)
	add_child(resource_option)
	add_focusable(resource_option)
	resource_option.item_selected.connect(_on_objective_selected)


func _add_option(label: String, value: StringName) -> void:
	resource_option.add_item(label)
	resource_option.set_item_metadata(resource_option.item_count - 1, value)


func _update_property() -> void:
	var selected_id: Variant = get_edited_object().get(get_edited_property())
	for index: int in range(resource_option.item_count):
		if resource_option.get_item_metadata(index) == selected_id:
			resource_option.select(index)
			return
	resource_option.select(0)


func _on_option_selected(index: int) -> void:
	emit_changed(
		get_edited_property(),
		resource_option.get_item_metadata(index)
	)


func _on_objective_selected(index: int) -> void:
	emit_changed(get_edited_property(), index)
	call_deferred("_refresh_inspector")


func _refresh_inspector() -> void:
	var edited_object: Object = get_edited_object()
	if is_instance_valid(edited_object):
		edited_object.notify_property_list_changed()
