class_name AbilityDef
extends Resource
## Balance data for one ability (Q). Values live in data/abilities/*.tres.

@export var id: StringName
@export var display_name: String
@export var cooldown: float = 15.0
@export var duration: float = 0.0
@export var scene: PackedScene
