extends Node3D


const VILLAGER_SCENE: PackedScene = preload("res://Scene/unit/villager.tscn")
const ENEMY_SCENE: PackedScene = preload("res://Scene/unit/enemy_base.tscn")
const SLIME_DATA: EnemyData = preload("res://data/enemies/raid/SlimeData.tres")

var level_config: LevelConfig = preload("res://data/levels/Level_01.tres")
@export var level_preset: LevelFlowData = preload("res://data/levels/LevelFlow_40min_Hard.tres")


func _enter_tree() -> void:
	var catalog := BuildingCatalog.new()
	catalog.name = "BuildingCatalog"
	add_child(catalog)
	$buildings/Base.set_building_data(preload("res://data/buildings/BaseData.tres"))
	if level_preset == null:
		return
	if level_preset.settlement_config != null:
		level_config = level_preset.settlement_config
	$Systems/PopulationManager.level_config = level_config
	$Systems/EncounterDirector.level_flow = level_preset
	$Systems/RiftManager.minimum_base_distance = level_preset.rift_min_base_distance
	var generator: MapGenerateRuntime = $Systems/MapGenerateRuntime
	if level_preset.map_config != null:
		generator.level_config = level_preset.map_config
	generator.resource_entries = level_preset.map_resources
	if generator.settlement_seed == -1:
		generator.settlement_seed = level_preset.layout_seed


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
@onready var raid_spawn_manager: RaidSpawnManager = $Systems/RaidSpawnManager
@onready var game_state: GameState = $Systems/GameState

var world_object_clicked: bool = false
var selected_object: Node3D = null
var selected_objects: Array[Node3D] = []
var road_manager: Node
var road_tool: Node
var selected_mesh_overlays: Dictionary = {}
var selection_outline_material: ShaderMaterial
var selected_building_range: MeshInstance3D
var selected_entrance_arrow: MeshInstance3D
var paused_game_commands: Array[Callable] = []
var enemy_placement_active: bool = false
var enemy_preview: Node3D = null
var prey_panel: PanelContainer
var loot_panel: PanelContainer
var camp_panel: PanelContainer
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
	var alarm := SettlementAlarm.new()
	alarm.name = "SettlementAlarm"
	$Systems.add_child(alarm)
	_create_selection_outline_material()
	camp_panel = preload("res://UI/camp_panel.gd").new()
	$UI.add_child(camp_panel)
	camp_panel.closed.connect(clear_selection)
	loot_panel = preload("res://UI/loot_panel.gd").new()
	$UI.add_child(loot_panel)
	loot_panel.closed.connect(clear_selection)
	prey_panel = preload("res://UI/prey_panel.gd").new()
	$UI.add_child(prey_panel)
	prey_panel.closed.connect(clear_selection)
	if level_preset != null and level_preset.camp_config != null:
		var camp_manager := CampSpawnManager.new()
		camp_manager.name = "CampSpawnManager"
		camp_manager.config = level_preset.camp_config
		$Systems.add_child(camp_manager)
	resource_building_panel.close_button.pressed.connect(_clear_selection_highlight)
	resource_building_panel.move_requested.connect(_on_building_move_requested)
	villager_panel.close_button.pressed.connect(_clear_selection_highlight)
	resource_node_panel.close_button.pressed.connect(_clear_selection_highlight)
	enemy_panel.close_button.pressed.connect(_clear_selection_highlight)

	_apply_level_config()
	road_manager = preload("res://Script/world/road_manager.gd").new()
	road_manager.name = "RoadManager"
	add_child(road_manager)
	road_tool = preload("res://Script/ui/road_tool.gd").new()
	road_tool.name = "RoadTool"
	road_tool.manager = road_manager
	add_child(road_tool)
	_spawn_initial_villagers()
	if level_preset != null and level_preset.wildlife_config != null:
		var wildlife := Node3D.new()
		wildlife.set_script(preload("res://Script/world/wildlife_manager.gd"))
		wildlife.name = "WildlifeManager"
		wildlife.config = level_preset.wildlife_config
		$Systems.add_child(wildlife)
	if level_preset != null and level_preset.fog_of_war_enabled:
		var fog := Node3D.new()
		fog.set_script(preload("res://Script/world/fog_of_war.gd"))
		fog.name = "FogOfWar"
		add_child(fog)
	if hud.has_method("connect_building_ghost"):
		hud.connect_building_ghost(building_ghost)
	if not hud.enemy_placement_requested.is_connected(_begin_enemy_placement):
		hud.enemy_placement_requested.connect(_begin_enemy_placement)
	if not hud.raid_requested.is_connected(_on_raid_requested):
		hud.raid_requested.connect(_on_raid_requested)
	if not hud.unreachable_villager_clicked.is_connected(_on_unreachable_villager_clicked):
		hud.unreachable_villager_clicked.connect(_on_unreachable_villager_clicked)

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
		if base.has_signal("destroyed") and not base.destroyed.is_connected(_on_base_destroyed):
			base.destroyed.connect(_on_base_destroyed)

	for resource: Node in get_tree().get_nodes_in_group("resources"):
		register_resource(resource)

	for enemy: Node in get_tree().get_nodes_in_group("enemies"):
		register_enemy(enemy)

	print("========== Main连接结束 ==========")


func _on_base_destroyed() -> void:
	if game_state == null or game_state.state == GameState.State.DEFEAT:
		return
	game_state.set_state(GameState.State.DEFEAT)
	get_tree().paused = true
	if hud.has_method("show_defeat_screen"):
		hud.show_defeat_screen()


func restart_game() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if (
			event.keycode == KEY_G
			and not building_ghost.is_placement_active()
			and road_tool.mode == 0
			and not enemy_placement_active
		):
			var building: BuildingBase = selected_object as BuildingBase
			if is_instance_valid(building) and building.can_be_moved():
				_on_building_move_requested(building)
				get_viewport().set_input_as_handled()
				return

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
	if is_instance_valid(selected_building_range) and selected_building_range.visible:
		if not is_instance_valid(selected_object) or selected_object.is_queued_for_deletion() or selected_object.get_meta("fog_hidden", false):
			selected_building_range.hide()
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


func show_resource_loss(source: Node3D, amount: float) -> void:
	if source == null or not is_instance_valid(source):
		return
	var text_manager: FloatingTextManager = get_node_or_null(
		"UI/FloatingTextManager"
	) as FloatingTextManager
	if text_manager != null:
		text_manager.show_resource_loss(source.global_position + Vector3.UP * 1.2, amount)


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


func _on_raid_requested() -> void:
	if raid_spawn_manager != null:
		raid_spawn_manager.spawn_raid()


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
	var on_death: Callable = _on_friendly_unit_died.bind(villager)
	if not villager.died.is_connected(on_death):
		villager.died.connect(on_death)


func _on_friendly_unit_died(_source: Node, unit: Node) -> void:
	if unit.get_faction() == EnemyData.Faction.SETTLEMENT:
		hud.show_friendly_death(unit.get_named_display_name())


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
	var on_death: Callable = _on_friendly_unit_died.bind(enemy)
	if enemy.health_component != null and not enemy.health_component.died.is_connected(on_death):
		enemy.health_component.died.connect(on_death)


func _spawn_initial_villagers() -> void:

	if level_config == null:
		return

	var bases = get_tree().get_nodes_in_group("bases")
	if bases.is_empty():
		return

	var base: Node3D = bases[0]

	for index in range(maxi(level_config.initial_villagers, 0)):
		var villager = VILLAGER_SCENE.instantiate()
		villager.leaving_immigration_base = true
		villagers_container.add_child(villager)
		villager.global_position = base.get_migrant_interior_position()
		villager.walk_out_of_immigration_base(base, index, level_config.initial_villagers)

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


func _on_building_move_requested(building: BuildingBase) -> void:
	road_tool.close()
	_cancel_enemy_placement()
	clear_selection()
	building_ghost.select_moving_building(building)


func _on_villager_clicked(villager: UnitBase) -> void:
	world_object_clicked = true
	hud.set_debug_villager(villager)
	_clear_selection_highlight()
	_close_selection_panels_immediately()
	_select_world_object(villager)
	call_deferred("_open_villager_panel", villager)


func _on_unreachable_villager_clicked(villager: UnitBase) -> void:
	if not is_instance_valid(villager):
		return
	var camera: GameCameraController = get_viewport().get_camera_3d() as GameCameraController
	if camera != null:
		camera.focus_on_position(villager.global_position)
	_on_villager_clicked(villager)


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


func register_prey(prey: Node3D) -> void:
	prey.prey_clicked.connect(_on_prey_clicked)


func _on_prey_clicked(prey: Node3D) -> void:
	if bool(prey.get_meta("fog_hidden", false)) or prey.is_queued_for_deletion():
		return
	world_object_clicked = true
	hud.set_debug_villager(null)
	_clear_selection_highlight()
	_close_selection_panels_immediately()
	_select_world_object(prey)
	prey_panel.open_prey(prey)


func register_loot_bundle(bundle: LootBundle) -> void:
	bundle.loot_clicked.connect(_on_loot_bundle_clicked)


func _on_loot_bundle_clicked(bundle: LootBundle) -> void:
	if bool(bundle.get_meta("fog_hidden", false)) or bundle.is_queued_for_deletion():
		return
	world_object_clicked = true
	hud.set_debug_villager(null)
	_clear_selection_highlight()
	_close_selection_panels_immediately()
	_select_world_object(bundle)
	loot_panel.open_bundle(bundle)


func register_treasure_camp(camp: TreasureCamp) -> void:
	camp.camp_clicked.connect(_on_treasure_camp_clicked)


func _on_treasure_camp_clicked(camp: TreasureCamp) -> void:
	if bool(camp.get_meta("fog_hidden", false)):
		return
	world_object_clicked = true
	hud.set_debug_villager(null)
	_clear_selection_highlight()
	_close_selection_panels_immediately()
	_select_world_object(camp)
	camp_panel.open_camp(camp)


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
	camp_panel.hide()
	loot_panel.hide()
	prey_panel.hide()
	resource_building_panel.close_panel_immediately()
	villager_panel.close_panel_immediately()
	resource_node_panel.close_panel_immediately()
	enemy_panel.close_panel_immediately()


func clear_selection() -> void:
	camp_panel.hide()
	loot_panel.hide()
	prey_panel.hide()
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
	if is_instance_valid(selected_entrance_arrow): selected_entrance_arrow.queue_free()
	selected_entrance_arrow = null
	if target is BuildingBase and not target is ConstructionSite and not (target.building_data != null and (target.building_data.is_wall() or target.building_data.is_wall_tower())):
		var entrance: Vector3 = target.to_local(target.get_entrance_position())
		selected_entrance_arrow = BuildingBase.create_entrance_arrow(entrance, BuildingBase.get_entrance_footprint(target))
		target.add_child(selected_entrance_arrow)
	_show_selected_building_range(target)
	selected_objects = [target]
	if bool(target.get_meta("selection_double_click", false)):
		target.remove_meta("selection_double_click")
		var group: String = "buildings" if target is BuildingBase else "villagers"
		for candidate: Node3D in get_tree().get_nodes_in_group(group):
			if candidate == target or candidate.is_queued_for_deletion() or not candidate.is_visible_in_tree() or candidate.get_meta("fog_hidden", false): continue
			if target is BuildingBase:
				if target.building_data == null or candidate.building_data == null or target.building_data.id != candidate.building_data.id or (target is ConstructionSite) != (candidate is ConstructionSite): continue
			elif candidate.unit_data != target.unit_data or candidate.job != target.job: continue
			selected_objects.append(candidate)
	for object: Node3D in selected_objects:
		_highlight_selected_object(object)


func _highlight_selected_object(target: Node3D) -> void:
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
		if target is TreasureCamp and mesh_instance.name == "AggroRange":
			continue
		selected_mesh_overlays[mesh_instance] = mesh_instance.material_overlay
		mesh_instance.material_overlay = selection_outline_material


func _show_selected_building_range(target: Node3D) -> void:
	if is_instance_valid(selected_building_range):
		selected_building_range.hide()
	var radius: float = 0.0
	var center: Vector3 = target.global_position
	var color := Color(0.25, 0.7, 1.0, 0.85)
	if target.has_method("allows_garrison_attacks"):
		radius = target.alarm_radius
		color = Color(0.3, 1.0, 0.4, 0.85)
	elif target is ResourceBuildingBase:
		radius = target.idle_radius if target is Farm else target.work_radius
		if not target is Farm:
			color = Color(0.3, 1.0, 0.4, 0.85)
		if target.get_script() == preload("res://Script/building/game/hunter_hut.gd"):
			var base: Node3D = get_tree().get_first_node_in_group("bases") as Node3D
			if is_instance_valid(base):
				center = base.global_position
	elif target.is_in_group("bases"):
		radius = target.idle_radius
	if radius <= 0.0:
		return
	if not is_instance_valid(selected_building_range):
		selected_building_range = MeshInstance3D.new()
		selected_building_range.name = "SelectedBuildingRange"
		selected_building_range.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(selected_building_range)
	var ring := TorusMesh.new()
	ring.inner_radius = maxf(radius - 0.08, 0.01)
	ring.outer_radius = radius
	ring.rings = 128
	ring.ring_segments = 8
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.no_depth_test = true
	material.albedo_color = color
	ring.material = material
	selected_building_range.mesh = ring
	selected_building_range.global_position = center + Vector3.UP * 0.1
	selected_building_range.show()


func _clear_selection_highlight() -> void:
	if is_instance_valid(selected_entrance_arrow): selected_entrance_arrow.queue_free()
	selected_entrance_arrow = null
	if is_instance_valid(selected_building_range):
		selected_building_range.hide()
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
	selected_objects.clear()
	selected_object = null
