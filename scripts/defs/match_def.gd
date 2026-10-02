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
@export_group("Airdrop")
@export var airdrop_first_delay: float = 180.0 ## Seconds into the match before the first crate.
@export var airdrop_interval_min: float = 120.0 ## Then a random gap in [min, max]. 0 = no airdrops.
@export var airdrop_interval_max: float = 180.0
@export var airdrop_fall_time: float = 12.0 ## Seconds the crate floats down under its parachute.
@export var airdrop_open_time: float = 3.0 ## Seconds of holding E to open a crate.
@export var airdrop_max_active: int = 0 ## > 0: no new crate while crates + dropped + carried reach this.
@export var weapon_drop_lifetime: float = 45.0 ## Seconds a dead carrier's weapon stays on the ground.

@export_group("Practice")
@export var infinite_ammo: bool = false ## Magazines never empty (Test Range).
@export var ability_cooldowns: bool = true ## False: abilities are always ready (Test Range toggle, Settings.practice_unlimited_abilities).
@export var loadout_swap_anytime: bool = false ## True: a loadout pick applies at once at any time, not only right after spawning (Test Range).
