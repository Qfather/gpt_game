class_name EffectData
extends Resource


enum EffectKind {
	DAMAGE,
	AREA,
	KNOCKBACK,
	STATUS,
	VISUAL,
}

@export var effect_id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var effect_kind: EffectKind = EffectKind.DAMAGE
