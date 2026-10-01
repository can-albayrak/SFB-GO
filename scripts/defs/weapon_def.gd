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
@export var burst_count: int = 1 ## Shots per trigger pull (>1 = burst weapon, fired per click).
@export var burst_interval: float = 0.07 ## Seconds between shots inside a burst.
@export var magazine_size: int = 30
@export var reload_time: float = 2.0
@export var equip_time: float = 0.4
@export var move_speed_mult: float = 1.0
@export var uses_ammo: bool = true ## False = never runs dry (melee weapons).

@export_group("Recoil")
## Per-shot view kick in degrees: x = right, y = up. Shots past the end reuse the last entry.
@export var recoil_pattern: PackedVector2Array
## Degrees per second the view returns once firing stops.
@export var recoil_recovery: float = 12.0
## Recovery starts this long after the next shot would have been ready.
@export var recoil_recovery_delay: float = 0.08

@export_group("Movement Spread")
## Degrees of random cone when firing at move_spread_ref_speed. No threshold: the cone
## follows a curve, (speed / ref) ^ exponent, so walking is a little off and running more.
@export var move_spread: float = 0.0
@export var move_spread_ref_speed: float = 6.6 ## m/s where the cone equals move_spread.
@export var move_spread_exponent: float = 1.5 ## > 1: slow movement is barely punished.

@export_group("Melee")
@export var melee_spread_scale: float = 1.0 ## Widens the fan of hit rays (Sledgehammer).
@export var melee_swing_angle: float = 70.0 ## View sweep per swing in degrees; 0 = no sweep (Chainsaw).
@export var knockback: float = 0.0 ## Metres/second pushed onto a player hit (Kick).

@export_group("Thrown")
@export var throw_speed: float = 22.0
@export var throw_lift: float = 2.0 ## Extra upward speed, so throws arc.
@export var return_time: float = 8.0 ## Seconds until a thrown item is back in the inventory.
@export var projectile: PackedScene

@export_group("Scope")
@export var scope_zoom: float = 0.0 ## 0 = no scope; otherwise right mouse zooms by this factor.
@export var scope_move_mult: float = 0.5 ## Speed multiplier while scoped (no sprint).
@export var scope_sway: float = 0.0 ## Degrees of view sway while scoped (halved when crouched).
@export var unscoped_spread: float = 0.0 ## Degrees of random cone when firing without the scope.

@export_group("Scene")
@export var scene: PackedScene ## Visual + behaviour (Weapon subclass).


## Average seconds per shot over sustained fire (host rate check). For bursts the
## trigger interval is shared by all shots of the burst.
func get_average_shot_interval() -> float:
	return fire_interval / maxi(burst_count, 1)


## Degrees of cone added by moving at `speed` m/s (gradual speed penalty).
func get_move_spread(speed: float) -> float:
	if move_spread <= 0.0 or move_spread_ref_speed <= 0.0 or speed <= 0.0:
		return 0.0
	return move_spread * pow(speed / move_spread_ref_speed, move_spread_exponent)


func zone_multiplier(zone: Hitbox.Zone) -> float:
	match zone:
		Hitbox.Zone.HEAD:
			return headshot_mult
		Hitbox.Zone.LEG:
			return leg_mult
	return 1.0
