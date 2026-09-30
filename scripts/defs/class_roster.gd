class_name ClassRoster
extends Resource
## Ordered list of playable classes (data/classes/roster.tres). Loadouts store indices into it,
## so every peer must run the same roster.

@export var classes: Array[ClassDef]
