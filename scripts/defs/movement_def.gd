class_name MovementDef
extends Resource
## Movement tuning. Values live in data/movement/*.tres.
## Class speed differences come from ClassDef.move_speed; this holds the feel.

@export_group("Ground")
@export var ground_accel: float = 10.0
@export var friction: float = 6.0
@export var stop_speed: float = 2.0 ## Below this speed friction acts as if moving this fast (quick stops).
@export var sprint_mult: float = 1.25 ## Shift: run faster than the base speed (stays under the bhop cap).
@export var crouch_mult: float = 0.4

@export_group("Air")
@export var gravity: float = 20.3 ## CS 1.6: 800 u/s^2.
@export var jump_velocity: float = 7.3 ## CS 1.6 is 7.65 m/s (301 u/s); slightly lower for our capsule.
@export var air_accel: float = 10.0 ## CS 1.6 sv_airaccelerate 10.
@export var air_speed_cap: float = 0.8 ## Limits air gain per direction, which is what makes strafing work.
@export var bhop_cap_mult: float = 1.3 ## Horizontal speed is clamped to base * this on every jump.
@export var jump_buffer_time: float = 0.08 ## Jump pressed this early before landing still counts.

@export_group("Slide")
@export var slide_min_speed_mult: float = 0.85
@export var slide_boost_mult: float = 1.35
@export var slide_friction: float = 0.35
@export var slide_duration: float = 1.1
@export var slide_cooldown: float = 0.9
@export var slide_max_speed_mult: float = 1.55 ## Slide boost may exceed the bhop cap up to base * this.
