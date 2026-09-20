class_name PopulationManager
extends Node

signal population_changed(current_population: int, housing_capacity: int)

var current_population: int = 0
var housing_capacity: int = 0


func _ready() -> void:
	add_to_group("population_manager")
	call_deferred("refresh_population")


func _process(_delta: float) -> void:
	refresh_population()


func register_villager(villager: Node) -> void:
	if villager == null:
		return
	refresh_population()


func unregister_villager(villager: Node) -> void:
	if villager == null:
		return
	refresh_population()


func remove_villager(villager: Node) -> bool:
	if villager == null or not is_instance_valid(villager):
		return false
	if villager.has_method("is_idle") and not villager.is_idle():
		push_warning("PopulationManager：只能删除无业待命居民")
		return false
	if villager.has_method("get_carried_amount") and villager.get_carried_amount() > 0.0:
		push_warning("PopulationManager：居民仍携带资源，不能删除")
		return false
	villager.queue_free()
	call_deferred("refresh_population")
	return true


func register_housing(_source: Node, _capacity: int) -> void:
	refresh_population()


func unregister_housing(_source: Node) -> void:
	refresh_population()


func refresh_population() -> void:
	var next_population: int = get_tree().get_nodes_in_group("villagers").size()
	var next_housing_capacity: int = 0

	for base: Node in get_tree().get_nodes_in_group("bases"):
		if base.has_method("get_housing_capacity"):
			next_housing_capacity += int(base.get_housing_capacity())

	for housing: Node in get_tree().get_nodes_in_group("housing_buildings"):
		if housing.has_method("get_housing_capacity"):
			next_housing_capacity += int(housing.get_housing_capacity())

	if (
		next_population == current_population
		and next_housing_capacity == housing_capacity
	):
		return

	current_population = next_population
	housing_capacity = next_housing_capacity
	population_changed.emit(current_population, housing_capacity)


func get_population() -> int:
	return current_population


func get_housing_capacity() -> int:
	return housing_capacity


func get_free_housing() -> int:
	return housing_capacity - current_population
