extends Node3D


# ============================================================
# UI
# ============================================================

@onready var resource_building_panel: ResourceBuildingPanel = \
	$UI/ResourceBuildingPanel


# ============================================================
# 初始化
# ============================================================

func _ready():

	print("========== Main启动 ==========")

	var buildings = get_tree().get_nodes_in_group(
		"resource_buildings"
	)

	print("🏭 找到资源建筑数量：", buildings.size())

	for building in buildings:

		print("🏭 找到建筑：", building.name)

		if building.has_signal("building_clicked"):

			print("🔗 连接建筑点击信号：", building.name)

			building.building_clicked.connect(
				_on_resource_building_clicked
			)

	print("========== Main连接结束 ==========")


# ============================================================
# 点击资源建筑
# ============================================================

func _on_resource_building_clicked(building):

	print("📨 Main收到建筑点击：", building.name)
	print("📺 UI对象：", resource_building_panel)

	resource_building_panel.open_building(building)
