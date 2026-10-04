class_name ThrowingKnifeWeapon
extends Weapon
## Bear's secondary: a few throwing knives. Ammo is the knives in hand; there is no reload,
## thrown knives come back by pickup or timer (see ThrownKnife). Host spawns the projectile.
## Owner view: a throw snaps the hand forward with the knife gone from it, drops the hand out of
## view and brings it back with the next knife (none left: the hand comes back empty).

const THROW_TIME: float = 0.45
## Throw keys as offsets from the rest pose in the holder's space: position (metres), rotation
## (degrees). The arm follows the hand (IK).
const RELEASE_POS: Vector3 = Vector3(-0.05, 0.07, -0.2)
const RELEASE_ROT: Vector3 = Vector3(-45.0, -10.0, 0.0)
const LOW_POS: Vector3 = Vector3(0.03, -0.32, 0.06)
const LOW_ROT: Vector3 = Vector3(20.0, 0.0, 0.0)
const RELEASE_END: float = 0.25 ## Share of the throw spent snapping forward...
const LOW_END: float = 0.55 ## ...and dropping out of view; the rest brings the next knife up.

var _rest: Transform3D
var _tween: Tween

@onready var _model: Node3D = $Model


func _ready() -> void:
	_rest = transform
	ammo_changed.connect(_on_ammo_changed)


func holster() -> void:
	super.holster()
	_stop_throw()


## Owner: the host spawns the knife, so the request and the view throw are all there is to do.
func _fire() -> void:
	_play_throw()
	player.send_fire(player.get_aim_origin(), -player.get_aim_basis().z, player.weapons.find(self))


func server_fire(origin: Vector3, dir: Vector3) -> Vector3:
	assert(multiplayer.is_server(), "server_fire is host-only")
	var game: Game = Game.find(get_tree())
	if game == null:
		return origin
	var launch: Array = player.get_throw_launch(origin, dir, def.throw_speed, def.throw_lift)
	game.server_spawn_knife(def, player.get_multiplayer_authority(), launch[0], launch[1])
	return launch[0]


## No reloading: knives return on their own.
func _start_reload() -> void:
	pass


func _play_throw() -> void:
	_stop_throw()
	_model.visible = false # Out of the hand on the first frame: the knife is in the air.
	_tween = create_tween()
	_tween.tween_method(_set_throw_pose, 0.0, 1.0, THROW_TIME)
	_tween.finished.connect(_stop_throw)


## Throw pose at `t` (0..1): rest -> release -> low (out of view) -> rest, eased per segment.
func _set_throw_pose(t: float) -> void:
	var release := Transform3D(Basis.from_euler(_to_radians(RELEASE_ROT)), RELEASE_POS)
	var low := Transform3D(Basis.from_euler(_to_radians(LOW_ROT)), LOW_POS)
	var pose: Transform3D
	if t < RELEASE_END:
		pose = Transform3D.IDENTITY.interpolate_with(release, _ease(t / RELEASE_END))
	elif t < LOW_END:
		pose = release.interpolate_with(low, _ease((t - RELEASE_END) / (LOW_END - RELEASE_END)))
	else:
		_model.visible = ammo > 0 # The next knife, picked up below the view.
		pose = low.interpolate_with(Transform3D.IDENTITY, _ease((t - LOW_END) / (1.0 - LOW_END)))
	transform = Transform3D(pose.basis * _rest.basis, _rest.origin + pose.origin)


func _stop_throw() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null
	transform = _rest
	_model.visible = ammo > 0


## A knife came back (or all were refilled): it shows in the hand unless a throw is playing.
func _on_ammo_changed(_ammo: int, _magazine_size: int) -> void:
	if _tween == null:
		_model.visible = ammo > 0


static func _to_radians(degrees: Vector3) -> Vector3:
	return Vector3(deg_to_rad(degrees.x), deg_to_rad(degrees.y), deg_to_rad(degrees.z))


static func _ease(x: float) -> float:
	return x * x * (3.0 - 2.0 * x)
