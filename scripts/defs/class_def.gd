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
@export var quick_melee: WeaponDef
