class_name DiceAbility
extends Ability
## Gambler's Roll: the host rolls a die (def.dice_faces, equal odds) and applies the face:
## host-side parts (damage multiplier, health, the speed / fire rate checks, reveals) at once,
## then tells the owner, who feels its own parts (fire rate, free ammo, speed) and sees the
## face on the HUD bar (striped for a bad face).

const SHOW_INSTANT: float = 2.0 ## HUD seconds for a face without a duration.

var _face: DiceFaceDef ## Owner: the last face rolled.
var _face_left: float = 0.0


func tick(delta: float) -> void:
	super(delta)
	_face_left = maxf(_face_left - delta, 0.0)


func get_hud_window() -> Array:
	if _face == null or _face_left <= 0.0:
		return []
	var total: float = _face.duration if _face.duration > 0.0 else SHOW_INSTANT
	return [_face_left, total, _face.title, _face.mood < DiceFaceDef.Mood.NEUTRAL]


func _use_local(_origin: Vector3, _dir: Vector3) -> void:
	Sfx.play_ui(player, Sfx.DICE)


func server_use(_origin: Vector3, _dir: Vector3) -> void:
	if def.dice_faces.is_empty():
		return
	var index: int = randi() % def.dice_faces.size()
	server_apply_face(index)


## Host: applies face `index` (tests call it directly) and tells the owner.
func server_apply_face(index: int) -> void:
	assert(multiplayer.is_server(), "server_apply_face is host-only")
	var face: DiceFaceDef = def.dice_faces[index]
	match face.kind:
		DiceFaceDef.Kind.DAMAGE:
			player.status.server_set_damage_mult(face.damage_mult, face.duration)
		DiceFaceDef.Kind.HOT_HAND:
			player.status.server_start_buff(face.duration, 1.0, face.fire_rate_mult)
		DiceFaceDef.Kind.LUCKY:
			player.health = player.class_def.max_health
			player.status.server_start_buff(face.duration, face.speed_mult, 1.0)
		DiceFaceDef.Kind.REVEAL:
			_server_reveal_all(face.duration)
		DiceFaceDef.Kind.HEALTH:
			player.health = mini(player.health, face.set_health)
	var owner_id: int = player.get_multiplayer_authority()
	if owner_id == multiplayer.get_unique_id() or owner_id in multiplayer.get_peers():
		_show_face.rpc_id(owner_id, index)


## Everyone alive shows through walls to the Gambler, and the Gambler to each of them.
func _server_reveal_all(seconds: float) -> void:
	var gambler_id: int = player.get_multiplayer_authority()
	var found: PackedInt32Array = PackedInt32Array()
	for node: Node in player.get_parent().get_children():
		var other := node as Player
		if other == null or other == player or not other.is_alive:
			continue
		found.append(other.get_multiplayer_authority())
		other.effects.server_show_sonar(PackedInt32Array([gambler_id]), seconds)
	player.effects.server_show_sonar(found, seconds)


@rpc("any_peer", "call_local", "reliable")
func _show_face(index: int) -> void:
	var sender: int = multiplayer.get_remote_sender_id()
	if (sender if sender != 0 else multiplayer.get_unique_id()) != 1 or not player.is_local:
		return
	if index < 0 or index >= def.dice_faces.size():
		return
	_face = def.dice_faces[index]
	_face_left = _face.duration if _face.duration > 0.0 else SHOW_INSTANT
	match _face.kind:
		DiceFaceDef.Kind.HOT_HAND:
			player.status.start_buff_local(_face.duration, 1.0, _face.fire_rate_mult)
			player.status.start_free_ammo_local(_face.duration)
		DiceFaceDef.Kind.LUCKY:
			player.status.start_buff_local(_face.duration, _face.speed_mult, 1.0)
	Sfx.play_ui(player, Sfx.DICE_GOOD if _face.mood >= DiceFaceDef.Mood.NEUTRAL else Sfx.DICE_BAD)
