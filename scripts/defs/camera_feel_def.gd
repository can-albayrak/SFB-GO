class_name CameraFeelDef
extends Resource
## Camera feel tuning: speed FOV shift, head bob, landing dip, slide camera, damage shake, recoil.
## Values live in data/camera/*.tres; each player scales every effect in Settings (0 = off).

@export_group("FOV Shift")
@export var fov_shift_max: float = 4.0 ## Degrees (horizontal FOV, 4:3) added at full speed.
@export var fov_shift_start_speed: float = 7.0 ## m/s; no shift at or below this.
@export var fov_shift_full_speed: float = 11.0 ## m/s; the full shift at and above this.
@export var fov_shift_smoothing: float = 6.0 ## Per second.

@export_group("Head Bob")
@export var bob_height: float = 0.012 ## Metres up and down at bob_ref_speed.
@export var bob_sway: float = 0.008 ## Metres side to side at bob_ref_speed.
@export var bob_cycles_per_metre: float = 0.28 ## One cycle = two steps.
@export var bob_ref_speed: float = 6.6 ## m/s for the full bob; slower movement bobs less.
@export var bob_blend: float = 8.0 ## Per second; how fast the bob fades in and out.

@export_group("Landing")
@export var landing_dip: float = 0.07 ## Metres the view drops on a hard landing.
@export var landing_min_fall_speed: float = 3.0 ## m/s; softer landings do nothing.
@export var landing_full_fall_speed: float = 10.0 ## m/s; the full dip at and above this.
@export var landing_recover: float = 9.0 ## Per second.
@export var landing_follow: float = 25.0 ## Per second; how fast the view moves into the dip.

@export_group("Slide")
@export var slide_drop: float = 0.08 ## Extra metres below the crouch eye height.
@export var slide_tilt: float = 2.5 ## Degrees of roll.
@export var slide_smoothing: float = 10.0 ## Per second.

@export_group("Damage Shake")
@export var shake_angle: float = 0.7 ## Degrees at shake_full_damage or more.
@export var shake_full_damage: float = 40.0
@export var shake_min_share: float = 0.35 ## Small hits still shake this share of the full angle.
@export var shake_time: float = 0.18
@export var shake_frequency: float = 30.0 ## Hz.

@export_group("Shot Kick")
@export var kick_recover: float = 9.0 ## Per second; how fast a WeaponDef.view_kick settles.
@export var kick_view_share: float = 0.3 ## Share of the kick the camera follows (aim unchanged).
@export var kick_back: float = 0.007 ## Metres the gun slides back per degree of kick.
@export var kick_roll: float = 0.25 ## Degrees of roll per degree of kick (alternating side).

@export_group("Hit Feedback")
## View punch (same units as WeaponDef.view_kick) on the shooter when the host confirms a
## headshot / a kill. No time-scale hit stop: the game runs on the network clock.
@export var hit_head_kick: float = 1.2
@export var kill_kick: float = 2.4
@export_group("View Model")
## Every first-person weapon is drawn this much bigger (hands follow the grips). Snipers
## already have their own 1.25x in their scenes.
@export var view_model_scale: float = 1.15

@export_group("Damage Overlay")
@export var hurt_flash_alpha: float = 0.35 ## Red at the screen edges right after a hit of hurt_full_damage.
@export var hurt_full_damage: float = 40.0
@export var hurt_min_share: float = 0.4 ## Small hits still flash this share.
@export var hurt_flash_time: float = 0.45 ## Seconds the flash fades over.
@export var low_health_start: float = 0.6 ## Health share where the lasting red edge begins.
@export var low_health_alpha: float = 0.5 ## Red edge strength at 1 health.
## Hit direction: a thin, faint red arc around the crosshair pointing toward the attacker.
@export var hit_dir_alpha: float = 0.4
@export var hit_dir_time: float = 1.0 ## Seconds it fades over.
@export var hit_dir_radius: float = 0.12 ## Share of the screen height from the centre.
@export var hit_dir_arc_degrees: float = 36.0
@export var hit_dir_width: float = 3.0 ## Pixels at 1080p.

@export_group("Recoil")
## Share of the weapon's recoil the view follows. 0: the crosshair stays where it is and the
## shots climb away from it by the pattern (Can's call); 1: the view is kicked as far as the shots.
@export var recoil_view_share: float = 0.0
## The gun in view tips up this many degrees per degree of recoil (so the kick still shows)...
@export var recoil_model_pitch: float = 0.6
## ...and slides back this many metres per degree, up to recoil_model_max_back.
@export var recoil_model_back: float = 0.012
@export var recoil_model_max_back: float = 0.06
