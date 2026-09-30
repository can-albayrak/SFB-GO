extends Node
## Match rules and state: score, kill target, timer, pickup/airdrop timers.
## Only the host mutates state here; clients receive it via RPC.
## Stage 2 only uses the respawn delay; FFA rules arrive in stage 3.

const DEFAULT_RULES: MatchDef = preload("res://data/match/default.tres")

var rules: MatchDef = DEFAULT_RULES
