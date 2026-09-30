extends Node
## Match rules and state: score, kill target, timer, pickup/airdrop timers.
## Only the host mutates state here; clients receive it via RPC.
## Stage 2 only uses the respawn delay; FFA rules arrive in stage 3.

## Seconds between death and respawn (GDD: 3 s). Host-configurable later via the lobby.
var respawn_delay: float = 3.0
