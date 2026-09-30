class_name Weapon
extends Node3D
## Base weapon: ammo, fire rate, reload and recoil state. Subclasses implement
## _fire() (owning client: effects + request to host) and server_fire() (host: damage).
## Reserve ammo is unlimited (GDD); only the magazine matters.

signal ammo_changed(ammo: int, magazine_size: int)
signal reload_changed(is_reloading: bool)

var def: WeaponDef
var player: Player
var ammo: int = 0
var is_reloading: bool = false
## Current view kick in degrees (x = right, y = up). Player adds it to the aim.
var recoil_offset: Vector2 = Vector2.ZERO

var _prev_recoil: Vector2 = Vector2.ZERO
var _cooldown: float = 0.0
var _reload_left: float = 0.0
var _since_shot: float = INF
var _shot_index: int = 0

@onready var muzzle: Marker3D = $Muzzle


func setup(weapon_def: WeaponDef, owner_player: Player) -> void:
	def = weapon_def
	player = owner_player
	ammo = def.magazine_size


func draw() -> void:
	visible = true
	_cooldown = def.equip_time


func holster() -> void:
	visible = false
	_set_reloading(false)
	_reset_recoil()


func refill() -> void:
	_set_reloading(false)
	_reset_recoil()
	_cooldown = 0.0
	ammo = def.magazine_size
	ammo_changed.emit(ammo, def.magazine_size)


## Recoil for the camera, smoothed between physics ticks.
func get_view_recoil() -> Vector2:
	return _prev_recoil.lerp(recoil_offset, Engine.get_physics_interpolation_fraction())


## Owning client only, once per physics tick while equipped.
func tick(delta: float, cmd: PlayerCommand) -> void:
	_prev_recoil = recoil_offset
	_cooldown = maxf(_cooldown - delta, 0.0)
	_since_shot += delta
	_update_recoil(delta)

	if is_reloading:
		_reload_left -= delta
		if _reload_left <= 0.0:
			ammo = def.magazine_size
			_set_reloading(false)
			ammo_changed.emit(ammo, def.magazine_size)
		return

	if cmd.reload and ammo < def.magazine_size:
		_start_reload()
		return

	# fire_pressed also counts for automatics, so a click shorter than one tick still fires.
	var wants_fire: bool = cmd.fire_pressed or (def.automatic and cmd.fire)
	if not wants_fire or _cooldown > 0.0:
		return
	if ammo <= 0:
		_start_reload()
		return

	ammo -= 1
	_cooldown = def.fire_interval
	_since_shot = 0.0
	_fire() # Aim is read before the kick, so the first shot is always accurate.
	_apply_recoil_kick()
	ammo_changed.emit(ammo, def.magazine_size)


## Owning client: local effects and the fire request to the host.
func _fire() -> void:
	pass


## Host only: resolves the shot and applies damage. Returns the shot end point.
func server_fire(origin: Vector3, _dir: Vector3) -> Vector3:
	return origin


func _start_reload() -> void:
	if ammo >= def.magazine_size:
		return
	_reload_left = def.reload_time
	_set_reloading(true)


func _set_reloading(value: bool) -> void:
	if is_reloading == value:
		return
	is_reloading = value
	reload_changed.emit(value)


func _reset_recoil() -> void:
	recoil_offset = Vector2.ZERO
	_prev_recoil = Vector2.ZERO
	_shot_index = 0


func _apply_recoil_kick() -> void:
	if def.recoil_pattern.is_empty():
		return
	var index: int = mini(_shot_index, def.recoil_pattern.size() - 1)
	recoil_offset += def.recoil_pattern[index]
	_shot_index += 1


func _update_recoil(delta: float) -> void:
	if _since_shot < def.fire_interval + def.recoil_recovery_delay:
		return
	recoil_offset = recoil_offset.move_toward(Vector2.ZERO, def.recoil_recovery * delta)
	if recoil_offset == Vector2.ZERO:
		_shot_index = 0
