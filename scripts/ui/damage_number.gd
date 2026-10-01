class_name DamageNumber
extends RefCounted
## Floating damage number at a hit point. Shown only on the shooter's screen, after the
## host confirmed the hit (Player.confirm_hit). Cosmetic only.

const RISE: float = 0.7
const LIFETIME: float = 0.9
const FONT_SIZE: int = 56
const OUTLINE_SIZE: int = 12
const PIXEL_SIZE: float = 0.004
const JITTER: float = 0.2 ## Random sideways offset so quick hits do not stack.
const LIFT: float = 0.25 ## Starts this far above the hit point.
const HEAD_COLOR: Color = Color(1.0, 0.25, 0.2)
const BODY_COLOR: Color = Color(1.0, 1.0, 1.0)
const LEG_COLOR: Color = Color(0.7, 0.7, 0.7)


## `parent` must sit at the world origin (Players root).
static func spawn(parent: Node3D, point: Vector3, amount: float, zone: Hitbox.Zone) -> void:
	if amount <= 0.0:
		return
	var label := Label3D.new()
	label.text = str(roundi(amount))
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.font_size = FONT_SIZE
	label.outline_size = OUTLINE_SIZE
	label.pixel_size = PIXEL_SIZE
	label.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	match zone:
		Hitbox.Zone.HEAD:
			label.modulate = HEAD_COLOR
		Hitbox.Zone.LEG:
			label.modulate = LEG_COLOR
		_:
			label.modulate = BODY_COLOR
	label.position = point + Vector3(randf_range(-JITTER, JITTER), LIFT, 0.0) # Before add_child.
	parent.add_child(label)

	var tween := label.create_tween().set_parallel()
	tween.tween_property(label, "position:y", label.position.y + RISE, LIFETIME)
	tween.tween_property(label, "modulate:a", 0.0, LIFETIME).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(label.queue_free)
