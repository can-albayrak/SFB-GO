class_name DiceFaceDef
extends Resource
## One face of the Gambler's die (AbilityDef.dice_faces, data/abilities/dice.tres).
## The host rolls; every face is equally likely.

enum Kind {
	DAMAGE, ## Damage dealt x damage_mult for duration (host).
	HOT_HAND, ## Magazines do not empty and fire rate x fire_rate_mult for duration.
	LUCKY, ## Health to full, run speed x speed_mult for duration.
	REVEAL, ## Gambler sees everyone through walls, and everyone sees the Gambler, for duration.
	HEALTH, ## Health drops to set_health at once (never raised).
}
enum Mood { VERY_BAD = -2, BAD = -1, NEUTRAL = 0, GOOD = 1 }

@export var title: String
@export var kind: Kind
@export var mood: Mood = Mood.NEUTRAL
@export var duration: float = 6.0
@export var damage_mult: float = 1.0
@export var fire_rate_mult: float = 1.0
@export var speed_mult: float = 1.0
@export var set_health: int = 0
