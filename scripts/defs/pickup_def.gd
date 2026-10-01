class_name PickupDef
extends Resource
## A map pickup (GDD "Pickup'lar"). Values live in data/pickups/*.tres.

enum Kind { HEALTH, SPEED, DOUBLE_JUMP }

@export var id: StringName
@export var display_name: String
@export var kind: Kind = Kind.HEALTH
@export var heal: int = 0 ## HEALTH: health given (never above the class maximum).
@export var duration: float = 0.0 ## SPEED / DOUBLE_JUMP: seconds the effect lasts.
@export var speed_mult: float = 1.0 ## SPEED: movement speed multiplier.
@export var respawn_time: float = 45.0 ## Seconds until it is back after being taken.
@export var color: Color = Color.WHITE ## Pickup and the glow of a player under its effect.
