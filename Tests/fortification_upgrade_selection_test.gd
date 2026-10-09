extends SceneTree
var failed := false
var main: Node3D
var grid: BuildGrid
func _initialize(): call_deferred("_run")
func _expect(ok: bool,message: String):
	print("[通过] " if ok else "[失败] ",message)
	failed = failed or not ok
func _building(path: String,cell: Vector2i) -> BuildingBase:
	var data: BuildingData=load("res://data/buildings/"+path+".tres")
	var building: BuildingBase=data.building_scene.instantiate()
	building.building_data=data
	main.add_child(building)
	building.position=grid.grid_to_world(cell)
	building.set_build_grid_occupancy(cell,data.grid_size,0)
	for point in grid._get_area_cells(cell,data.grid_size,0): grid.occupied_cells[point]=true
	main.register_building(building)
	building.set_meta("fog_hidden",false)
	return building
func _run():
	main=load("res://Scene/main.tscn").instantiate()
	main.level_preset=main.level_preset.duplicate(true)
	main.level_preset.events.clear()
	main.level_preset.camp_config.enabled=false
	root.add_child(main)
	current_scene=main
	for i in range(90): await physics_frame
	main.get_node("Systems/PopulationManager").set_process(false)
	get_first_node_in_group("fog_of_war").set_process(false)
	grid=main.get_node("Systems/BuildGrid")
	for data: BuildingData in main.hud.menu_buildings:
		_expect(data.id not in [&"wall",&"gate",&"wall_tower"], "石制防线不在直接建造菜单中")
	var first=_building("WoodWallData",Vector2i(0,0))
	var second=_building("WoodWallData",Vector2i(1,0))
	var stone=_building("WallData",Vector2i(2,0))
	var click:=InputEventMouseButton.new()
	click.button_index=MOUSE_BUTTON_LEFT
	click.pressed=true
	click.double_click=true
	first._on_click_area_input_event(null,click,Vector3.ZERO,Vector3.ZERO,0)
	_expect(main.selected_objects.size()==2 and main.selected_objects.has(first) and main.selected_objects.has(second) and not main.selected_objects.has(stone),"双击木墙仅多选同类木墙")
	await process_frame
	main.resource_building_panel.refresh()
	_expect(main.resource_building_panel.upgrade_button.visible and not main.resource_building_panel.upgrade_button.disabled,"多选菜单提供升级按钮")
	if DisplayServer.get_name() != "headless":
		var camera: Camera3D = main.get_viewport().get_camera_3d()
		camera.set_process(false)
		camera.global_position = first.global_position + Vector3(4,8,9)
		camera.look_at(first.global_position + Vector3(1.5,0,0))
		main.resource_building_panel.position.x = main.resource_building_panel.opened_x
		await process_frame
		RenderingServer.force_draw(false)
		root.get_texture().get_image().save_png("res://.godot/fortification_upgrade_selection.png")
	main.resource_building_panel._on_upgrade_pressed()
	_expect(is_instance_valid(first.upgrade_site) and is_instance_valid(second.upgrade_site),"多选木墙分别生成升级工地")
	var cancelled: ConstructionSite=second.upgrade_site
	cancelled.cancel_construction()
	await process_frame
	_expect(is_instance_valid(second) and second.building_data.id==&"wood_wall" and grid.occupied_cells.has(Vector2i(1,0)),"取消升级保留木墙和占地")
	var site: ConstructionSite=first.upgrade_site
	for id: StringName in site.required_resources: site.receive_delivery(id,site.get_still_needed(id))
	site._complete_construction()
	await process_frame
	var upgraded: BuildingBase
	for building: Node in get_nodes_in_group("buildings"):
		if not building is ConstructionSite and building.build_grid_area_registered and building.build_grid_position==Vector2i.ZERO and not building.is_queued_for_deletion(): upgraded=building
	_expect(upgraded!=null and upgraded.building_data.id==&"wall" and grid.occupied_cells.has(Vector2i.ZERO),"升级完工替换为石墙且不释放占地")
	var gate=_building("WoodGateData",Vector2i(5,0))
	_expect(gate.get_upgrade_cost().get(&"wood",0.0)==0 and gate.get_upgrade_cost().get(&"stone",0.0)==15,"木城门升级仅补15石料，不重复收取木材")
	_expect(gate.request_upgrade(),"木城门可以升级")
	var gate_site: ConstructionSite=gate.upgrade_site
	for id: StringName in gate_site.required_resources: gate_site.receive_delivery(id,gate_site.get_still_needed(id))
	gate_site._complete_construction()
	await process_frame
	var tower=_building("WoodWallTowerData",Vector2i(11,0))
	var archer=load("res://Scene/unit/villager.tscn").instantiate()
	main.add_child(archer)
	archer.set_physics_process(false)
	for i in range(5): await physics_frame
	archer.set_combat_role(CombatRole.Type.ARCHER)
	tower.garrisoned_units.append(archer)
	archer.garrisoned_in=tower
	archer.state=archer.State.GARRISONED
	tower.food_inventory[&"meat"]=3
	_expect(tower.request_upgrade(),"木塔楼可以升级，不需要重新建底墙")
	var tower_site: ConstructionSite=tower.upgrade_site
	for id: StringName in tower_site.required_resources: tower_site.receive_delivery(id,tower_site.get_still_needed(id))
	tower_site._complete_construction()
	await process_frame
	_expect(is_instance_valid(archer.garrisoned_in) and archer.garrisoned_in.building_data.id==&"wall_tower" and archer.garrisoned_in.garrisoned_units.has(archer) and archer.garrisoned_in.food_inventory.get(&"meat")==3,"升级塔楼保留驻军和军粮")
	main.clear_selection()
	_expect(main.selected_objects.is_empty(),"取消选择恢复全部高亮")
	var first_unit = load("res://Scene/unit/villager.tscn").instantiate()
	var second_unit = load("res://Scene/unit/villager.tscn").instantiate()
	main.add_child(first_unit)
	main.add_child(second_unit)
	first_unit.set_physics_process(false)
	second_unit.set_physics_process(false)
	for i in range(5): await physics_frame
	first_unit.set_combat_role(CombatRole.Type.SWORDSMAN)
	second_unit.set_combat_role(CombatRole.Type.SWORDSMAN)
	first_unit.set_meta("selection_double_click",true)
	main._on_villager_clicked(first_unit)
	_expect(main.selected_objects.has(second_unit) and not main.selected_objects.has(archer),"双击剑士多选同类单位，不选弓箭手")
	quit(1 if failed else 0)
