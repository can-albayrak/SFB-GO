class_name Hitbox
extends Area3D
## Damage zone hit by hitscan rays. Lives on physics layer 3 (hitbox).
## The scene root that owns this hitbox receives the damage via take_hit().

enum Zone { HEAD, BODY, LEG }

@export var zone: Zone = Zone.BODY


func get_receiver() -> Node:
	return owner
