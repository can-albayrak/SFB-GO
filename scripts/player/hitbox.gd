class_name Hitbox
extends Area3D
## Damage zone hit by hitscan rays. Lives on physics layer 3 (hitbox).
## The scene root that owns this hitbox receives the damage via take_hit().

enum Zone { HEAD, BODY, LEG }

@export var zone: Zone = Zone.BODY

@onready var _shape: CollisionShape3D = $Shape


func get_receiver() -> Node:
	return owner


func set_enabled(enabled: bool) -> void:
	_shape.set_deferred(&"disabled", not enabled)


## pose.x = centre height, pose.y = box height (0 keeps the current shape).
## Box shapes must be resource_local_to_scene so instances do not share them.
func set_pose(pose: Vector2) -> void:
	position.y = pose.x
	var box := _shape.shape as BoxShape3D
	if box != null and pose.y > 0.0:
		box.size.y = pose.y
