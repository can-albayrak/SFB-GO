class_name HitFeedback
extends RefCounted
## Shooter-side hit marker logic. A hitscan shot whose own trace touches a living, damageable
## player shows its marker and tick at once (predict) instead of a round trip later; the
## host's confirmation (Player.confirm_hit) then only upgrades it (headshot, kill) and adds
## the damage number. Other weapons get no prediction and show on confirmation as before.
## Local to this process: one local player per game instance.

const PREDICTION_TTL: float = 0.8 ## A prediction the host never confirmed (shield, spawn protection) expires.

## [expiry, zone] of markers already shown, oldest first.
static var _pending: Array[Vector2] = []


## The local trace touched a player in `zone`.
static func predict(zone: Hitbox.Zone) -> void:
	_pending.append(Vector2(_now() + PREDICTION_TTL, float(zone)))
	Events.hit_confirmed.emit(zone, false, 0.0)


## The host confirmed a hit by `shooter` (the local player). Shows the marker unless a
## prediction of the same plain hit already did, and punches the view on headshots and kills.
static func on_confirmed(shooter: Player, zone: Hitbox.Zone, killed: bool, amount: float) -> void:
	var shown_early: bool = _take_prediction(zone)
	if killed:
		shooter.punch_view(CameraFeel.DEF.kill_kick)
	elif zone == Hitbox.Zone.HEAD:
		shooter.punch_view(CameraFeel.DEF.hit_head_kick)
	if shown_early and not killed:
		return
	Events.hit_confirmed.emit(zone, killed, amount)


## Pops the oldest live prediction; true when it was for `zone`.
static func _take_prediction(zone: Hitbox.Zone) -> bool:
	var now: float = _now()
	while not _pending.is_empty() and _pending[0].x < now:
		_pending.pop_front()
	if _pending.is_empty():
		return false
	var entry: Vector2 = _pending.pop_front()
	return int(entry.y) == int(zone)


static func _now() -> float:
	return Time.get_ticks_msec() / 1000.0
