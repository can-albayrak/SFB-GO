class_name Decoy
extends Node3D
## Cosmetic hologram copy of a player's body (Hawk Decoy). No hitbox: shots pass through.

const COLOR: Color = Color(0.3, 0.85, 1.0, 0.45)
const BLINK_TIME: float = 1.5 ## Flickers for this long before vanishing.
const BLINK_PERIOD: float = 0.15

var _left: float = 0.0


## `source` is the player's Model node; its look is copied, frozen at this pose.
static func create(source: Node3D, at: Vector3, yaw: float, seconds: float) -> Decoy:
	var decoy := Decoy.new()
	decoy._left = seconds
	var body: Node3D = source.duplicate()
	body.visible = true
	for extra: String in ["Crown", "Glint"]: # Leader crown and scope glint stay on the player.
		var node: Node = body.get_node_or_null(extra)
		if node != null:
			body.remove_child(node)
			node.queue_free()
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = COLOR
	_apply_material(body, material)
	decoy.add_child(body)
	decoy.position = at
	decoy.rotation.y = yaw
	return decoy


static func _apply_material(node: Node, material: Material) -> void:
	if node is GeometryInstance3D:
		(node as GeometryInstance3D).material_override = material
		(node as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for child: Node in node.get_children():
		_apply_material(child, material)


func _process(delta: float) -> void:
	_left -= delta
	if _left <= 0.0:
		queue_free()
		return
	if _left < BLINK_TIME:
		visible = fmod(_left, BLINK_PERIOD * 2.0) < BLINK_PERIOD
