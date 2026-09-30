extends Node
## Global signal bus. Systems communicate through here instead of calling each other directly.

@warning_ignore("unused_signal")
signal local_player_spawned(player: Player)

## A shot from the local player landed. Drives the hit marker.
@warning_ignore("unused_signal")
signal hit_confirmed(zone: Hitbox.Zone, killed: bool)
