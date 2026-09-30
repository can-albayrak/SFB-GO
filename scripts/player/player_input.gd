class_name PlayerInput
extends Node
## Reads local keyboard/mouse. Only active on the owning client.
## Mouse look is applied immediately; everything else is packed into a PlayerCommand per tick.

const MAX_PITCH: float = deg_to_rad(89.0)

var _suppress_fire: bool = false

@onready var player: Player = get_parent()


func _ready() -> void:
	if not is_multiplayer_authority():
		set_process_unhandled_input(false)
		return
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	var captured: bool = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	if event is InputEventMouseMotion and captured:
		var motion: InputEventMouseMotion = event
		var rad_per_count: float = deg_to_rad(Settings.get_look_degrees_per_count())
		player.rotate_y(-motion.screen_relative.x * rad_per_count)
		player.look_pitch = clampf(player.look_pitch - motion.screen_relative.y * rad_per_count, -MAX_PITCH, MAX_PITCH)
	elif event.is_action_pressed(&"respawn") and multiplayer.multiplayer_peer is OfflineMultiplayerPeer:
		# Offline test range only: instant respawn, dead or alive.
		var game: Game = Game.find(get_tree())
		if game != null:
			game.test_respawn(player)
	elif event.is_action_pressed(&"pause_menu") and captured:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and event.is_pressed() and not captured:
		# The click that recaptures the mouse must not also fire.
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		_suppress_fire = true
		get_viewport().set_input_as_handled()


func gather() -> PlayerCommand:
	var cmd := PlayerCommand.new()
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return cmd

	cmd.move = Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back")
	cmd.jump = Input.is_action_just_pressed(&"jump")
	cmd.crouch = Input.is_action_pressed(&"crouch")
	cmd.crouch_pressed = Input.is_action_just_pressed(&"crouch")
	cmd.sprint = Input.is_action_pressed(&"sprint")
	cmd.reload = Input.is_action_just_pressed(&"reload")
	cmd.melee = Input.is_action_just_pressed(&"melee")
	cmd.ability = Input.is_action_just_pressed(&"ability")

	if _suppress_fire and not Input.is_action_pressed(&"fire"):
		_suppress_fire = false
	if not _suppress_fire:
		cmd.fire = Input.is_action_pressed(&"fire")
		cmd.fire_pressed = Input.is_action_just_pressed(&"fire")

	if Input.is_action_just_pressed(&"weapon_primary"):
		cmd.weapon_slot = 0
	elif Input.is_action_just_pressed(&"weapon_secondary"):
		cmd.weapon_slot = 1
	return cmd
