class_name Decoy
extends CharacterBody3D
## Copy of a player's body (Hawk Decoy) that looks exactly like them: same model, same
## colours, no hologram tint. It keeps the player's momentum and moves with the same gravity
## and ground friction, so a decoy dropped mid-jump falls and lands like a real player.
## Player-layer capsule: people bump into it and explosives burst on it; hitscan shots pass
## through (no hitbox), as before. Cosmetic: runs on every peer from the same start state.

const BLINK_TIME: float = 1.5 ## Flickers for this long before vanishing.
const BLINK_PERIOD: float = 0.15
const CAPSULE_RADIUS: float = 0.35
const CAPSULE_HEIGHT: float = 1.8
const PLAYER_LAYER: int = 2
const WORLD_MASK: int = 1
const DEFAULT_GRAVITY: float = 20.3
const DEFAULT_FRICTION: float = 6.0
const STOP_SPEED: float = 2.0

var _left: float = 0.0
var _gravity: float = DEFAULT_GRAVITY
var _friction: float = DEFAULT_FRICTION
var _body: Node3D


## `source` is the player's Model node; its look is copied, frozen at this pose.
static func create(source: Node3D, at: Vector3, yaw: float, seconds: float, start_velocity: Vector3, move_def: MovementDef) -> Decoy:
	var decoy := Decoy.new()
	decoy._left = seconds
	decoy.velocity = start_velocity
	if move_def != null:
		decoy._gravity = move_def.gravity
		decoy._friction = move_def.friction
	decoy.collision_layer = PLAYER_LAYER
	decoy.collision_mask = WORLD_MASK
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = CAPSULE_RADIUS
	capsule.height = CAPSULE_HEIGHT
	shape.shape = capsule
	shape.position = Vector3(0.0, CAPSULE_HEIGHT * 0.5, 0.0)
	decoy.add_child(shape)
	var body: Node3D = source.duplicate()
	body.visible = true
	SoldierRig.clear_reveal(body)
	for extra: String in ["Crown", "Glint"]: # Leader crown and scope glint stay on the player.
		var node: Node = body.get_node_or_null(extra)
		if node != null:
			body.remove_child(node)
			node.queue_free()
	decoy._body = body
	decoy.add_child(body)
	decoy.position = at
	decoy.rotation.y = yaw
	return decoy


func _physics_process(delta: float) -> void:
	if is_on_floor():
		var horizontal := Vector2(velocity.x, velocity.z)
		var speed: float = horizontal.length()
		if speed > 0.0:
			var drop: float = maxf(speed, STOP_SPEED) * _friction * delta
			horizontal *= maxf(speed - drop, 0.0) / speed
			velocity.x = horizontal.x
			velocity.z = horizontal.y
		velocity.y = maxf(velocity.y, 0.0)
	else:
		velocity.y -= _gravity * delta
	move_and_slide()


func _process(delta: float) -> void:
	_left -= delta
	if _left <= 0.0:
		queue_free()
		return
	if _left < BLINK_TIME:
		_body.visible = fmod(_left, BLINK_PERIOD * 2.0) < BLINK_PERIOD
