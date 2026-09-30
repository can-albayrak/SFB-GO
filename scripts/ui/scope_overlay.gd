class_name ScopeOverlay
extends Control
## Sniper scope: black mask with a circular view and a thin reticle. Drawn only while `active`.

const VIEW_RADIUS_SHARE: float = 0.42 ## Of the shorter screen side.
const MASK_COLOR: Color = Color(0.0, 0.0, 0.0, 1.0)
const RETICLE_COLOR: Color = Color(0.0, 0.0, 0.0, 0.85)
const RETICLE_DOT_COLOR: Color = Color(1.0, 0.15, 0.1, 0.9)

var active: bool = false: set = _set_active


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false


func _set_active(value: bool) -> void:
	if active == value:
		return
	active = value
	visible = value
	queue_redraw()


func _draw() -> void:
	if not active:
		return
	var center: Vector2 = size * 0.5
	var radius: float = minf(size.x, size.y) * VIEW_RADIUS_SHARE
	var mask_width: float = size.length()
	# A very wide arc starting at the view radius covers everything outside the circle.
	draw_arc(center, radius + mask_width * 0.5, 0.0, TAU, 160, MASK_COLOR, mask_width)
	draw_arc(center, radius, 0.0, TAU, 128, MASK_COLOR, 3.0, true)
	draw_line(center - Vector2(radius, 0.0), center + Vector2(radius, 0.0), RETICLE_COLOR, 1.0)
	draw_line(center - Vector2(0.0, radius), center + Vector2(0.0, radius), RETICLE_COLOR, 1.0)
	draw_circle(center, 2.0, RETICLE_DOT_COLOR)
