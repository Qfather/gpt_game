extends Resource
class_name MapGenerationConfig

enum IslandShape { CIRCLE, ELLIPSE, SQUARE, RECTANGLE, TRIANGLE, CUSTOM }

@export_category("岛屿")
@export var island_shape: IslandShape = IslandShape.CIRCLE
@export var island_size: Vector2 = Vector2(30.0, 30.0)
@export_range(0, 2147483647) var seed: int = 731942
@export_range(0, 2147483647) var resource_seed: int = 90210
@export_range(0.0, 0.8, 0.01) var terrain_relief: float = 0.18
@export_range(0.0, 1.0, 0.01) var naturalization: float = 0.75
@export_range(0.2, 5.0, 0.05) var noise_scale: float = 1.0
@export var base_position: Vector2 = Vector2(7.35, -8.62)
@export var custom_outline: PackedVector2Array = PackedVector2Array()

@export_category("湖泊")
@export_range(0, 8, 1) var lake_count: int = 2
@export_range(1.0, 6.0, 0.1) var lake_radius: float = 2.5
@export var custom_lakes: Array[PackedVector2Array] = []

@export_category("资源密度")
@export_range(0.0, 1.0, 0.01) var tree_density: float = 0.35
@export_range(0.0, 1.0, 0.01) var stone_density: float = 0.16
@export_range(1, 12, 1) var trees_per_cluster: int = 5
@export_range(1, 8, 1) var stones_per_cluster: int = 3
