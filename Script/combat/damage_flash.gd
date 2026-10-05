extends RefCounted


static func flash(visual: Node3D) -> void:
	if not is_instance_valid(visual) or not visual.is_inside_tree(): return
	var white := StandardMaterial3D.new()
	white.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	white.albedo_color = Color.WHITE
	var meshes: Array[Node] = visual.find_children("*", "MeshInstance3D", true, false)
	if visual is MeshInstance3D: meshes.append(visual)
	for node: Node in meshes:
		var mesh: MeshInstance3D = node as MeshInstance3D
		var state: Dictionary = mesh.get_meta("damage_flash", {"original": mesh.material_overlay, "generation": 0})
		state.generation += 1
		mesh.set_meta("damage_flash", state)
		mesh.material_overlay = white
		visual.get_tree().create_timer(0.12, false).timeout.connect(_restore.bind(mesh, state.generation))


static func _restore(mesh: Variant, generation: int) -> void:
	if not is_instance_valid(mesh) or not mesh.has_meta("damage_flash"): return
	var state: Dictionary = mesh.get_meta("damage_flash")
	if state.generation != generation: return
	mesh.material_overlay = state.original
	mesh.remove_meta("damage_flash")
