class_name MapDef
extends Resource
## One playable map (data/maps/*.tres). The host picks it in the lobby; every peer loads
## `scene_path`. A map scene holds geometry, SpawnPoints, Pickups and AirdropPoints.

@export var id: StringName
@export var display_name: String
@export_file("*.tscn") var scene_path: String
## Shown next to the name in the lobby, e.g. "4-6".
@export var players_hint: String
## Bullet impact look on this map's walls (ImpactEffects.PROFILES: stone, snow, ice, metal).
## A collider with a "surface" meta overrides it.
@export var impact_surface: StringName = &"stone"
