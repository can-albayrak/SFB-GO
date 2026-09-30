class_name MovementDef
extends Resource
## Movement tuning. Values live in data/movement/*.tres.
## Class speed differences come from ClassDef.move_speed; this holds the feel.

@export_group("Ground")
@export var ground_accel: float = 10.0
@export var friction: float = 6.0
@export var stop_speed: float = 2.0 ## Below this speed friction acts as if moving this fast (quick stops).
@export var walk_mult: float = 0.52
@export var crouch_mult: float = 0.4

@export_group("Air")
@export var gravity: float = 16.0
@export var jump_velocity: float = 5.6
@export var air_accel: float = 12.0
@export var air_speed_cap: float = 0.8 ## Limits air gain per direction, which is what makes strafing work.
@export var bhop_cap_mult: float = 1.3 ## Horizontal speed is clamped to base * this on every jump.
@export var jump_buffer_time: float = 0.08 ## Jump pressed this early before landing still counts.

@export_group("Slide")
@export var slide_min_speed_mult: float = 0.85
@export var slide_boost_mult: float = 1.2
@export var slide_friction: float = 0.8
@export var slide_duration: float = 0.75
@export var slide_cooldown: float = 0.8
