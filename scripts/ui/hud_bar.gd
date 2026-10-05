class_name HudBar
extends Control
## PS2-era HUD bar (GDD "Görsel referans"): a bevelled frame (light top-left, dark
## bottom-right), a dark well and a three-tone gradient fill. `value` is 0..1.

const FRAME_LIGHT: Color = Color("7f8a9a")
const FRAME_DARK: Color = Color("2a303a")
const WELL: Color = Color("10131a")
const FRAME: float = 2.0
const PADDING: float = 2.0

@export var fill_top: Color = Color("b8dcb0")
@export var fill_mid: Color = Color("6f9f68")
@export var fill_bottom: Color = Color("4a7546")

var value: float = 1.0:
	set(v):
		v = clampf(v, 0.0, 1.0)
		if not is_equal_approx(v, value):
			value = v
			queue_redraw()


## Diagonal stripes over the fill: a different kind of timer (Phantom's recall window).
var striped: bool = false:
	set(v):
		if v != striped:
			striped = v
			queue_redraw()

const STRIPE_COLOR: Color = Color(0.0, 0.0, 0.0, 0.35)
const STRIPE_STEP: float = 8.0


func set_colors(top: Color, mid: Color, bottom: Color) -> void:
	fill_top = top
	fill_mid = mid
	fill_bottom = bottom
	queue_redraw()


func _draw() -> void:
	var w: float = size.x
	var h: float = size.y
	draw_rect(Rect2(0.0, 0.0, w, h), WELL)
	draw_rect(Rect2(0.0, 0.0, w, FRAME), FRAME_LIGHT)
	draw_rect(Rect2(0.0, 0.0, FRAME, h), FRAME_LIGHT)
	draw_rect(Rect2(0.0, h - FRAME, w, FRAME), FRAME_DARK)
	draw_rect(Rect2(w - FRAME, 0.0, FRAME, h), FRAME_DARK)
	var inner := Rect2(FRAME + PADDING, FRAME + PADDING, w - 2.0 * (FRAME + PADDING), h - 2.0 * (FRAME + PADDING))
	if inner.size.x <= 0.0 or inner.size.y <= 0.0 or value <= 0.0:
		return
	var fill_width: float = inner.size.x * value
	# Three horizontal bands approximate the vertical gradient of the mock-up.
	var bands: Array[Color] = [fill_top, fill_mid, fill_bottom]
	var band_h: float = inner.size.y / 3.0
	for i: int in 3:
		var top: float = inner.position.y + band_h * i
		var colors := PackedColorArray([bands[i], bands[i], bands[mini(i + 1, 2)], bands[mini(i + 1, 2)]])
		var points := PackedVector2Array([
			Vector2(inner.position.x, top), Vector2(inner.position.x + fill_width, top),
			Vector2(inner.position.x + fill_width, top + band_h), Vector2(inner.position.x, top + band_h)])
		draw_polygon(points, colors)
	if striped:
		_draw_stripes(Rect2(inner.position, Vector2(fill_width, inner.size.y)))


func _draw_stripes(area: Rect2) -> void:
	var x: float = area.position.x - area.size.y
	while x < area.end.x:
		var a := Vector2(maxf(x, area.position.x), area.end.y - maxf(area.position.x - x, 0.0))
		var top_x: float = x + area.size.y
		var b := Vector2(minf(top_x, area.end.x), area.position.y + maxf(top_x - area.end.x, 0.0))
		if b.x > a.x:
			draw_line(a, b, STRIPE_COLOR, STRIPE_STEP * 0.4)
		x += STRIPE_STEP
