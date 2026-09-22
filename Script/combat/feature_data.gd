class_name FeatureData
extends Resource


enum FeatureKind {
	TRAIT,
	ABILITY,
	VISUAL,
}

@export var feature_id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var feature_kind: FeatureKind = FeatureKind.TRAIT
var source: Resource
