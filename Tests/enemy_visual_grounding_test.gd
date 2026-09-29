extends SceneTree

var failed: bool = false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for folder: String in ["res://data/enemies/raid", "res://data/enemies/rift"]:
		for file: String in DirAccess.get_files_at(folder):
			if not file.ends_with("Data.tres"):
				continue
			var data: EnemyData = load(folder.path_join(file)) as EnemyData
			if data == null:
				continue
			var enemy: EnemyBase = load("res://Scene/unit/enemy_base.tscn").instantiate() as EnemyBase
			enemy.enemy_data = data
			root.add_child(enemy)
			enemy.set_process(false)
			enemy.set_physics_process(false)
			enemy.position = Vector3(0, 6.6, 0)
			await process_frame
			var bottom: float = INF
			for node: Node in enemy.visual_root.find_children("*", "MeshInstance3D", true, false):
				var mesh: MeshInstance3D = node as MeshInstance3D
				if mesh.mesh != null:
					var bounds: AABB = mesh.global_transform * mesh.get_aabb()
					bottom = minf(bottom, bounds.position.y)
			if not is_equal_approx(bottom, 6.0):
				failed = true
				push_error("失败：模型脚底未贴地：" + file + " 高度=" + str(bottom))
			enemy.queue_free()
			await process_frame
	print("怪物模型贴地测试", "失败" if failed else "通过")
	quit(1 if failed else 0)
