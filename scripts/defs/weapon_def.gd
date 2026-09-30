class_name WeaponDef
extends Resource
## Balance data for one weapon. Values live in data/weapons/*.tres, never in code.

enum FireType { HITSCAN, PROJECTILE, MELEE, THROWN }

@export var id: StringName
@export var display_name: String
@export var fire_type: FireType = FireType.HITSCAN

@export_group("Damage")
@export var damage: float = 20.0
@export var headshot_mult: float = 2.0
@export var leg_mult: float = 0.75
@export var max_range: float = 250.0

@export_group("Handling")
@export var fire_interval: float = 0.1 ## Seconds between shots.
@export var automatic: bool = true ## Hold to fire; false = one shot per click.
@export var magazine_size: int = 30
@export var reload_time: float = 2.0
@export var equip_time: float = 0.4
@export var move_speed_mult: float = 1.0

@export_group("Recoil")
## Per-shot view kick in degrees: x = right, y = up. Shots past the end reuse the last entry.
@export var recoil_pattern: PackedVector2Array
## Degrees per second the view returns once firing stops.
@export var recoil_recovery: float = 12.0

@export_group("Scene")
@export var scene: PackedScene ## Visual + behaviour (Weapon subclass).


func zone_multiplier(zone: Hitbox.Zone) -> float:
	match zone:
		Hitbox.Zone.HEAD:
			return headshot_mult
		Hitbox.Zone.LEG:
			return leg_mult
	return 1.0
