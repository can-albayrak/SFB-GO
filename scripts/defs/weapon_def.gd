class_name WeaponDef
extends Resource
## Balance data for one weapon. Values live in data/weapons/*.tres, never in code.

enum FireType { HITSCAN, PROJECTILE, MELEE, THROWN }
## Which first-person hands hold the weapon (the view model arms follow it).
enum ViewHands { NONE, RIGHT, BOTH }

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
## Kills with it count toward the Most Knife Kills award (V knife, throwing knives).
@export var counts_as_knife: bool = false
@export var kill_ammo_reward: bool = true ## False: kills never add rounds (airdrop weapons, throwing knives).
## Two guns sharing the magazine: left click fires the left, right click the right,
## each with its own fire_interval (Dual Pistols).
@export var dual_wield: bool = false

@export_group("Airdrop")
## Airdrop weapon (GDD "Airdrop"): the magazine is all the ammo there is (no reload), the
## host counts it, the gun is gone when empty and drops with its rounds when the carrier dies.
@export var airdrop: bool = false
@export var carry_speed_mult: float = 1.0 ## Carrier's speed while it is in the inventory.
@export var pierce_walls: bool = false ## Railgun: the beam goes through every wall.
@export var spin_up_time: float = 0.0 ## Minigun: seconds of holding fire before it shoots.

@export_group("Recoil")
## Per-shot kick of the aim in degrees: x = right, y = up (CS spray: climb first, then sway).
## Shots past the end loop back to recoil_loop_start, so a long spray sways side to side
## instead of climbing forever.
@export var recoil_pattern: PackedVector2Array
## Index the pattern loops back to; -1 = the last entry only.
@export var recoil_loop_start: int = -1
## The kick never takes the aim more than this many degrees above where it started.
@export var recoil_max_up: float = 8.0
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

@export_group("Pellets")
## Shotgun: one hitscan ray per entry, offset from the aim by (right, up) degrees. A fixed,
## learnable pattern, computed the same way by the owner (visuals) and the host (damage).
@export var pellet_pattern: PackedVector2Array
## Damage falloff by distance: full up to falloff_start, then linear down to
## falloff_min_mult at falloff_end and beyond. falloff_end <= falloff_start = no falloff.
@export var falloff_start: float = 0.0
@export var falloff_end: float = 0.0
@export var falloff_min_mult: float = 1.0

@export_group("Launcher")
@export var grenade: GrenadeDef ## Explosive fired by a PROJECTILE weapon (Grenade Launcher).
## Rocket Launcher (Half-Life style): right click toggles laser guidance; while it is on
## and the launcher is in hand, live rockets steer towards where the shooter aims.
@export var guidable: bool = false

@export_group("Melee")
@export var melee_spread_scale: float = 1.0 ## Widens the fan of hit rays (Sledgehammer).
@export var melee_swing_angle: float = 70.0 ## View sweep per swing in degrees; 0 = no sweep (Chainsaw).
@export var knockback: float = 0.0 ## Metres/second pushed onto a player hit (Kick).
## Held knife only (not the V quick swing): damage of a hit from behind (CS backstab). 0 = none.
@export var backstab_damage: float = 0.0
## How far behind counts: dot of the victim's facing and the attacker-to-victim direction
## (CS: 0.475, about 60 degrees either side of straight behind).
@export var backstab_dot: float = 0.475
## Held knife right click (CS:GO): a slower, heavier stab. 0 = no heavy attack.
@export var heavy_damage: float = 0.0
@export var heavy_interval: float = 1.0 ## Seconds after a heavy stab before the knife is ready again.
@export var heavy_backstab_damage: float = 0.0 ## A heavy stab from behind.

@export_group("Thrown")
@export var throw_speed: float = 22.0
@export var throw_lift: float = 2.0 ## Extra upward speed, so throws arc.
@export var throw_gravity: float = 14.0 ## m/s^2 pulling a thrown item down (lower = flatter flight).
@export var projectile_radius: float = 0.0 ## Hit area around a thrown item's path (0 = a thin ray).
@export var return_time: float = 8.0 ## Seconds until a thrown item is back in the inventory.
@export var projectile: PackedScene

@export_group("Scope")
@export var scope_zoom: float = 0.0 ## 0 = no scope; otherwise right mouse zooms by this factor.
@export var scope_move_mult: float = 0.5 ## Speed multiplier while scoped (no sprint).
@export var scope_sway: float = 0.0 ## Degrees of view sway while scoped (halved when crouched).
## Degrees of random cone when firing without the scope (every shot for a gun without one).
@export var unscoped_spread: float = 0.0
## Seconds from right click to full zoom. The unscoped cone fades out over the same time,
## so a shot fired mid-zoom is still inaccurate (no instant quick scopes).
@export var scope_in_time: float = 0.0
## False: no crosshair while this gun is in hand and not scoped (snipers, CS style).
@export var hip_crosshair: bool = true

@export_group("Scene")
@export var scene: PackedScene ## Visual + behaviour (Weapon subclass).

@export_group("View Model")
@export var view_hands: ViewHands = ViewHands.BOTH

@export_group("World Model")
## What other players see in this player's hand (a model, no script). Null = empty hand.
@export var world_model: PackedScene
@export var world_model_scale: float = 1.0
## Muzzle position on the unscaled world model (remote tracers start here).
@export var world_muzzle: Vector3 = Vector3(0.0, 0.035, -0.62)


## Average seconds per shot over sustained fire (host rate check). For bursts the
## trigger interval is shared by all shots of the burst.
func get_average_shot_interval() -> float:
	return fire_interval / maxi(burst_count, 1) / (2.0 if dual_wield else 1.0)


## Damage multiplier for a hit `distance` metres away (shotgun falloff).
func get_falloff_mult(distance: float) -> float:
	if falloff_end <= falloff_start:
		return 1.0
	var share: float = clampf((distance - falloff_start) / (falloff_end - falloff_start), 0.0, 1.0)
	return lerpf(1.0, falloff_min_mult, share)


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
