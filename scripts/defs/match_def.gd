class_name MatchDef
extends Resource
## Match rules. Defaults live in data/match/default.tres; the host overrides
## kill target and time limit in the main menu before hosting.

@export var kill_target: int = 30 ## First to this many kills wins. 0 = no kill limit.
@export var time_limit: float = 900.0 ## Seconds. 0 = no time limit.
@export var respawn_delay: float = 3.0 ## Seconds between death and respawn.
@export var spawn_protection: float = 2.0 ## Seconds of no damage after spawning; firing ends it.
@export var end_screen_time: float = 10.0 ## Seconds the results stay up before the next match.
@export var loadout_swap_window: float = 3.0 ## A loadout picked this soon after spawning applies at once.
