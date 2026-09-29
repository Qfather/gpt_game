@tool
extends EditorInspectorPlugin

const PROPERTY_EDITOR_SCRIPT := preload("res://addons/water_material_inspector/water_shader_parameter_editor.gd")
const LABELS := {
	"water_normal": "水面法线贴图",
	"foam_noise": "泡沫噪声贴图",
	"surface_noise": "平静水面低频噪声",
	"scene_depth": "场景深度纹理",
	"shallow_color": "浅水颜色",
	"deep_color": "深水颜色",
	"very_deep_color": "极深水颜色",
	"shore_foam_color": "岸边泡沫颜色",
	"shore_wave_color": "岸边波纹颜色",
	"surface_foam_color": "平静水面泡沫颜色",
	"normal_tiling": "法线平铺",
	"normal_strength": "法线强度",
	"normal_speed": "法线流动速度",
	"normal_pan_speed": "法线流动倍率",
	"normal_noise_intensity": "法线扰动强度",
	"normal_noise_tiling": "法线扰动平铺",
	"deep_height": "深水过渡距离",
	"very_deep_height": "极深水过渡距离",
	"base_opacity": "水面不透明度",
	"shallows_opacity": "浅水不透明度",
	"shore_edge_opacity": "岸边泡沫不透明度",
	"shore_edge_thickness": "岸边泡沫宽度",
	"shore_edge_noise_scale": "岸边边缘噪声平铺",
	"shore_small_foam_opacity": "岸边细泡沫不透明度",
	"shore_small_foam_tiling": "岸边细泡沫平铺",
	"shore_foam_intensity": "岸边泡沫强度",
	"shore_foam_noise_scale": "岸边泡沫噪声强度",
	"shore_wave_speed": "岸边波纹速度",
	"shore_wave_return_amount": "岸边波纹回流量",
	"shore_wave_fade_out_speed": "岸边波纹淡出速度",
	"shore_wave_fade_in_speed": "岸边波纹淡入速度",
	"shore_wave_oscillation": "岸边波纹频率",
	"shore_wave_thickness": "岸边波纹宽度",
	"shore_wave_intensity": "岸边波纹强度",
	"enable_calm_surface_foam": "启用平静水面低频泡沫",
	"surface_foam_strength": "平静水面泡沫强度",
	"surface_foam_tiling": "平静水面泡沫平铺",
	"surface_foam_speed": "平静水面泡沫速度",
	"roughness": "水面粗糙度",
}


func _can_handle(object: Object) -> bool:
	if not object is ShaderMaterial or object.shader == null:
		return false
	return object.shader.code.contains("enable_calm_surface_foam")


func _parse_property(object: Object, type: Variant.Type, name: String, hint_type: PropertyHint, hint_string: String, usage_flags: int, wide: bool) -> bool:
	if not name.begins_with("shader_parameter/"):
		return false
	var parameter_name := name.trim_prefix("shader_parameter/")
	if not LABELS.has(parameter_name):
		return false

	var editor := PROPERTY_EDITOR_SCRIPT.new()
	if not editor.configure(parameter_name, LABELS[parameter_name], type):
		return false
	add_property_editor(name, editor, false, LABELS[parameter_name])
	return true
