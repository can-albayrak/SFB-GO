class_name ClassDef
extends Resource
## Balance data for one class. Values live in data/classes/*.tres.

@export var id: StringName
@export var display_name: String
@export var max_health: int = 100
@export var move_speed: float = 6.0 ## Metres per second at full run.
@export var movement: MovementDef
@export var primary_weapons: Array[WeaponDef]
@export var secondary_weapon: WeaponDef
@export var abilities: Array[AbilityDef]
@export var quick_melee: WeaponDef ## V: swung over the weapon in hand (knife or Bear's kick).
## Ghost: footsteps make no sound (for anyone, the owner included).
@export var silent_steps: bool = false
@export var knife: WeaponDef ## Weapon slot 3 (CS style): held and swung like a gun; backstabs kill.
