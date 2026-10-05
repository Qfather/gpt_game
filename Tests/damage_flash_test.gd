extends SceneTree

var failed: bool = false

func _init() -> void:
	call_deferred("_run")

func _expect(value: bool, message: String) -> void:
	print("[通过] " if value else "[失败] ", message)
	failed = failed or not value

func _capture(name: String) -> void:
	if DisplayServer.get_name() == "headless": return
	RenderingServer.force_draw(false)
	_expect(root.get_texture().get_image().save_png("res://.godot/damage_flash_" + name + ".png") == OK, "保存" + name + "画面")

func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world
	var region := NavigationRegion3D.new()
	var nav := NavigationMesh.new()
	nav.vertices = PackedVector3Array([Vector3(-10,0,-10),Vector3(-10,0,10),Vector3(10,0,10),Vector3(10,0,-10)])
	nav.add_polygon(PackedInt32Array([0,1,2,3]))
	region.navigation_mesh = nav
	world.add_child(region)
	var resident: CharacterBody3D = load("res://Scene/unit/villager.tscn").instantiate()
	world.add_child(resident)
	resident.set_combat_role(CombatRole.Type.SWORDSMAN)
	resident.position = Vector3(-2,0,0)
	resident.set_physics_process(false)
	var enemy: EnemyBase = load("res://Scene/unit/enemy_base.tscn").instantiate()
	world.add_child(enemy)
	enemy.position = Vector3(2,0,0)
	enemy.set_physics_process(false)
	enemy.set_process(false)
	if DisplayServer.get_name() != "headless":
		root.size = Vector2i(1000,700)
		var camera := Camera3D.new()
		world.add_child(camera)
		camera.position = Vector3(4,5,9)
		camera.look_at(Vector3(0,1,0))
		camera.make_current()
		var light := DirectionalLight3D.new()
		world.add_child(light)
		light.rotation_degrees = Vector3(-45,-30,0)
	for frame: int in range(10): await physics_frame
	var meshes: Array[Node] = resident.visual_root.find_children("*", "MeshInstance3D", true, false)
	meshes.append_array(enemy.visual_root.find_children("*", "MeshInstance3D", true, false))
	var original: Dictionary = {}
	for mesh: MeshInstance3D in meshes: original[mesh] = mesh.material_overlay
	resident.take_damage(0.0, enemy)
	enemy.take_damage(0.0, resident)
	_expect(not meshes[0].has_meta("damage_flash"), "零伤害不闪白")
	_capture("before")
	_expect(resident.take_damage(1.0, enemy) > 0.0 and enemy.take_damage(1.0, resident) > 0.0, "角色与敌人实际受到伤害")
	for mesh: MeshInstance3D in meshes:
		_expect(mesh.material_overlay is StandardMaterial3D and mesh.material_overlay.albedo_color == Color.WHITE, "受伤模型使用白色叠加材质")
	_capture("hit")
	# 放慢测试游戏时间，避免 GPU 读回图片耗时跨过 0.12 秒闪白窗口。
	Engine.time_scale = 0.1
	await create_timer(0.08).timeout
	resident.take_damage(1.0, enemy)
	await create_timer(0.06).timeout
	_expect(meshes[0].has_meta("damage_flash"), "连续受击时旧计时器不会提前清除闪白")
	await create_timer(0.15).timeout
	for mesh: MeshInstance3D in meshes:
		_expect(mesh.material_overlay == original[mesh] and not mesh.has_meta("damage_flash"), "闪白结束后恢复原材质")
	_capture("after")
	Engine.time_scale = 1.0
	resident.take_damage(1.0, enemy)
	world.queue_free()
	await process_frame
	await create_timer(0.15).timeout
	print("受伤闪白测试", "失败" if failed else "通过")
	quit(1 if failed else 0)
