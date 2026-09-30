class_name PlayerCommand
extends RefCounted
## One physics tick of player input. Movement and weapons read only this,
## so the same logic can later run from network input.

var move: Vector2 = Vector2.ZERO ## x = right, y = back (Input.get_vector order).
var jump: bool = false ## Pressed this tick.
var crouch: bool = false ## Held.
var crouch_pressed: bool = false ## Pressed this tick.
var walk: bool = false ## Held.
var fire: bool = false ## Held.
var fire_pressed: bool = false ## Pressed this tick.
var reload: bool = false ## Pressed this tick.
var weapon_slot: int = -1 ## Requested slot this tick, -1 = none.
var melee: bool = false ## Pressed this tick.
var ability: bool = false ## Pressed this tick.
