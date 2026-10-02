class_name MapList
extends Resource
## Maps the host can pick in the lobby (data/maps/map_list.tres), in menu order.
## The first one is the lobby default.

@export var maps: Array[MapDef]


func get_map(index: int) -> MapDef:
	return maps[clampi(index, 0, maps.size() - 1)] if not maps.is_empty() else null
