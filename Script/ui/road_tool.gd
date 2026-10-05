extends Node

var manager: Node
var main: Node
var ghost: BuildingGhost
var mode: int = 0
var dragging: bool = false
var drag_start: Vector2i
var preview: MeshInstance3D
var preview_material: StandardMaterial3D
var stroke: Array[Vector2i] = []
var mouse_position: Vector2 = Vector2.INF
var stroke_valid: bool = false
var preview_from: Vector2i = Vector2i(2147483647, 0)
var preview_to: Vector2i = Vector2i(2147483647, 0)
var preview_refresh_msec: int = 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	main = get_parent()
	ghost = main.get_node("Systems/BuildingGhost")
	preview = MeshInstance3D.new()
	preview.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	preview_material = StandardMaterial3D.new()
	preview_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	preview_material.vertex_color_use_as_albedo = true
	preview.material_override = preview_material
	main.add_child(preview)
	preview.hide()
	main.hud.road_requested.connect(open)
	main.hud.build_requested.connect(func(_data: BuildingData) -> void: close())
	main.hud.enemy_placement_requested.connect(func(_data: EnemyData) -> void: close())
	set_process(false)

func open(data: BuildingData = null) -> void:
	ghost.cancel_preview()
	main._cancel_enemy_placement()
	main.clear_selection()
	_set_mode(data.road_kind if data != null else 1)

func close() -> void:
	mode = 0
	dragging = false
	stroke.clear()
	preview.hide()
	set_process(false)

func _set_mode(value: int) -> void:
	mode = value
	dragging = false
	preview_from = Vector2i(2147483647, 0)
	stroke.clear()
	set_process(true)

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
	var game_camera: GameCameraController = main.get_node("Systems/Camera3D")
	if is_instance_valid(game_camera.character_camera): return
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
		var requested: Array[Vector2i] = _line(drag_start, cell) if mode == 3 else manager.plan_stroke(drag_start, cell)
		if mode == 3: manager.remove_cells(requested)
		elif not requested.is_empty(): manager.queue_cells(requested, mode)
		dragging = false
		stroke.clear()
	main.get_viewport().set_input_as_handled()

func _process(_delta: float) -> void:
	if mode == 0: return
	if main.get_viewport().gui_get_hovered_control() != null:
		preview.hide()
		return
	var cell: Variant = _mouse_cell()
	if cell == null:
		preview.hide()
		return
	var next: Array[Vector2i] = []
	var from: Vector2i = drag_start if dragging else cell
	if preview_from == from and preview_to == cell and not stroke.is_empty() and Time.get_ticks_msec() < preview_refresh_msec:
		preview.show()
		return
	preview_from = from
	preview_to = cell
	preview_refresh_msec = Time.get_ticks_msec() + 200
	next = _line(from, cell) if mode == 3 else manager.plan_stroke(from, cell)
	var was_valid: bool = stroke_valid
	stroke_valid = not next.is_empty()
	if mode != 3 and stroke_valid:
		var needed: int = 0
		for point: Vector2i in next:
			if manager.cells.get(point, 0) < mode and not manager.pending.has(point): needed += 1
		stroke_valid = manager.affordable_count(mode) >= needed
	if next.is_empty(): next = _line(from, cell)
	if next == stroke and was_valid == stroke_valid:
		preview.show()
		return
	stroke = next
	var vertices := PackedVector3Array()
	var colors := PackedColorArray()
	var half: float = manager.grid.cell_size * 0.48
	for point: Vector2i in stroke:
		var center: Vector3 = manager.grid.grid_to_world(point) + Vector3.UP * 0.06
		var color := Color(0.25, 0.8, 0.25) if stroke_valid else Color(0.9, 0.15, 0.1)
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
