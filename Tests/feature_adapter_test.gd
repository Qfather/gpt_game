extends SceneTree

const ADAPTER: Script = preload("res://Script/combat/feature_adapter.gd")


func _init() -> void:
	var trait_data: TraitData = TraitData.new()
	trait_data.trait_id = "swift_feet"
	trait_data.trait_name = "敏捷"
	trait_data.description = "移动更快"
	var trait_feature: FeatureData = ADAPTER.from_trait(trait_data)
	_expect(trait_feature.feature_id == &"swift_feet", "Trait 可以转换为 Feature 描述")
	_expect(trait_feature.feature_kind == FeatureData.FeatureKind.TRAIT, "Trait 保留 Feature 类型")

	var ability: EnemyAbility = EnemyAbility.new()
	ability.ability_id = &"ground_slam"
	ability.display_name = "震地"
	var ability_feature: FeatureData = ADAPTER.from_ability(ability)
	_expect(ability_feature.feature_id == &"ground_slam", "Ability 可以转换为 Feature 描述")
	_expect(ability_feature.feature_kind == FeatureData.FeatureKind.ABILITY, "Ability 保留 Feature 类型")
	print("Feature 兼容接口测试通过")
	quit()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		push_error("失败：" + message)
		quit(1)

