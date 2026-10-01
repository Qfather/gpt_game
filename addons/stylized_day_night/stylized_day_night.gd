@tool
extends Node3D

signal time_changed(hour: float, day_progress: float)
signal night_visibility_changed(multiplier: float)

@export_range(60.0, 3600.0, 1.0) var cycle_length_seconds: float = 600.0
@export_range(0.0, 24.0, 0.1) var start_hour: float = 9.0
@export_range(0.0, 1.0, 0.01) var night_visibility_multiplier: float = 0.8
@export var light_shafts_enabled: bool = true
@export var clouds_enabled: bool = true
@export_enum("程序化云", "环形云 01", "环形云 02", "小云团环") var cloud_style: int = 0
@export_range(0.25, 0.75, 0.01) var cloud_density: float = 0.50
@export_range(2.0, 12.0, 0.1) var cloud_scale: float = 5.0
@export_range(0.0, 0.08, 0.001) var cloud_speed: float = 0.015
@export_range(0.0, 1.0, 0.01) var cloud_opacity: float = 0.65
@export_range(-10.0, 10.0, 0.1) var mesh_cloud_altitude: float = 0.0
@export var cloud_rings: Array[Dictionary] = [
	{"radius": 25.0, "height": 0.0, "rotation": 0.0},
]
@export var cycle_paused: bool = false
@export var distant_fog_enabled: bool = false
@export_range(0.0, 500.0, 1.0) var distant_fog_begin: float = 55.0
@export_range(1.0, 500.0, 1.0) var distant_fog_end: float = 180.0
@export var distant_fog_custom_color_enabled: bool = false
@export_color_no_alpha var distant_fog_custom_color: Color = Color("#C7DCEA")

var game_hour: float = 9.0
var current_visibility_multiplier: float = 1.0
var _elapsed_cycle_seconds: float = 0.0
var _cloud_time: float = 0.0
var _last_emitted_visibility: float = -1.0
var _world_environment: WorldEnvironment
var _sun: DirectionalLight3D
var _moon: DirectionalLight3D
var _sky_material: ShaderMaterial
var _cloud_layer: Node3D
var _cloud_material: StandardMaterial3D
var _cloud_variants: Array[Node3D] = []
var _cloud_base_scales: Array[Vector3] = []
var _cloud_base_positions: Array[Vector3] = []
var _cloud_bounds_centers: Array[Vector3] = []
var _generated_cloud_rings: Array[Node3D] = []
var _generated_ring_signature: String = ""
var _cloud_puff_material: StandardMaterial3D
var _cloud_puff_mesh: SphereMesh
var _cloud_shadow_material := StandardMaterial3D.new()

const CLOUD_RING_SCENES: Array[PackedScene] = [
	preload("res://addons/stylized_day_night/modle/cloud_ring_01.glb"),
	preload("res://addons/stylized_day_night/modle/cloud_ring_02.glb"),
]

const DAY_TOP := Color("#6FA6D8")
const DAY_HORIZON := Color("#C7DCEA")
const DAY_GROUND := Color("#679BBF")
const NIGHT_TOP := Color("#101B3A")
const NIGHT_HORIZON := Color("#46516F")
const NIGHT_GROUND := Color("#202633")


func _validate_property(property: Dictionary) -> void:
	if property.name in [
		&"cycle_length_seconds", &"start_hour", &"night_visibility_multiplier", &"light_shafts_enabled",
		&"clouds_enabled", &"cloud_style", &"cloud_density", &"cloud_scale",
		&"cloud_speed", &"cloud_opacity", &"mesh_cloud_altitude", &"cloud_rings",
		&"cycle_paused", &"distant_fog_enabled", &"distant_fog_begin", &"distant_fog_end",
		&"distant_fog_custom_color_enabled", &"distant_fog_custom_color",
	]:
		property.usage &= ~PROPERTY_USAGE_EDITOR


func _get_property_list() -> Array[Dictionary]:
	return [
		{"name": "昼夜设置", "type": TYPE_NIL, "usage": PROPERTY_USAGE_GROUP},
		{"name": "昼夜周期（秒）", "type": TYPE_FLOAT, "hint": PROPERTY_HINT_RANGE, "hint_string": "60,3600,1", "usage": PROPERTY_USAGE_DEFAULT},
		{"name": "开始时刻（小时）", "type": TYPE_FLOAT, "hint": PROPERTY_HINT_RANGE, "hint_string": "0,24,0.1", "usage": PROPERTY_USAGE_DEFAULT},
		{"name": "夜间视野倍率", "type": TYPE_FLOAT, "hint": PROPERTY_HINT_RANGE, "hint_string": "0,1,0.01", "usage": PROPERTY_USAGE_DEFAULT},
		{"name": "暂停昼夜循环", "type": TYPE_BOOL, "usage": PROPERTY_USAGE_DEFAULT},
		{"name": "启用光束效果", "type": TYPE_BOOL, "usage": PROPERTY_USAGE_DEFAULT},
		{"name": "云层设置", "type": TYPE_NIL, "usage": PROPERTY_USAGE_GROUP},
		{"name": "启用云层", "type": TYPE_BOOL, "usage": PROPERTY_USAGE_DEFAULT},
		{"name": "云层样式", "type": TYPE_INT, "hint": PROPERTY_HINT_ENUM, "hint_string": "程序化云,环形云 01,环形云 02,小云团环", "usage": PROPERTY_USAGE_DEFAULT},
		{"name": "云层密度", "type": TYPE_FLOAT, "hint": PROPERTY_HINT_RANGE, "hint_string": "0.25,0.75,0.01", "usage": PROPERTY_USAGE_DEFAULT},
		{"name": "云层大小", "type": TYPE_FLOAT, "hint": PROPERTY_HINT_RANGE, "hint_string": "2,12,0.1", "usage": PROPERTY_USAGE_DEFAULT},
		{"name": "云层速度", "type": TYPE_FLOAT, "hint": PROPERTY_HINT_RANGE, "hint_string": "0,0.08,0.001", "usage": PROPERTY_USAGE_DEFAULT},
		{"name": "云层不透明度", "type": TYPE_FLOAT, "hint": PROPERTY_HINT_RANGE, "hint_string": "0,1,0.01", "usage": PROPERTY_USAGE_DEFAULT},
		{"name": "模型云高度", "type": TYPE_FLOAT, "hint": PROPERTY_HINT_RANGE, "hint_string": "-10,10,0.1", "usage": PROPERTY_USAGE_DEFAULT},
		{"name": "云团环配置", "type": TYPE_ARRAY, "usage": PROPERTY_USAGE_DEFAULT},
		{"name": "远景雾", "type": TYPE_NIL, "usage": PROPERTY_USAGE_GROUP},
		{"name": "启用远景雾", "type": TYPE_BOOL, "usage": PROPERTY_USAGE_DEFAULT},
		{"name": "雾开始距离", "type": TYPE_FLOAT, "hint": PROPERTY_HINT_RANGE, "hint_string": "0,500,1", "usage": PROPERTY_USAGE_DEFAULT},
		{"name": "雾结束距离", "type": TYPE_FLOAT, "hint": PROPERTY_HINT_RANGE, "hint_string": "1,500,1", "usage": PROPERTY_USAGE_DEFAULT},
		{"name": "自定义雾颜色", "type": TYPE_BOOL, "usage": PROPERTY_USAGE_DEFAULT},
		{"name": "雾颜色", "type": TYPE_COLOR, "hint": PROPERTY_HINT_COLOR_NO_ALPHA, "usage": PROPERTY_USAGE_DEFAULT},
	]


func _get(property: StringName) -> Variant:
	match property:
		&"昼夜周期（秒）": return cycle_length_seconds
		&"开始时刻（小时）": return start_hour
		&"夜间视野倍率": return night_visibility_multiplier
		&"暂停昼夜循环": return cycle_paused
		&"启用光束效果": return light_shafts_enabled
		&"启用云层": return clouds_enabled
		&"云层样式": return cloud_style
		&"云层密度": return cloud_density
		&"云层大小": return cloud_scale
		&"云层速度": return cloud_speed
		&"云层不透明度": return cloud_opacity
		&"模型云高度": return mesh_cloud_altitude
		&"云团环配置": return cloud_rings
		&"启用远景雾": return distant_fog_enabled
		&"雾开始距离": return distant_fog_begin
		&"雾结束距离": return distant_fog_end
		&"自定义雾颜色": return distant_fog_custom_color_enabled
		&"雾颜色": return distant_fog_custom_color
	return null


func _set(property: StringName, value: Variant) -> bool:
	match property:
		&"昼夜周期（秒）": cycle_length_seconds = value
		&"开始时刻（小时）": start_hour = value
		&"夜间视野倍率": night_visibility_multiplier = value
		&"暂停昼夜循环": cycle_paused = value
		&"启用光束效果": light_shafts_enabled = value
		&"启用云层": clouds_enabled = value
		&"云层样式": cloud_style = value
		&"云层密度": cloud_density = value
		&"云层大小": cloud_scale = value
		&"云层速度": cloud_speed = value
		&"云层不透明度": cloud_opacity = value
		&"模型云高度": mesh_cloud_altitude = value
		&"云团环配置": cloud_rings = value
		&"启用远景雾": distant_fog_enabled = value
		&"雾开始距离": distant_fog_begin = value
		&"雾结束距离": distant_fog_end = value
		&"自定义雾颜色": distant_fog_custom_color_enabled = value
		&"雾颜色": distant_fog_custom_color = value
		_: return false
	return true


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	game_hour = start_hour
	_create_environment()
	_update_sky_and_sun()
	set_process(not Engine.is_editor_hint())


func _process(delta: float) -> void:
	if not cycle_paused:
		_elapsed_cycle_seconds += delta
		_cloud_time += delta
		game_hour = fposmod(start_hour + _elapsed_cycle_seconds / maxf(cycle_length_seconds, 1.0) * 24.0, 24.0)
		_update_sky_and_sun()
	_update_cloud_layer_position()
	_update_light_shafts()


func set_game_hour(hour: float) -> void:
	game_hour = fposmod(hour, 24.0)
	start_hour = game_hour
	_elapsed_cycle_seconds = 0.0
	_update_sky_and_sun()


func refresh_settings() -> void:
	_rebuild_generated_cloud_rings()
	_update_sky_and_sun()


func _create_environment() -> void:
	_world_environment = WorldEnvironment.new()
	_world_environment.name = "SkyEnvironment"
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 0.45
	environment.glow_enabled = true
	environment.fog_mode = Environment.FOG_MODE_DEPTH
	environment.fog_density = 1.0
	environment.fog_sky_affect = 0.0
	var sky := Sky.new()
	_sky_material = ShaderMaterial.new()
	_sky_material.shader = preload("res://addons/stylized_day_night/stylized_sky.gdshader")
	sky.sky_material = _sky_material
	environment.sky = sky
	_world_environment.environment = environment
	add_child(_world_environment)

	_sun = DirectionalLight3D.new()
	_sun.name = "SunLight"
	_sun.shadow_enabled = true
	_sun.light_color = Color("#FFF1D6")
	add_child(_sun)
	_moon = DirectionalLight3D.new()
	_moon.name = "MoonLight"
	_moon.shadow_enabled = false
	_moon.light_color = Color("#A8C4F0")
	add_child(_moon)
	_create_mesh_clouds()
	_create_light_shafts()


func _create_light_shafts() -> void:
	var environment := _world_environment.environment
	environment.volumetric_fog_density = 0.0001
	environment.volumetric_fog_albedo = Color.WHITE
	environment.volumetric_fog_length = 32.0
	environment.volumetric_fog_anisotropy = 0.0
	environment.volumetric_fog_ambient_inject = 0.0
	environment.volumetric_fog_sky_affect = 1.0
	_sun.light_volumetric_fog_energy = 500.0
	_moon.light_volumetric_fog_energy = 1000.0
	_update_light_shafts()


func _update_light_shafts() -> void:
	if not is_instance_valid(_world_environment):
		return
	if _world_environment.environment.volumetric_fog_enabled != light_shafts_enabled:
		for shadow in _cloud_layer.find_children("LightShaftShadow", "MeshInstance3D", true, false):
			shadow.visible = light_shafts_enabled
	_world_environment.environment.volumetric_fog_enabled = light_shafts_enabled
	_moon.shadow_enabled = light_shafts_enabled


func _update_sky_and_sun() -> void:
	if not is_instance_valid(_sky_material) or not is_instance_valid(_sun) or not is_instance_valid(_moon):
		return
	var daylight := maxf(0.0, sin((game_hour - 6.0) / 12.0 * PI))
	var blend := clampf(daylight / 0.22, 0.0, 1.0)
	daylight = blend * blend * (3.0 - 2.0 * blend)
	var sun_direction := _get_celestial_direction(game_hour)
	_sky_material.set_shader_parameter("daylight", daylight)
	_sky_material.set_shader_parameter("star_visibility", 1.0 - daylight)
	_sky_material.set_shader_parameter("sun_direction", sun_direction)
	_sky_material.set_shader_parameter("day_top_color", DAY_TOP)
	_sky_material.set_shader_parameter("day_horizon_color", DAY_HORIZON)
	_sky_material.set_shader_parameter("night_top_color", NIGHT_TOP)
	_sky_material.set_shader_parameter("night_horizon_color", NIGHT_HORIZON)
	_sky_material.set_shader_parameter("day_ground_color", DAY_GROUND)
	_sky_material.set_shader_parameter("night_ground_color", NIGHT_GROUND)
	_sky_material.set_shader_parameter("cloud_density", cloud_density)
	_sky_material.set_shader_parameter("cloud_scale", cloud_scale)
	_sky_material.set_shader_parameter("cloud_opacity", cloud_opacity)
	_sky_material.set_shader_parameter("cloud_offset", Vector3(_cloud_time * cloud_speed, 0.0, _cloud_time * cloud_speed * 0.18))
	_sky_material.set_shader_parameter("clouds_enabled", clouds_enabled and cloud_style == 0)
	if is_instance_valid(_cloud_material):
		var night_cloud_color := Color(0.24, 0.30, 0.43)
		var day_cloud_color := Color(0.92, 0.96, 1.0)
		var cloud_color := night_cloud_color.lerp(day_cloud_color, daylight)
		cloud_color.a = cloud_opacity
		_cloud_material.albedo_color = cloud_color
	_update_mesh_cloud_scales()
	for index in range(_cloud_variants.size()):
		_cloud_variants[index].visible = clouds_enabled and cloud_style == index + 1
	_world_environment.environment.ambient_light_color = Color("#809CC4")
	_world_environment.environment.ambient_light_sky_contribution = lerpf(0.15, 1.0, daylight)
	_world_environment.environment.ambient_light_energy = lerpf(0.6, 0.45, daylight)
	_world_environment.environment.fog_enabled = distant_fog_enabled
	_world_environment.environment.fog_depth_begin = distant_fog_begin
	_world_environment.environment.fog_depth_end = maxf(distant_fog_begin + 1.0, distant_fog_end)
	_world_environment.environment.fog_light_color = distant_fog_custom_color if distant_fog_custom_color_enabled else NIGHT_HORIZON.lerp(DAY_HORIZON, daylight)
	_sun.light_energy = daylight
	_sun.light_color = Color("#B8C9FF").lerp(Color("#FFF1D6"), daylight)
	var light_up := Vector3.FORWARD if absf(sun_direction.y) > 0.98 else Vector3.UP
	_sun.look_at(_sun.global_position - sun_direction, light_up)
	_moon.light_energy = (1.0 - daylight) * 0.45
	_moon.look_at(_moon.global_position + sun_direction, light_up)
	var visibility := lerpf(night_visibility_multiplier, 1.0, daylight)
	current_visibility_multiplier = visibility
	if not is_equal_approx(visibility, _last_emitted_visibility):
		_last_emitted_visibility = visibility
		night_visibility_changed.emit(visibility)
	time_changed.emit(game_hour, game_hour / 24.0)


func _create_mesh_clouds() -> void:
	_cloud_layer = Node3D.new()
	_cloud_layer.name = "MeshCloudLayer"
	add_child(_cloud_layer)
	_cloud_material = StandardMaterial3D.new()
	_cloud_material.albedo_color = Color(0.92, 0.96, 1.0, cloud_opacity)
	_cloud_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_cloud_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_cloud_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_cloud_puff_material = _cloud_material
	_cloud_puff_mesh = SphereMesh.new()
	_cloud_puff_mesh.radial_segments = 16
	_cloud_puff_mesh.rings = 8
	for cloud_scene in CLOUD_RING_SCENES:
		var cloud_root := cloud_scene.instantiate() as Node3D
		if cloud_root == null:
			continue
		cloud_root.visible = false
		_cloud_layer.add_child(cloud_root)
		_apply_cloud_material(cloud_root)
		_cloud_variants.append(cloud_root)
		_cloud_base_scales.append(cloud_root.scale)
		_cloud_base_positions.append(cloud_root.position)
		_cloud_bounds_centers.append(_get_cloud_bounds_center(cloud_root))
	_update_mesh_cloud_scales()
	_rebuild_generated_cloud_rings()


func _update_mesh_cloud_scales() -> void:
	var scale_multiplier := cloud_scale / 5.0
	for index in range(_cloud_variants.size()):
		var base_scale := _cloud_base_scales[index]
		var scaled := base_scale * scale_multiplier
		var center := _cloud_bounds_centers[index]
		_cloud_variants[index].scale = scaled
		_cloud_variants[index].position = _cloud_base_positions[index] + Vector3(
			(base_scale.x - scaled.x) * center.x,
			(base_scale.y - scaled.y) * center.y,
			(base_scale.z - scaled.z) * center.z
		)


func _get_cloud_bounds_center(root: Node3D) -> Vector3:
	var bounds_points: Array[Vector3] = []
	_collect_cloud_bounds(root, Transform3D.IDENTITY, bounds_points)
	var bounds_min := Vector3(INF, INF, INF)
	var bounds_max := Vector3(-INF, -INF, -INF)
	for point in bounds_points:
		bounds_min.x = minf(bounds_min.x, point.x)
		bounds_min.y = minf(bounds_min.y, point.y)
		bounds_min.z = minf(bounds_min.z, point.z)
		bounds_max.x = maxf(bounds_max.x, point.x)
		bounds_max.y = maxf(bounds_max.y, point.y)
		bounds_max.z = maxf(bounds_max.z, point.z)
	return (bounds_min + bounds_max) * 0.5


func _collect_cloud_bounds(node: Node, transform_to_root: Transform3D, bounds_points: Array[Vector3]) -> void:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		var aabb := mesh_instance.get_aabb()
		for corner_index in range(8):
			var corner := Vector3(
				aabb.position.x + (aabb.size.x if (corner_index & 1) != 0 else 0.0),
				aabb.position.y + (aabb.size.y if (corner_index & 2) != 0 else 0.0),
				aabb.position.z + (aabb.size.z if (corner_index & 4) != 0 else 0.0)
			)
			bounds_points.append(transform_to_root * corner)
	for child in node.get_children():
		var child_transform := transform_to_root
		if child is Node3D:
			child_transform *= (child as Node3D).transform
		_collect_cloud_bounds(child, child_transform, bounds_points)


func _apply_cloud_material(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		mesh_instance.material_override = _cloud_material
		mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for child in node.get_children():
		_apply_cloud_material(child)
	if node is MeshInstance3D:
		_add_cloud_shadow(node)


func _add_cloud_shadow(mesh_instance: MeshInstance3D) -> void:
	var shadow := MeshInstance3D.new()
	shadow.name = "LightShaftShadow"
	shadow.mesh = mesh_instance.mesh
	shadow.material_override = _cloud_shadow_material
	shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	shadow.visible = light_shafts_enabled
	mesh_instance.add_child(shadow)


func _rebuild_generated_cloud_rings() -> void:
	if not is_instance_valid(_cloud_layer) or _cloud_puff_mesh == null:
		return
	if not clouds_enabled or cloud_style != 3:
		for ring_root in _generated_cloud_rings:
			ring_root.visible = false
		return
	var signature := "%s|%.3f|%.3f" % [var_to_str(cloud_rings), cloud_density, cloud_scale]
	if signature == _generated_ring_signature:
		for ring_index in range(_generated_cloud_rings.size()):
			_generated_cloud_rings[ring_index].visible = clouds_enabled and cloud_style == 3
		return
	for ring_root in _generated_cloud_rings:
		ring_root.queue_free()
	_generated_cloud_rings.clear()
	_generated_ring_signature = signature
	for ring_index in range(cloud_rings.size()):
		var rng := RandomNumberGenerator.new()
		rng.seed = 1483 + ring_index * 7919
		var ring_data: Dictionary = cloud_rings[ring_index]
		var radius := float(ring_data.get("radius", 25.0))
		var ring_root := Node3D.new()
		ring_root.name = "GeneratedCloudRing_%d" % (ring_index + 1)
		ring_root.position.y = float(ring_data.get("height", 0.0))
		ring_root.rotation.y = deg_to_rad(float(ring_data.get("rotation", 0.0)))
		_cloud_layer.add_child(ring_root)
		_generated_cloud_rings.append(ring_root)
		var puff_count := maxi(8, int(ceil(TAU * radius * cloud_density)))
		var puff_scale := cloud_scale / 5.0
		for puff_index in range(puff_count):
			var angle := TAU * float(puff_index) / float(puff_count)
			angle += rng.randf_range(-TAU / float(puff_count) * 0.25, TAU / float(puff_count) * 0.25)
			var puff_root := _create_cloud_puff(rng.randi_range(0, 2))
			var point_radius := radius + rng.randf_range(-puff_scale * 0.35, puff_scale * 0.35)
			puff_root.position = Vector3(cos(angle), 0.0, sin(angle)) * point_radius
			puff_root.position.y = rng.randf_range(-0.18, 0.18) * puff_scale
			puff_root.rotation.y = rng.randf_range(0.0, TAU)
			puff_root.scale = Vector3.ONE * puff_scale * rng.randf_range(0.8, 1.2)
			ring_root.add_child(puff_root)
			ring_root.visible = clouds_enabled and cloud_style == 3


func _create_cloud_puff(variant: int) -> Node3D:
	var puff := Node3D.new()
	var parts: Array[Vector3] = []
	match variant:
		0:
			parts = [Vector3(0.0, 0.0, 0.0), Vector3(-0.65, -0.05, 0.0), Vector3(0.62, -0.08, 0.08), Vector3(0.05, 0.28, 0.0)]
		1:
			parts = [Vector3(0.0, 0.0, 0.0), Vector3(-0.55, 0.12, 0.12), Vector3(0.58, 0.05, -0.1), Vector3(0.12, -0.16, 0.52), Vector3(-0.08, -0.12, -0.48)]
		_:
			parts = [Vector3(0.0, 0.0, 0.0), Vector3(-0.38, 0.28, 0.0), Vector3(0.45, 0.18, 0.1), Vector3(0.05, -0.12, 0.52), Vector3(-0.12, -0.08, -0.5), Vector3(-0.62, -0.1, 0.28)]
	for part_index in range(parts.size()):
		var puff_piece := MeshInstance3D.new()
		puff_piece.mesh = _cloud_puff_mesh
		puff_piece.material_override = _cloud_puff_material
		puff_piece.position = parts[part_index]
		var vertical_scale := 0.52 if part_index == 0 else 0.68
		puff_piece.scale = Vector3(0.72, vertical_scale, 0.72) if part_index == 0 else Vector3.ONE * 0.55
		_add_cloud_shadow(puff_piece)
		puff.add_child(puff_piece)
	return puff


func _update_cloud_layer_position() -> void:
	if not is_instance_valid(_cloud_layer):
		return
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	_cloud_layer.global_position = Vector3(camera.global_position.x, camera.global_position.y + 10.0 + mesh_cloud_altitude, camera.global_position.z)
	_cloud_layer.rotation.y = fposmod(_cloud_time * cloud_speed * deg_to_rad(100.0), TAU)
	for ring_index in range(_generated_cloud_rings.size()):
		_generated_cloud_rings[ring_index].visible = clouds_enabled and cloud_style == 3


func _get_celestial_direction(hour: float) -> Vector3:
	var elevation := sin((hour - 6.0) / 12.0 * PI)
	var horizontal := sqrt(maxf(0.0, 1.0 - elevation * elevation))
	var azimuth := (hour - 6.0) / 24.0 * TAU
	return Vector3(cos(azimuth) * horizontal, elevation, sin(azimuth) * horizontal).normalized()
