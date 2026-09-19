extends Node3D


const VILLAGER_SCENE: PackedScene = preload("res://Scene/unit/villager.tscn")

@export var level_config: LevelConfig = preload("res://data/levels/Level_01.tres")


# ============================================================
# UI
# ============================================================

@onready var resource_building_panel: ResourceBuildingPanel = \
	$UI/ResourceBuildingPanel
@onready var villager_panel: VillagerPanel = $UI/VillagerPanel
@onready var resource_node_panel: ResourceNodePanel = $UI/ResourceNodePanel
@onready var hud: GameHUD = $UI/HUD
@onready var building_ghost: BuildingGhost = $Systems/BuildingGhost
@onready var villagers_container: Node = $Villagers

var world_object_clicked: bool = false
var selected_object: Node3D = null
var selected_mesh_overlays: Dictionary = {}
var selection_outline_material: ShaderMaterial


# ============================================================
# 初始化
# ============================================================

func _ready():
	_create_selection_outline_material()
	resource_building_panel.close_button.pressed.connect(_clear_selection_highlight)
	villager_panel.close_button.pressed.connect(_clear_selection_highlight)
	resource_node_panel.close_button.pressed.connect(_clear_selection_highlight)

	_apply_level_config()
	_spawn_initial_villagers()
	if hud.has_method("connect_building_ghost"):
		hud.connect_building_ghost(building_ghost)

	print("========== Main启动 ==========")

	var buildings = get_tree().get_nodes_in_group(
		"resource_buildings"
	)

	print("🏭 找到资源建筑数量：", buildings.size())

	for building in buildings:

		print("🏭 找到建筑：", building.name)

		register_building(building)

	for base: Node in get_tree().get_nodes_in_group("bases"):
		register_building(base)

	for resource: Node in get_tree().get_nodes_in_group("resources"):
		register_resource(resource)

	print("========== Main连接结束 ==========")


func _unhandled_input(event: InputEvent) -> void:
	if (
		event is InputEventKey
		and event.pressed
		and not event.echo
		and event.keycode == KEY_H
	):
		if DevMode.DEV_MODE:
			_debug_add_wood()
			get_viewport().set_input_as_handled()
		return

	if (
		event is InputEventMouseButton
		and event.pressed
		and event.button_index == MOUSE_BUTTON_LEFT
	):
		if building_ghost.is_placement_active():
			return
		world_object_clicked = false
		call_deferred("_clear_selection_if_world_empty")


func _clear_selection_if_world_empty() -> void:
	if not world_object_clicked:
		clear_selection()
	world_object_clicked = false


func _debug_add_wood() -> void:
	var bases: Array[Node] = get_tree().get_nodes_in_group("bases")
	if bases.is_empty():
		return

	var base: Node = bases[0]
	if not base.has_method("add_resource") or not base.has_method("get_resource"):
		return

	var added_amount: float = base.add_resource(
		ResourceType.Type.WOOD,
		10.0
	)
	print(
		"快捷测试：增加木材 ",
		added_amount,
		"，据点当前木材：",
		base.get_resource(ResourceType.Type.WOOD)
	)


func register_building(building: Node) -> void:
	if building == null or not building.has_signal("building_clicked"):
		return

	if not building.building_clicked.is_connected(_on_resource_building_clicked):
		print("🔗 连接建筑点击信号：", building.name)
		building.building_clicked.connect(_on_resource_building_clicked)


func register_villager(villager: Node) -> void:
	if villager == null or not villager.has_signal("unit_clicked"):
		return
	if not villager.unit_clicked.is_connected(_on_villager_clicked):
		villager.unit_clicked.connect(_on_villager_clicked)


func register_resource(resource: Node) -> void:
	if resource == null or not resource.has_signal("resource_clicked"):
		return
	if not resource.resource_clicked.is_connected(_on_resource_clicked):
		resource.resource_clicked.connect(_on_resource_clicked)


func _spawn_initial_villagers() -> void:

	if level_config == null:
		return

	var bases = get_tree().get_nodes_in_group("bases")
	if bases.is_empty():
		return

	var base: Node3D = bases[0]
	var spawn_origin: Vector3 = base.global_position

	for index in range(maxi(level_config.initial_villagers, 0)):
		var villager = VILLAGER_SCENE.instantiate()
		villagers_container.add_child(villager)

		var resource_manager = get_tree().get_first_node_in_group(
			"resource_manager"
		)
		if resource_manager != null:
			resource_manager.register_villager(villager)
		register_villager(villager)

		var column: int = index % 3
		var row: int = index / 3
		villager.global_position = spawn_origin + Vector3(
			float(column - 1) * 1.5,
			0.0,
			float(row + 1) * 1.5
		)


func _apply_level_config() -> void:

	if level_config == null:
		push_error("Main：没有找到 LevelConfig")
		return

	var bases = get_tree().get_nodes_in_group("bases")
	if bases.is_empty():
		push_error("Main：没有找到 Base")
		return

	var base = bases[0]
	if not base.has_method("add_resource"):
		push_error("Main：Base 不支持资源接口")
		return

	base.add_resource(
		ResourceType.Type.WOOD,
		level_config.initial_wood
	)
	base.add_resource(
		ResourceType.Type.STONE,
		level_config.initial_stone
	)


# ============================================================
# 点击资源建筑
# ============================================================

func _on_resource_building_clicked(building):
	world_object_clicked = true

	print("📨 Main收到建筑点击：", building.name)
	print("📺 UI对象：", resource_building_panel)

	_clear_selection_highlight()
	villager_panel.close_panel()
	resource_node_panel.close_panel()
	_select_world_object(building as Node3D)
	call_deferred("_open_resource_building_panel", building)


func _on_villager_clicked(villager: UnitBase) -> void:
	world_object_clicked = true
	_clear_selection_highlight()
	resource_building_panel.close_panel()
	resource_node_panel.close_panel()
	_select_world_object(villager)
	call_deferred("_open_villager_panel", villager)


func _on_resource_clicked(resource: ResourceBase) -> void:
	world_object_clicked = true
	_clear_selection_highlight()
	resource_building_panel.close_panel()
	villager_panel.close_panel()
	_select_world_object(resource)
	call_deferred("_open_resource_node_panel", resource)


func _open_resource_building_panel(building: Node) -> void:
	if is_instance_valid(building):
		resource_building_panel.open_building(building)


func _open_villager_panel(villager: UnitBase) -> void:
	if is_instance_valid(villager):
		villager_panel.open_unit(villager)


func _open_resource_node_panel(resource: ResourceBase) -> void:
	if is_instance_valid(resource):
		resource_node_panel.open_building(resource)


func clear_selection() -> void:
	_clear_selection_highlight()
	resource_building_panel.close_panel()
	villager_panel.close_panel()
	resource_node_panel.close_panel()


func _create_selection_outline_material() -> void:
	var outline_shader: Shader = Shader.new()
	outline_shader.code = """
shader_type spatial;
render_mode unshaded, cull_front;

uniform vec4 outline_color : source_color = vec4(1.0, 0.82, 0.15, 1.0);
uniform float outline_size = 0.06;

void vertex() {
	VERTEX += NORMAL * outline_size;
}

void fragment() {
	ALBEDO = outline_color.rgb;
	EMISSION = outline_color.rgb;
}
"""
	selection_outline_material = ShaderMaterial.new()
	selection_outline_material.shader = outline_shader


func _select_world_object(target: Node3D) -> void:
	if not is_instance_valid(target):
		return

	selected_object = target
	var mesh_nodes: Array[Node] = target.find_children(
		"*",
		"MeshInstance3D",
		true,
		false
	)
	for mesh_node: Node in mesh_nodes:
		var mesh_instance: MeshInstance3D = mesh_node as MeshInstance3D
		if mesh_instance == null:
			continue
		selected_mesh_overlays[mesh_instance] = mesh_instance.material_overlay
		mesh_instance.material_overlay = selection_outline_material


func _clear_selection_highlight() -> void:
	for mesh_variant: Variant in selected_mesh_overlays.keys():
		var mesh_instance: MeshInstance3D = mesh_variant as MeshInstance3D
		if is_instance_valid(mesh_instance):
			mesh_instance.material_overlay = (
				selected_mesh_overlays[mesh_variant] as Material
			)
	selected_mesh_overlays.clear()
	selected_object = null
