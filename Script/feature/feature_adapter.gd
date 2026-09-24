class_name FeatureAdapter
extends RefCounted


static func from_trait(trait_data: TraitData) -> FeatureData:
	var feature: FeatureData = FeatureData.new()
	if trait_data == null:
		return feature
	feature.feature_id = StringName(trait_data.trait_id)
	feature.display_name = trait_data.trait_name
	feature.description = trait_data.description
	feature.feature_kind = FeatureData.FeatureKind.TRAIT
	feature.source = trait_data
	return feature


static func from_ability(ability: EnemyAbility) -> FeatureData:
	var feature: FeatureData = FeatureData.new()
	if ability == null:
		return feature
	feature.feature_id = ability.ability_id
	feature.display_name = ability.display_name
	feature.feature_kind = FeatureData.FeatureKind.ABILITY
	feature.source = ability
	return feature
