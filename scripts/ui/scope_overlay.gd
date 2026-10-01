class_name ScopeOverlay
extends Control
## Sniper scope: black mask around a circular lens with a duplex reticle
## (thick outer posts, thin centre, range ticks). Drawn only while `active`.
## `motion` (0..1, set by the HUD from the player's speed) blurs the view behind it.

const VIEW_RADIUS_SHARE: float = 0.46 ## Of the shorter screen side.
const RING_SEGMENTS: int = 96
const MASK_COLOR: Color = Color(0.0, 0.0, 0.0, 1.0)
const RIM_COLOR: Color = Color(0.0, 0.0, 0.0, 0.9)
const VIGNETTE_COLOR: Color = Color(0.0, 0.0, 0.0, 0.35)
const RETICLE_COLOR: Color = Color(0.0, 0.0, 0.0, 0.95)
const THICK_WIDTH: float = 5.0
const THIN_WIDTH: float = 1.5
const THIN_LENGTH_SHARE: float = 0.22 ## Thin centre lines, of the lens radius.
const TICK_COUNT: int = 4
const TICK_SPACING_SHARE: float = 0.055
const TICK_HALF_LENGTH: float = 7.0
const CENTER_DOT_COLOR: Color = Color(1.0, 0.1, 0.05, 0.9)
const BLUR_SHADER: Shader = preload("res://assets/shaders/scope_blur.gdshader")
const BLUR_START_SPEED: float = 0.6 ## m/s: slower than this keeps the view sharp.
const BLUR_FULL_SPEED: float = 4.0 ## m/s: full blur from here.
const MAX_BLUR: float = 0.8

var active: bool = false: set = _set_active

var _blur: ColorRect
var _blur_material: ShaderMaterial


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT) # In the tree already: offsets must follow too.
	resized.connect(queue_redraw)
	_blur_material = ShaderMaterial.new()
	_blur_material.shader = BLUR_SHADER
	_blur = ColorRect.new()
	_blur.material = _blur_material
	_blur.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_blur.show_behind_parent = true # Under the mask and reticle.
	_blur.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_blur)
	visible = false


## Speed of the scoped player in m/s; blurs the scope view while moving.
func set_motion(speed: float) -> void:
	var share: float = clampf((speed - BLUR_START_SPEED) / (BLUR_FULL_SPEED - BLUR_START_SPEED), 0.0, 1.0)
	_blur_material.set_shader_parameter(&"amount", share * MAX_BLUR)
	_blur.visible = share > 0.0


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
	_draw_mask(center, radius)
	_draw_reticle(center, radius)


## Black everywhere outside the lens: one quad per ring segment, reaching past the screen corners.
func _draw_mask(center: Vector2, radius: float) -> void:
	var outer: float = size.length()
	var previous: Vector2 = Vector2.RIGHT
	for i: int in range(1, RING_SEGMENTS + 1):
		var current: Vector2 = Vector2.RIGHT.rotated(TAU * float(i) / RING_SEGMENTS)
		draw_colored_polygon(PackedVector2Array([
			center + previous * radius, center + current * radius,
			center + current * outer, center + previous * outer]), MASK_COLOR)
		previous = current
	draw_arc(center, radius, 0.0, TAU, RING_SEGMENTS, RIM_COLOR, 4.0, true)
	# Soft darkening toward the lens edge.
	draw_arc(center, radius * 0.96, 0.0, TAU, RING_SEGMENTS, VIGNETTE_COLOR, radius * 0.08, true)


func _draw_reticle(center: Vector2, radius: float) -> void:
	var thin: float = radius * THIN_LENGTH_SHARE
	# Thick outer posts (left, right, bottom, top) reaching the rim, thin lines near the centre.
	draw_line(center + Vector2(-radius, 0.0), center + Vector2(-thin, 0.0), RETICLE_COLOR, THICK_WIDTH)
	draw_line(center + Vector2(thin, 0.0), center + Vector2(radius, 0.0), RETICLE_COLOR, THICK_WIDTH)
	draw_line(center + Vector2(0.0, thin), center + Vector2(0.0, radius), RETICLE_COLOR, THICK_WIDTH)
	draw_line(center + Vector2(0.0, -radius), center + Vector2(0.0, -thin), RETICLE_COLOR, THICK_WIDTH)
	draw_line(center + Vector2(-thin, 0.0), center + Vector2(thin, 0.0), RETICLE_COLOR, THIN_WIDTH)
	draw_line(center + Vector2(0.0, -thin), center + Vector2(0.0, thin), RETICLE_COLOR, THIN_WIDTH)
	# Range ticks on the lower post (holdover marks).
	for i: int in range(1, TICK_COUNT + 1):
		var y: float = radius * TICK_SPACING_SHARE * i + thin
		draw_line(center + Vector2(-TICK_HALF_LENGTH, y), center + Vector2(TICK_HALF_LENGTH, y), RETICLE_COLOR, THIN_WIDTH + 0.5)
	draw_circle(center, 2.0, CENTER_DOT_COLOR)
