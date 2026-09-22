extends SceneTree


func _init() -> void:
	randomize()
	var always: FeatureData = FeatureData.new()
	always.feature_id = &"always"
	var never: FeatureData = FeatureData.new()
	never.feature_id = &"never"
	var data: EnemyData = EnemyData.new()
	data.features = [
		_make_entry(always, 1.0),
		_make_entry(never, 0.0),
	]
	var enemy: EnemyBase = preload("res://Scene/unit/enemy_base.tscn").instantiate()
	enemy.enemy_data = data
	var features: Array[FeatureData] = enemy.call("_roll_features", data.features)
	_expect(features.size() == 1, "FeatureEntry 概率筛选只保留 100% 条目")
	_expect(features[0].feature_id == &"always", "100% Feature 每次生成")
	print("FeatureEntry 最小接口测试通过")
	quit()


func _make_entry(feature: FeatureData, chance: float) -> FeatureEntry:
	var entry: FeatureEntry = FeatureEntry.new()
	entry.feature = feature
	entry.chance = chance
	return entry


func _expect(condition: bool, message: String) -> void:
	if not condition:
		push_error("失败：" + message)
		quit(1)
