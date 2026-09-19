extends Node3D


const VILLAGER_SCENE: PackedScene = preload("res://Scene/unit/villager.tscn")

@export var level_config: LevelConfig = preload("res://data/levels/Level_01.tres")


# ============================================================
# UI
# ============================================================

@onready var resource_building_panel: ResourceBuildingPanel = \
	$UI/ResourceBuildingPanel
@onready var hud: GameHUD = $UI/HUD
@onready var building_ghost: BuildingGhost = $Systems/BuildingGhost
@onready var villagers_container: Node = $Villagers


# ============================================================
# 初始化
# ============================================================

func _ready():

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

	print("========== Main连接结束 ==========")


func _unhandled_input(event: InputEvent) -> void:
	if not DevMode.DEV_MODE:
		return

	if not (
		event is InputEventKey
		and event.pressed
		and not event.echo
		and event.keycode == KEY_H
	):
		return

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
	get_viewport().set_input_as_handled()


func register_building(building: Node) -> void:
	if building == null or not building.has_signal("building_clicked"):
		return

	if not building.building_clicked.is_connected(_on_resource_building_clicked):
		print("🔗 连接建筑点击信号：", building.name)
		building.building_clicked.connect(_on_resource_building_clicked)


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

	print("📨 Main收到建筑点击：", building.name)
	print("📺 UI对象：", resource_building_panel)

	resource_building_panel.open_building(building)
