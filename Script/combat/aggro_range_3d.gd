class_name AggroRange3D
extends MeshInstance3D


@export var radius: float = 8.0
@export var ring_color: Color = Color(1.0, 0.1, 0.1, 0.45)
@export var combat_only: bool = false

var target: Node


func _ready() -> void:
	target = get_parent()
	_create_ring()
	_refresh_visibility()


func _process(_delta: float) -> void:
	_refresh_visibility()


func set_radius(next_radius: float) -> void:
	radius = maxf(next_radius, 0.1)
	if is_inside_tree():
		_create_ring()


func _create_ring() -> void:
	var torus: TorusMesh = TorusMesh.new()
	torus.inner_radius = maxf(radius - 0.035, 0.01)
	torus.outer_radius = radius
	torus.rings = 64
	torus.ring_segments = 8
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.no_depth_test = true
	material.albedo_color = ring_color
	torus.material = material
	mesh = torus


func _refresh_visibility() -> void:
	if target == null:
		return
	if combat_only:
		visible = (
			target.has_method("get_combat_role")
			and int(target.get_combat_role()) == CombatRole.Type.SWORDSMAN
		)
