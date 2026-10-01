class_name Loadout
extends RefCounted
## A loadout is PackedInt32Array [class_index, primary_index, ability_index] into the roster.
## Small enough to replicate and send in RPCs; validated by the host.

# Loaded on first use, not preloaded: the roster pulls in every weapon and ability scene, and
# those scripts reach classes (Game, LoadoutMenu) that read the roster, a compile-time cycle.
const ROSTER_PATH: String = "res://data/classes/roster.tres"
const CLASS: int = 0
const PRIMARY: int = 1
const ABILITY: int = 2

static var _roster: ClassRoster


static func roster() -> ClassRoster:
	if _roster == null:
		_roster = load(ROSTER_PATH)
	return _roster


static func get_class_def(code: PackedInt32Array) -> ClassDef:
	return roster().classes[code[CLASS]]


static func get_primary(code: PackedInt32Array) -> WeaponDef:
	return get_class_def(code).primary_weapons[code[PRIMARY]]


## Null when the class has no abilities.
static func get_ability(code: PackedInt32Array) -> AbilityDef:
	var abilities: Array[AbilityDef] = get_class_def(code).abilities
	return abilities[code[ABILITY]] if not abilities.is_empty() else null


static func is_valid(code: PackedInt32Array) -> bool:
	if code.size() != 3 or code[CLASS] < 0 or code[CLASS] >= roster().classes.size():
		return false
	var class_def: ClassDef = roster().classes[code[CLASS]]
	if code[PRIMARY] < 0 or code[PRIMARY] >= class_def.primary_weapons.size():
		return false
	return code[ABILITY] == 0 if class_def.abilities.is_empty() else (code[ABILITY] >= 0 and code[ABILITY] < class_def.abilities.size())


static func make(class_index: int, primary_index: int, ability_index: int) -> PackedInt32Array:
	return PackedInt32Array([class_index, primary_index, ability_index])


static func default_code() -> PackedInt32Array:
	return make(0, 0, 0)


## The saved choice from Settings, clamped to what the roster offers.
static func from_settings() -> PackedInt32Array:
	var class_index: int = 0
	for i: int in roster().classes.size():
		if roster().classes[i].id == Settings.loadout_class:
			class_index = i
	var code: PackedInt32Array = make(class_index, Settings.loadout_primary, Settings.loadout_ability)
	return code if is_valid(code) else make(class_index, 0, 0)


static func save_to_settings(code: PackedInt32Array) -> void:
	Settings.loadout_class = get_class_def(code).id
	Settings.loadout_primary = code[PRIMARY]
	Settings.loadout_ability = code[ABILITY]
	Settings.save_settings()


static func describe(code: PackedInt32Array) -> String:
	var ability: AbilityDef = get_ability(code)
	var text: String = "%s · %s" % [get_class_def(code).display_name, get_primary(code).display_name]
	return text + (" · %s" % ability.display_name if ability != null else "")
