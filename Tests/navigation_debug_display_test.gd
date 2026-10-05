extends SceneTree

var failed: bool = false

func _init() -> void:
	call_deferred("_run")

func _expect(value: bool, message: String) -> void:
	print("[通过] " if value else "[失败] ", message)
	failed = failed or not value

func _capture(name: String) -> Image:
	RenderingServer.force_draw(false)
	var image: Image = root.get_texture().get_image()
	image.save_png("res://.godot/navigation_debug_" + name + ".png")
	return image

func _blue_pixels(image: Image) -> int:
	var count: int = 0
	for y: int in range(image.get_height()):
		for x: int in range(image.get_width()):
			var color: Color = image.get_pixel(x, y)
			if color.b > 0.3 and color.b > color.r * 1.5: count += 1
	return count

func _run() -> void:
	root.size = Vector2i(1280, 720)
	var main: Node = load("res://Scene/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	for frame: int in range(90): await physics_frame
	var region: NavigationRegion3D = main.get_node("Systems/NavigationRegion3D")
	_expect(region.navigation_mesh.get_polygon_count() > 0, "实际地图已生成寻路网格")
	var hud: GameHUD = main.find_child("HUD", true, false) as GameHUD
	if hud == null:
		for node: Node in main.find_children("*", "CanvasLayer", true, false):
			if node is GameHUD: hud = node
	_expect(hud != null, "找到实际游戏 HUD")
	if hud == null:
		quit(1)
		return
	var toggle: CheckButton = hud.find_child("NavigationDebugToggle", true, false)
	paused = true
	var before: Image
	if DisplayServer.get_name() != "headless": before = _capture("off")
	toggle.button_pressed = true
	for frame: int in range(5): await physics_frame
	var overlay: MeshInstance3D = region.get_node_or_null("NavigationDebugMesh")
	_expect(overlay != null and overlay.visible and overlay.mesh != null, "勾选后显示实际寻路网格")
	if DisplayServer.get_name() != "headless":
		var enabled: Image = _capture("on")
		_expect(before.get_data() != enabled.get_data(), "勾选后实际渲染画面发生变化")
	var original: NavigationMesh = region.navigation_mesh
	var shown: Mesh = overlay.mesh
	var changed := NavigationMesh.new()
	changed.vertices = PackedVector3Array([Vector3(-3,3,-3), Vector3(-3,3,3), Vector3(3,3,3), Vector3(3,3,-3)])
	changed.add_polygon(PackedInt32Array([0,1,2,3]))
	region.navigation_mesh = changed
	for frame: int in range(2): await physics_frame
	print("更新后的显示包围盒：", overlay.mesh.get_aabb())
	_expect(overlay.mesh != shown and is_equal_approx(overlay.mesh.get_aabb().size.x, 6.0) and is_equal_approx(overlay.mesh.get_aabb().size.z, 6.0), "寻路网格重建后显示同步更新")
	region.navigation_mesh = original
	toggle.button_pressed = false
	for frame: int in range(5): await physics_frame
	_expect(not overlay.visible, "取消后关闭导航显示")
	if DisplayServer.get_name() != "headless":
		var after: Image = _capture("off_again")
		_expect(absi(_blue_pixels(before) - _blue_pixels(after)) < 1000, "关闭后蓝色寻路覆盖消失")
	quit(1 if failed else 0)
