class_name ChargeAbility
extends Ability
## Bear Charge: a fast dash forward (owner-authoritative movement). The host watches the
## dash and stuns the first enemy it runs into for def.stun_time.

const HIT_RADIUS: float = 1.3 ## Horizontal reach around the charger.
const CENTER_HEIGHT: float = 1.0
const BEHIND_TOLERANCE: float = -0.2 ## Dot with the dash direction; below this the target is behind.

var _active_left: float = 0.0
var _dir: Vector3 = Vector3.ZERO


func _use_local(_origin: Vector3, dir: Vector3) -> void:
	player.movement.start_charge(dir, def.speed, def.duration)


func server_use(_origin: Vector3, dir: Vector3) -> void:
	_dir = Vector3(dir.x, 0.0, dir.z).normalized()
	_active_left = def.duration


func _physics_process(delta: float) -> void:
	if _active_left <= 0.0 or not multiplayer.is_server():
		return
	_active_left -= delta
	if not player.is_alive:
		_active_left = 0.0
		return
	var me: Vector3 = player.global_position + Vector3.UP * CENTER_HEIGHT
	for node: Node in player.get_parent().get_children():
		var target := node as Player
		if target == null or target == player or not target.can_take_damage():
			continue
		var offset: Vector3 = target.global_position + Vector3.UP * CENTER_HEIGHT - me
		var flat := Vector2(offset.x, offset.z)
		if flat.length() > HIT_RADIUS or offset.normalized().dot(_dir) < BEHIND_TOLERANCE:
			continue
		target.server_stun(def.stun_time)
		player.confirm_hit.rpc_id(player.get_multiplayer_authority(), Hitbox.Zone.BODY, false, 0.0, me + offset)
		_active_left = 0.0
		return
