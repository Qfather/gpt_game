extends Node

var manager: Node
var main: Node
var ghost: BuildingGhost
var panel: PanelContainer
var status: Label
var upgrade_button: Button
var mode: int = 0
var all_selected: bool = false
var dragging: bool = false
var drag_start: Vector2i
var preview: MeshInstance3D
var preview_material: StandardMaterial3D
var stroke: Array[Vector2i] = []
var mouse_position: Vector2 = Vector2.INF

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	main = get_parent()
	ghost = main.get_node("Systems/BuildingGhost")
	_create_panel()
	preview = MeshInstance3D.new()
	preview.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	preview_material = StandardMaterial3D.new()
	preview_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	preview_material.vertex_color_use_as_albedo = true
	preview.material_override = preview_material
	main.add_child(preview)
	preview.hide()
	manager.roads_changed.connect(_refresh_status)
	var resources: Node = get_tree().get_first_node_in_group("resource_manager")
	if resources != null: resources.resources_changed.connect(_refresh_status)
	main.hud.road_requested.connect(open)
	main.hud.build_requested.connect(func(_data: BuildingData) -> void: close())
	main.hud.enemy_placement_requested.connect(func(_data: EnemyData) -> void: close())
	set_process(false)

func _button(row: HBoxContainer, text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(callback)
	row.add_child(button)
	return button

func _create_panel() -> void:
	panel = PanelContainer.new()
	panel.name = "RoadPanel"
	main.hud.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	panel.offset_left = 380
	panel.offset_right = 1000
	panel.offset_top = -240
	panel.offset_bottom = -120
	var content := VBoxContainer.new()
	panel.add_child(content)
	status = Label.new()
	content.add_child(status)
	var row := HBoxContainer.new()
	content.add_child(row)
	_button(row, "铺土路（免费）", _set_mode.bind(1))
	_button(row, "铺石路（1石头/格）", _set_mode.bind(2))
	_button(row, "拆路", _set_mode.bind(3)).tooltip_text = "拆除不返还资源"
	_button(row, "选择全部土路", _select_all)
	var actions := HBoxContainer.new()
	content.add_child(actions)
	upgrade_button = _button(actions, "升级为石路", _upgrade)
	_button(actions, "关闭 / 取消铺设", close)
	panel.hide()

func open() -> void:
	ghost.cancel_preview()
	main._cancel_enemy_placement()
	main.clear_selection()
	panel.show()
	_refresh_status()

func close() -> void:
	mode = 0
	dragging = false
	stroke.clear()
	preview.hide()
	panel.hide()
	set_process(false)

func _set_mode(value: int) -> void:
	mode = value
	dragging = false
	all_selected = false
	set_process(true)
	_refresh_status()

func _select_all() -> void:
	mode = 0
	dragging = false
	preview.hide()
	set_process(false)
	all_selected = true
	_refresh_status()

func _upgrade() -> void:
	manager.upgrade_all()
	_refresh_status()

func _refresh_status() -> void:
	var count: int = manager.dirt_count()
	var affordable: int = mini(count, manager.available_stone())
	status.text = "道路：土路 %d 格（+5%%）／石路 %d 格（+10%%）\n%s" % [count, manager.cells.size() - count, "已选择全部土路；点击下方按钮升级" if all_selected else "左键拖拽铺设，松开完成；右键或 Esc 取消"]
	upgrade_button.text = "升级全部：%d 石头，可升级 %d/%d 格" % [count, affordable, count]
	upgrade_button.disabled = not all_selected or affordable == 0

func _mouse_cell() -> Variant:
	var camera: Camera3D = main.get_viewport().get_camera_3d()
	if camera == null: return null
	var point: Vector3 = ghost._get_mouse_world_position(camera, mouse_position)
	return manager.grid.world_to_grid(point) if point != Vector3.INF else null

func _line(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = [from]
	var cell: Vector2i = from
	# 四向连续折线路径，避免斜向拖拽留下互不相连的道路。
	while cell != to:
		if absi(to.x - cell.x) >= absi(to.y - cell.y): cell.x += signi(to.x - cell.x)
		else: cell.y += signi(to.y - cell.y)
		result.append(cell)
	return result

func _input(event: InputEvent) -> void:
	if mode == 0: return
	if event is InputEventMouse: mouse_position = event.position
	if event is InputEventMouseMotion: return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		close()
		main.get_viewport().set_input_as_handled()
		return
	if not event is InputEventMouseButton: return
	if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		close()
		main.get_viewport().set_input_as_handled()
		return
	if event.button_index != MOUSE_BUTTON_LEFT: return
	if main.get_viewport().gui_get_hovered_control() != null and not dragging: return
	var cell: Variant = _mouse_cell()
	if cell == null: return
	if event.pressed:
		dragging = true
		drag_start = cell
	elif dragging:
		var requested: Array[Vector2i] = _line(drag_start, cell)
		if mode == 3: manager.remove_cells(requested)
		else: manager.place_cells(requested, mode)
		dragging = false
		stroke.clear()
		_refresh_status()
	main.get_viewport().set_input_as_handled()

func _process(_delta: float) -> void:
	if not panel.visible or mode == 0: return
	_refresh_status()
	if main.get_viewport().gui_get_hovered_control() != null:
		preview.hide()
		return
	var cell: Variant = _mouse_cell()
	if cell == null:
		preview.hide()
		return
	var next: Array[Vector2i] = []
	if dragging: next = _line(drag_start, cell)
	else: next.append(cell)
	if next == stroke:
		preview.show()
		return
	stroke = next
	var vertices := PackedVector3Array()
	var colors := PackedColorArray()
	var half: float = manager.grid.cell_size * 0.48
	for point: Vector2i in stroke:
		var center: Vector3 = manager.grid.grid_to_world(point) + Vector3.UP * 0.06
		var color := Color(0.25, 0.8, 0.25) if manager.can_place(point) else Color(0.9, 0.15, 0.1)
		if mode == 3: color = Color(0.9, 0.25, 0.15)
		var corners: Array[Vector3] = [center + Vector3(-half, 0, -half), center + Vector3(half, 0, -half), center + Vector3(half, 0, half), center + Vector3(-half, 0, half)]
		for index: int in [0, 1, 3, 1, 2, 3]:
			vertices.append(corners[index])
			colors.append(color)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colors
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	preview.mesh = mesh
	preview.show()
