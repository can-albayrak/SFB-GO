class_name CameraFeelDef
extends Resource
## Camera feel tuning: speed FOV shift, head bob, landing dip, slide camera, damage shake.
## Values live in data/camera/*.tres; each player scales every effect in Settings (0 = off).

@export_group("FOV Shift")
@export var fov_shift_max: float = 4.0 ## Degrees (horizontal FOV, 4:3) added at full speed.
@export var fov_shift_start_speed: float = 6.0 ## m/s; no shift at or below this.
@export var fov_shift_full_speed: float = 10.0 ## m/s; the full shift at and above this.
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
