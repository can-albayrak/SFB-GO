class_name DualPistolsWeapon
extends HitscanWeapon
## Cheetah's Dual Pistols: two semi-automatic guns sharing one magazine. Left click fires
## the left gun (base Weapon trigger), right click the right gun with its own cooldown.
## The host allows two shots per fire_interval (WeaponDef.dual_wield).

enum Hand { LEFT, RIGHT }

var _right_cooldown: float = 0.0
var _hand: Hand = Hand.LEFT

@onready var _right_muzzle: Marker3D = $Muzzle
@onready var _left_muzzle: Marker3D = $LeftMuzzle


func draw() -> void:
	super.draw()
	_right_cooldown = def.equip_time


func refill() -> void:
	super.refill()
	_right_cooldown = 0.0


func tick(delta: float, cmd: PlayerCommand) -> void:
	_right_cooldown = maxf(_right_cooldown - delta, 0.0)
	_hand = Hand.LEFT
	super.tick(delta, cmd) # Left trigger, reload and recoil.
	if is_reloading or not cmd.secondary_pressed or _right_cooldown > 0.0:
		return
	if ammo <= 0:
		_start_reload()
		return
	_right_cooldown = get_fire_interval()
	_hand = Hand.RIGHT
	_burst_left = 1
	_shoot_once()


func _fire() -> void:
	muzzle = _left_muzzle if _hand == Hand.LEFT else _right_muzzle
	super._fire()
