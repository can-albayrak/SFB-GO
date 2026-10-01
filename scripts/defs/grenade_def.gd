class_name GrenadeDef
extends AbilityDef
## Host-simulated explosive: thrown abilities (Frag Grenade, Flashbang, Sticky Bomb, Landmine)
## and the Grenade Launcher's round. Values live in data/abilities/*.tres and data/weapons/*.tres.
## The behaviour flags default to a plain fused grenade.

enum Kind { FRAG, FLASH }

@export var kind: Kind = Kind.FRAG
@export var projectile: PackedScene
@export var throw_speed: float = 16.0 ## m/s along the aim.
@export var throw_lift: float = 3.0 ## Extra upward m/s for a nicer arc.
@export var fuse_time: float = 2.5
@export var radius: float = 5.0 ## Frag: damage radius. Flash: max blind distance.
@export var damage: float = 100.0 ## Frag: damage at the centre, linear falloff to 0 at radius.
@export var flash_duration: float = 3.0 ## Flash: seconds when looking straight at it up close.

@export_group("Behaviour")
@export var explode_on_impact: bool = false ## Bursts on the first contact (launcher round).
@export var sticky: bool = false ## Sticks to the first wall or player it touches (Sticky Bomb).
@export var trigger_radius: float = 0.0 ## > 0: a mine; an enemy this close to it sets it off.
@export var arm_time: float = 0.0 ## Mine: seconds after it is thrown before it can trigger.
@export var explode_on_fuse: bool = true ## False: when fuse_time runs out it just disappears.
@export var max_per_thrower: int = 0 ## > 0: older ones of the same kind are removed (mines).
