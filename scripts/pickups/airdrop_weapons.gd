class_name AirdropWeapons
extends RefCounted
## The airdrop weapon pool. Loaded on first use, not preloaded: weapon scenes reach Player
## and Game, which read this list (same compile-time cycle as Loadout.roster()).

const ROSTER_PATH: String = "res://data/weapons/airdrop_roster.tres"

static var _roster: WeaponRoster


static func roster() -> WeaponRoster:
	if _roster == null:
		_roster = load(ROSTER_PATH)
	return _roster


static func get_def(index: int) -> WeaponDef:
	var weapons: Array[WeaponDef] = roster().weapons
	return weapons[index] if index >= 0 and index < weapons.size() else null


static func count() -> int:
	return roster().weapons.size()
