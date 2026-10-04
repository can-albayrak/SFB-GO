class_name CharacterModelDef
extends Resource
## A static (unrigged) character model put on the Mixamo skeleton by CharacterSkin.
## Values live in data/characters/*.tres.

@export var scene: PackedScene ## Any glTF/FBX; every mesh in it is used.
@export var height: float = 1.82 ## Scaled to this many metres from the feet to the top of the head.
@export var yaw_degrees: float = 0.0 ## Turn that makes the model face +Z (the skeleton's front).
## Where the model's limbs really are, so the skeleton is bent to match before skinning.
## Bone short name (left side; the right side is mirrored) -> the point in metres, in the
## scaled and turned model, that the bone's child joint should reach. E.g. "LeftArm" -> the
## elbow, "LeftForeArm" -> the wrist, "LeftUpLeg" -> the knee.
@export var fit_points: Dictionary[String, Vector3] = {}
