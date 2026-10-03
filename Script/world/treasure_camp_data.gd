@tool
class_name TreasureCampData
extends Resource

@export var display_name: String = "宝箱营地"
## 留空使用默认宝箱营地；自定义场景的根节点必须使用 TreasureCamp。
@export var scene: PackedScene
@export_range(2.0, 20.0, 0.5) var footprint_radius: float = 3.0
@export_range(3.0, 50.0, 0.5) var guard_leash_radius: float = 10.0
@export_range(0.0, 100.0, 0.1) var guard_health_regen: float = 1.0
@export_range(1, 20, 1) var minimum_guards: int = 1
@export_range(1, 20, 1) var maximum_guards: int = 2
@export var guard_pool: Array[CampGuardEntry] = []
@export_range(1, 20, 1) var reward_draws: int = 2
@export var reward_pool: Array[CampRewardEntry] = []


func validation_error() -> String:
	if minimum_guards > maximum_guards:
		return "守卫最小数量不能超过最大数量"
	if guard_leash_radius < footprint_radius:
		return "守卫活动半径不能小于营地占地半径"
	if guard_pool.is_empty() or reward_pool.is_empty():
		return "守卫池和奖励池不能为空"
	var guard_weight: float = 0.0
	for entry: CampGuardEntry in guard_pool:
		if entry == null or entry.enemy == null or entry.enemy.faction == EnemyData.Faction.SETTLEMENT:
			return "守卫池需要配置敌方怪物"
		guard_weight += entry.weight
	var reward_weight: float = 0.0
	for entry: CampRewardEntry in reward_pool:
		if entry == null or entry.resource == null or entry.resource.id.is_empty():
			return "奖励池需要配置资源"
		if entry.minimum_amount > entry.maximum_amount:
			return "奖励最小数量不能超过最大数量"
		reward_weight += entry.weight
	if guard_weight <= 0.0 or reward_weight <= 0.0:
		return "守卫池和奖励池至少各有一项正权重"
	return ""


func roll(rng: RandomNumberGenerator) -> Dictionary:
	var guards: Array[EnemyData] = []
	var rewards: Dictionary[StringName, float] = {}
	for _index: int in range(rng.randi_range(minimum_guards, maximum_guards)):
		var entry: CampGuardEntry = _draw(guard_pool, rng) as CampGuardEntry
		guards.append(entry.enemy)
	for _index: int in range(reward_draws):
		var entry: CampRewardEntry = _draw(reward_pool, rng) as CampRewardEntry
		var id: StringName = entry.resource.id
		rewards[id] = float(rewards.get(id, 0.0)) + rng.randi_range(entry.minimum_amount, entry.maximum_amount)
	return {"guards": guards, "rewards": rewards}


func _draw(pool: Array, rng: RandomNumberGenerator) -> Resource:
	var total: float = 0.0
	for entry: Resource in pool:
		total += float(entry.get("weight"))
	var choice: float = rng.randf() * total
	for entry: Resource in pool:
		var weight: float = float(entry.get("weight"))
		if weight <= 0.0:
			continue
		choice -= weight
		if choice <= 0.0:
			return entry
	return pool.back()
