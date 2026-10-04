class_name Weapon
extends Node3D
## Base weapon: ammo, fire rate, reload and recoil state. Subclasses implement
## _fire() (owning client: effects + request to host) and server_fire() (host: damage).
## Reserve ammo is unlimited (GDD); only the magazine matters.

signal ammo_changed(ammo: int, magazine_size: int)
## Slow guns (bolt, pump, launchers) start settling the kick this soon after a shot instead of
## after their whole fire interval; otherwise the view drifts down long after you re-aimed.
const RECOIL_SETTLE_WAIT_CAP: float = 0.2
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
var _burst_left: int = 0
var _burst_timer: float = 0.0
var _spin: float = 0.0 ## Minigun: seconds of spin built up by holding fire.

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
	_spin = 0.0
	_burst_left = 0
	_set_reloading(false)
	_reset_recoil()


func refill() -> void:
	_burst_left = 0
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
		_reload_left -= delta * player.status.get_reload_speed_mult()
		if _reload_left <= 0.0:
			ammo = def.magazine_size
			_set_reloading(false)
			ammo_changed.emit(ammo, def.magazine_size)
		return

	if _burst_left > 0:
		_burst_timer -= delta
		if _burst_timer <= 0.0:
			_shoot_once()
		return

	if cmd.reload and ammo < def.magazine_size:
		_start_reload()
		return

	# fire_pressed also counts for automatics, so a click shorter than one tick still fires.
	var wants_fire: bool = cmd.fire_pressed or (def.automatic and cmd.fire)
	if def.spin_up_time > 0.0:
		# Minigun: barrels spin up while fire is held and run down when released.
		_spin = minf(_spin + delta, def.spin_up_time) if wants_fire else maxf(_spin - delta * 2.0, 0.0)
		if _spin < def.spin_up_time:
			return
	if not wants_fire or _cooldown > 0.0:
		return
	if def.uses_ammo and ammo <= 0:
		_start_reload()
		return

	_cooldown = get_fire_interval() # Burst weapons: time between burst starts.
	_burst_left = maxi(def.burst_count, 1)
	_shoot_once()


## Seconds between trigger pulls right now (Adrenaline shortens it).
func get_fire_interval() -> float:
	return def.fire_interval / player.status.get_fire_rate_mult()


## Owner: one more round in the magazine (a thrown knife came back).
func add_ammo(count: int) -> void:
	ammo = mini(ammo + count, def.magazine_size)
	ammo_changed.emit(ammo, def.magazine_size)


## Blocks firing without touching ammo (quick melee swing).
func is_busy() -> bool:
	return _burst_left > 0


func _shoot_once() -> void:
	if def.uses_ammo and ammo <= 0:
		_burst_left = 0
		return
	if def.uses_ammo and not Match.rules.infinite_ammo:
		ammo -= 1
	_burst_left -= 1
	_burst_timer = def.burst_interval / player.status.get_fire_rate_mult()
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
	if ammo >= def.magazine_size or def.airdrop: # Airdrop weapons: the magazine is all there is.
		return
	_reload_left = def.reload_time
	_set_reloading(true)
	player.effects.report_action(SoldierRig.Action.RELOAD, def.reload_time / player.status.get_reload_speed_mult())


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
	recoil_offset += def.recoil_pattern[recoil_index(_shot_index)]
	recoil_offset.y = minf(recoil_offset.y, def.recoil_max_up)
	_shot_index += 1


## Pattern entry for the `shot`th shot of a spray: past the end it loops from recoil_loop_start.
func recoil_index(shot: int) -> int:
	var size: int = def.recoil_pattern.size()
	if shot < size:
		return shot
	var loop_start: int = clampi(def.recoil_loop_start, 0, size - 1) if def.recoil_loop_start >= 0 else size - 1
	return loop_start + (shot - size) % (size - loop_start)


func _update_recoil(delta: float) -> void:
	if _since_shot < minf(def.fire_interval, RECOIL_SETTLE_WAIT_CAP) + def.recoil_recovery_delay:
		return
	recoil_offset = recoil_offset.move_toward(Vector2.ZERO, def.recoil_recovery * delta)
	if recoil_offset == Vector2.ZERO:
		_shot_index = 0
