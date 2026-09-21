extends Node3D


const VILLAGER_SCENE: PackedScene = preload("res://Scene/unit/villager.tscn")
const ENEMY_SCENE: PackedScene = preload("res://Scene/unit/enemy_base.tscn")
const SLIME_DATA: EnemyData = preload("res://data/combat/SlimeData.tres")

@export var level_config: LevelConfig = preload("res://data/levels/Level_01.tres")


# ============================================================
# UI
# ============================================================

@onready var resource_building_panel: ResourceBuildingPanel = \
	$UI/ResourceBuildingPanel
@onready var villager_panel: VillagerPanel = $UI/VillagerPanel
@onready var resource_node_panel: ResourceNodePanel = $UI/ResourceNodePanel
@onready var enemy_panel: EnemyPanel = $UI/EnemyPanel
@onready var hud: GameHUD = $UI/HUD
@onready var building_ghost: BuildingGhost = $Systems/BuildingGhost
@onready var villagers_container: Node = $Villagers
@onready var enemies_container: Node = $Enemies

var world_object_clicked: bool = false
var selected_object: Node3D = null
var selected_mesh_overlays: Dictionary = {}
var selection_outline_material: ShaderMaterial
var paused_game_commands: Array[Callable] = []
var enemy_placement_active: bool = false
var enemy_preview: Node3D = null
var enemy_placement_data: EnemyData = SLIME_DATA


func execute_game_command(command: Callable) -> void:
	if get_tree().paused:
		paused_game_commands.append(command)
		print("游戏暂停，操作已排队，当前队列：", paused_game_commands.size())
		return
	command.call()


func flush_paused_game_commands() -> void:
	var commands: Array[Callable] = paused_game_commands.duplicate()
	paused_game_commands.clear()
	for command: Callable in commands:
		if command.is_valid():
			command.call()


# ============================================================
# 初始化
# ============================================================

func _ready():
	_create_selection_outline_material()
	resource_building_panel.close_button.pressed.connect(_clear_selection_highlight)
	villager_panel.close_button.pressed.connect(_clear_selection_highlight)
	resource_node_panel.close_button.pressed.connect(_clear_selection_highlight)
	enemy_panel.close_button.pressed.connect(_clear_selection_highlight)

	_apply_level_config()
	_spawn_initial_villagers()
	if hud.has_method("connect_building_ghost"):
		hud.connect_building_ghost(building_ghost)
	if not hud.enemy_placement_requested.is_connected(_begin_enemy_placement):
		hud.enemy_placement_requested.connect(_begin_enemy_placement)

	print("========== Main启动 ==========")

	var buildings = get_tree().get_nodes_in_group(
		"resource_buildings"
	)

	print("🏭 找到资源建筑数量：", buildings.size())

	for building in buildings:

		print("🏭 找到建筑：", building.name)

		register_building(building)

	for building: Node in get_tree().get_nodes_in_group("buildings"):
		register_building(building)

	for base: Node in get_tree().get_nodes_in_group("bases"):
		register_building(base)

	for resource: Node in get_tree().get_nodes_in_group("resources"):
		register_resource(resource)

	for enemy: Node in get_tree().get_nodes_in_group("enemies"):
		register_enemy(enemy)

	print("========== Main连接结束 ==========")


func _unhandled_input(event: InputEvent) -> void:
	if enemy_placement_active:
		if event is InputEventKey and event.pressed and not event.echo:
			if event.keycode == KEY_ESCAPE:
				_cancel_enemy_placement()
				get_viewport().set_input_as_handled()
				return
		if event is InputEventMouseButton and event.pressed:
			var enemy_mouse_event: InputEventMouseButton = event as InputEventMouseButton
			if enemy_mouse_event.button_index == MOUSE_BUTTON_LEFT:
				_place_enemy_at_mouse()
				get_viewport().set_input_as_handled()
				return
			if enemy_mouse_event.button_index == MOUSE_BUTTON_RIGHT:
				_cancel_enemy_placement()
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


func _process(_delta: float) -> void:
	if enemy_placement_active:
		_update_enemy_preview()


func _begin_enemy_placement(enemy_data: EnemyData) -> void:
	if enemy_data == null:
		return
	enemy_placement_data = enemy_data
	if building_ghost.is_placement_active():
		building_ghost.cancel_preview()
	_clear_selection_highlight()
	_close_selection_panels_immediately()
	if is_instance_valid(enemy_preview):
		enemy_preview.free()
	enemy_preview = _create_enemy_preview()
	add_child(enemy_preview)
	enemy_placement_active = true
	hud.set_enemy_placement_active(true)
	_update_enemy_preview()


func _create_enemy_preview() -> Node3D:
	var preview: Node3D = Node3D.new()
	preview.name = "EnemyPlacementPreview"
	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	var mesh: SphereMesh = SphereMesh.new()
	mesh.radius = 0.6
	mesh.height = 1.2
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.2, 0.9, 0.35, 0.5)
	mesh.material = material
	mesh_instance.mesh = mesh
	preview.add_child(mesh_instance)
	return preview


func _update_enemy_preview() -> void:
	if not is_instance_valid(enemy_preview):
		return
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null:
		enemy_preview.visible = false
		return
	var world_position: Vector3 = _get_mouse_ground_position(camera)
	if world_position == Vector3.INF:
		enemy_preview.visible = false
		return
	enemy_preview.global_position = world_position + Vector3.UP * 0.6
	enemy_preview.visible = true


func _place_enemy_at_mouse() -> void:
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null:
		return
	var world_position: Vector3 = _get_mouse_ground_position(camera)
	if world_position == Vector3.INF:
		return
	var enemy: Node3D = ENEMY_SCENE.instantiate() as Node3D
	if enemy == null:
		return
	enemy.set("enemy_data", enemy_placement_data)
	enemies_container.add_child(enemy)
	enemy.global_position = world_position + Vector3.UP * 0.6
	print("调试放置史莱姆：", enemy.global_position)
	_cancel_enemy_placement()


func _get_mouse_ground_position(camera: Camera3D) -> Vector3:
	var mouse_position: Vector2 = get_viewport().get_mouse_position()
	var ray_origin: Vector3 = camera.project_ray_origin(mouse_position)
	var ray_direction: Vector3 = camera.project_ray_normal(mouse_position)
	if absf(ray_direction.y) < 0.001:
		return Vector3.INF
	var distance: float = -ray_origin.y / ray_direction.y
	if distance < 0.0:
		return Vector3.INF
	return ray_origin + ray_direction * distance


func _cancel_enemy_placement() -> void:
	if is_instance_valid(enemy_preview):
		enemy_preview.queue_free()
		enemy_preview = null
	enemy_placement_active = false
	hud.set_enemy_placement_active(false)


func _clear_selection_if_world_empty() -> void:
	if not world_object_clicked:
		clear_selection()
	world_object_clicked = false


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


func register_enemy(enemy: Node) -> void:
	if enemy == null or not enemy.has_signal("enemy_clicked"):
		return
	if not enemy.enemy_clicked.is_connected(_on_enemy_clicked):
		enemy.enemy_clicked.connect(_on_enemy_clicked)


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
		var population_manager = get_tree().get_first_node_in_group(
			"population_manager"
		)
		if population_manager != null:
			population_manager.register_villager(villager)
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
		&"wood",
		level_config.initial_wood
	)
	base.add_resource(
		&"stone",
		level_config.initial_stone
	)
	base.add_resource(
		&"grain",
		level_config.initial_grain
	)


# ============================================================
# 点击资源建筑
# ============================================================

func _on_resource_building_clicked(building):
	world_object_clicked = true
	hud.set_debug_villager(null)

	print("📨 Main收到建筑点击：", building.name)
	print("📺 UI对象：", resource_building_panel)

	_clear_selection_highlight()
	_close_selection_panels_immediately()
	_select_world_object(building as Node3D)
	call_deferred("_open_resource_building_panel", building)


func _on_villager_clicked(villager: UnitBase) -> void:
	world_object_clicked = true
	hud.set_debug_villager(villager)
	_clear_selection_highlight()
	_close_selection_panels_immediately()
	_select_world_object(villager)
	call_deferred("_open_villager_panel", villager)


func _on_resource_clicked(resource: ResourceBase) -> void:
	world_object_clicked = true
	hud.set_debug_villager(null)
	_clear_selection_highlight()
	_close_selection_panels_immediately()
	_select_world_object(resource)
	call_deferred("_open_resource_node_panel", resource)


func _on_enemy_clicked(enemy: EnemyBase) -> void:
	world_object_clicked = true
	hud.set_debug_villager(null)
	_clear_selection_highlight()
	_close_selection_panels_immediately()
	_select_world_object(enemy)
	call_deferred("_open_enemy_panel", enemy)


func _open_resource_building_panel(building: Node) -> void:
	if is_instance_valid(building):
		resource_building_panel.open_building(building)


func _open_villager_panel(villager: UnitBase) -> void:
	if is_instance_valid(villager):
		villager_panel.open_unit(villager)


func _open_resource_node_panel(resource: ResourceBase) -> void:
	if is_instance_valid(resource):
		resource_node_panel.open_building(resource)


func _open_enemy_panel(enemy: EnemyBase) -> void:
	if is_instance_valid(enemy):
		enemy_panel.open_building(enemy)


func _close_selection_panels_immediately() -> void:
	resource_building_panel.close_panel_immediately()
	villager_panel.close_panel_immediately()
	resource_node_panel.close_panel_immediately()
	enemy_panel.close_panel_immediately()


func clear_selection() -> void:
	_clear_selection_highlight()
	hud.set_debug_villager(null)
	resource_building_panel.close_panel()
	villager_panel.close_panel()
	resource_node_panel.close_panel()
	enemy_panel.close_panel()


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
		if not is_instance_valid(mesh_variant):
			continue

		var mesh_instance: MeshInstance3D = mesh_variant as MeshInstance3D
		if mesh_instance == null:
			continue

		mesh_instance.material_overlay = (
			selected_mesh_overlays[mesh_variant] as Material
		)
	selected_mesh_overlays.clear()
	selected_object = null
