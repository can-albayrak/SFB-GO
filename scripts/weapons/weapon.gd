class_name Weapon
extends Node3D
## Base weapon: ammo, fire rate, reload and recoil state. Subclasses implement _fire().
## Reserve ammo is unlimited (GDD); only the magazine matters.

signal ammo_changed(ammo: int, magazine_size: int)
signal reload_changed(is_reloading: bool)

## Recoil starts recovering this long after the next shot would have been ready.
const RECOIL_HOLD_TIME: float = 0.08

var def: WeaponDef
var player: Player
var ammo: int = 0
var is_reloading: bool = false
## Current view kick in degrees (x = right, y = up). Player adds it to the aim.
var recoil_offset: Vector2 = Vector2.ZERO

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
	recoil_offset = Vector2.ZERO
	_shot_index = 0


func tick(delta: float, cmd: PlayerCommand) -> void:
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

	var wants_fire: bool = cmd.fire if def.automatic else cmd.fire_pressed
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


func _fire() -> void:
	pass


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


func _apply_recoil_kick() -> void:
	if def.recoil_pattern.is_empty():
		return
	var index: int = mini(_shot_index, def.recoil_pattern.size() - 1)
	recoil_offset += def.recoil_pattern[index]
	_shot_index += 1


func _update_recoil(delta: float) -> void:
	if _since_shot < def.fire_interval + RECOIL_HOLD_TIME:
		return
	recoil_offset = recoil_offset.move_toward(Vector2.ZERO, def.recoil_recovery * delta)
	if recoil_offset == Vector2.ZERO:
		_shot_index = 0
