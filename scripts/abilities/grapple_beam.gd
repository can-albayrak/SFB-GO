class_name GrappleBeam
extends MeshInstance3D
## Cosmetic rope between a player's body and the anchor. Frees itself after its lifetime.

const RADIUS: float = 0.02
const COLOR: Color = Color(0.75, 0.9, 1.0)
const HAND_HEIGHT: float = 1.2

var _player: Player
var _anchor: Vector3
var _left: float


static func create(player: Player, anchor: Vector3, lifetime: float) -> GrappleBeam:
	var beam := GrappleBeam.new()
	beam._player = player
	beam._anchor = anchor
	beam._left = lifetime
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = RADIUS
	cylinder.bottom_radius = RADIUS
	cylinder.height = 1.0
	cylinder.radial_segments = 6
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = COLOR
	cylinder.material = material
	beam.mesh = cylinder
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return beam


func _process(delta: float) -> void:
	_left -= delta
	if _left <= 0.0 or not is_instance_valid(_player):
		queue_free()
		return
	var from: Vector3 = _player.global_position + Vector3.UP * HAND_HEIGHT
	var length: float = from.distance_to(_anchor)
	if length < 0.05:
		return
	# Cylinder axis is local Y: stretch it to the rope length and orient it along the rope.
	var up: Vector3 = (_anchor - from) / length
	var helper: Vector3 = Vector3.RIGHT if absf(up.x) < 0.9 else Vector3.FORWARD
	var side: Vector3 = up.cross(helper).normalized()
	var axes := Basis(side, up, side.cross(up))
	global_transform = Transform3D(axes * Basis.from_scale(Vector3(1.0, length, 1.0)), (from + _anchor) * 0.5)
