extends Node
## Global signal bus. Systems communicate through here instead of calling each other directly.

@warning_ignore("unused_signal")
signal local_player_spawned(player: Player)

## A shot from the local player landed (confirmed by the host). Drives the hit marker.
@warning_ignore("unused_signal")
signal hit_confirmed(zone: Hitbox.Zone, killed: bool)

## Fired on every peer when the host announces a death. killer_id == victim id for self-kills.
@warning_ignore("unused_signal")
signal player_died(victim: Player, killer_id: int)
