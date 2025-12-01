@tool
extends Node

var mat := {}
var mat_floor := [] # from map generation
var used_floor := [] # array of coords; updated during props placement
var props := {}
const prop_types = [
	'MAP', # the procedurally generated map
	'BS', # bookshelf
]

func init_props() -> void:
	for key in prop_types:
		props[key] = false # initial value is false; none of this type were placed

func get_prop_state(key: String) -> bool:
	return props[key]

func set_prop_state(key: String) -> void:
	props[key] = true

func set_mat(new_mat) -> void:
	mat = new_mat
	mat_floor.clear()
	used_floor.clear()

func set_floors(pos: Array) -> void:
	mat_floor.clear()
	used_floor.clear()
	mat_floor = pos
	
func find_floor(pos: Array) -> int:
	return mat_floor.find(pos)

func add_floor(pos: Array) -> void:
	mat_floor.append(pos)

func use_floor(pos: Array) -> void:
	if pos not in used_floor: used_floor.append(pos)
	if mat_floor.has(pos): 
		mat_floor.erase(pos)
