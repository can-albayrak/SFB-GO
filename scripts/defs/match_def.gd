class_name MatchDef
extends Resource
## Match rules. Defaults live in data/match/default.tres; the host overrides
## kill target and time limit in the lobby. The offline Test Range uses data/match/test_range.tres.

@export var kill_target: int = 30 ## First to this many kills wins. 0 = no kill limit.
@export var time_limit: float = 900.0 ## Seconds. 0 = no time limit.
@export var respawn_delay: float = 3.0 ## Seconds between death and respawn.
@export var spawn_protection: float = 2.0 ## Seconds of no damage after spawning; firing ends it.
@export var end_screen_time: float = 10.0 ## Seconds the results stay up before the next match.
@export var loadout_swap_window: float = 3.0 ## A loadout picked this soon after spawning applies at once.
@export var kill_heal: int = 20 ## Health back for every kill (never above the class maximum).
@export var kill_ammo: int = 15 ## Rounds added to the weapon in hand for every kill (not above the magazine).
@export var infinite_ammo: bool = false ## Magazines never empty (Test Range).
@export var ability_cooldowns: bool = true ## False: abilities are always ready (Test Range).
