class_name GrenadeDef
extends AbilityDef
## Throwable ability (Frag Grenade, Flashbang). Values live in data/abilities/*.tres.

enum Kind { FRAG, FLASH }

@export var kind: Kind = Kind.FRAG
@export var projectile: PackedScene
@export var throw_speed: float = 16.0 ## m/s along the aim.
@export var throw_lift: float = 3.0 ## Extra upward m/s for a nicer arc.
@export var fuse_time: float = 2.5
@export var radius: float = 5.0 ## Frag: damage radius. Flash: max blind distance.
@export var damage: float = 100.0 ## Frag: damage at the centre, linear falloff to 0 at radius.
@export var flash_duration: float = 3.0 ## Flash: seconds when looking straight at it up close.
