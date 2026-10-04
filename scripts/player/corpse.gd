class_name Corpse
extends Node3D
## Cosmetic body left where a player died: plays the death clip, lies still, then sinks
## away. No collision or hitbox; the death itself was decided by the host.

const PLAY_SPEED: float = 1.4
const LIFETIME: float = 5.0
const SINK_TIME: float = 0.8
const SINK_DEPTH: float = 0.5

var _left: float = LIFETIME


## `source` is the dead player's Model node (position and yaw are copied).
static func create(source: Node3D) -> Corpse:
	var corpse := Corpse.new()
	corpse.name = "Corpse"
	corpse.transform = source.global_transform.orthonormalized()
	corpse.add_child(SoldierRig.create())
	return corpse


func _ready() -> void:
	(get_child(0) as SoldierRig).play_clip(&"dying", PLAY_SPEED)


func _process(delta: float) -> void:
	_left -= delta
	if _left <= 0.0:
		queue_free()
	elif _left < SINK_TIME:
		position.y -= SINK_DEPTH / SINK_TIME * delta
