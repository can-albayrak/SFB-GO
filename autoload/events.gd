extends Node
## Global signal bus. Systems communicate through here instead of calling each other directly.

@warning_ignore("unused_signal")
signal local_player_spawned(player: Player)

## A shot from the local player landed (confirmed by the host). Drives the hit marker.
## `amount` is the damage dealt (0 for hits without damage, e.g. a Charge stun).
@warning_ignore("unused_signal")
signal hit_confirmed(zone: Hitbox.Zone, killed: bool, amount: float)

## Fired on every peer when the host announces a death. killer_id == victim id for self-kills.
@warning_ignore("unused_signal")
signal player_died(victim: Player, killer_id: int, weapon_name: String, killer_health: int)

## Every peer, after Match has applied the kill to the scores. Drives the kill feed.
@warning_ignore("unused_signal")
signal kill_registered(killer_id: int, victim_id: int, weapon_name: String, headshot: bool)

@warning_ignore("unused_signal")
signal scores_changed

## Every peer. A new match (also the first one after a restart) has begun.
@warning_ignore("unused_signal")
signal match_started

## Every peer. awards: Array of [title: String, peer_id: int, detail: String].
@warning_ignore("unused_signal")
signal match_ended(winner_id: int, awards: Array)

## Local player hit by a flashbang: white-out for `seconds`.
@warning_ignore("unused_signal")
signal local_flashed(seconds: float)

## Local player hurt by another player standing at `source` (hit direction indicator).
@warning_ignore("unused_signal")
signal local_hurt_from(source: Vector3)

## Every peer: a crate is coming down at `point` (announcement).
@warning_ignore("unused_signal")
signal airdrop_incoming(point: Vector3)

## Every peer: `peer_id` opened a crate and got `weapon_name`.
@warning_ignore("unused_signal")
signal airdrop_opened(peer_id: int, weapon_name: String)

## Local player: a short line under the crosshair (e.g. how many the Sonar found).
@warning_ignore("unused_signal")
signal local_notice(text: String)

## Local player stunned (Bear's Charge) for `seconds`.
@warning_ignore("unused_signal")
signal local_stunned(seconds: float)
