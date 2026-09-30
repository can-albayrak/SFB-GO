class_name Crosshair
extends Control
## Crosshair drawn from Settings, plus the hit marker (white = hit, red = kill).

const HIT_MARKER_TIME: float = 0.2
const HIT_MARKER_INNER: float = 6.0
const HIT_MARKER_OUTER: float = 13.0
const HIT_MARKER_WIDTH: float = 2.0
const HIT_COLOR: Color = Color(1.0, 1.0, 1.0)
const KILL_COLOR: Color = Color(1.0, 0.2, 0.15)

var _hit_left: float = 0.0
var _hit_color: Color = HIT_COLOR


func show_hit(_zone: Hitbox.Zone, killed: bool) -> void:
	_hit_left = HIT_MARKER_TIME
	_hit_color = KILL_COLOR if killed else HIT_COLOR
	queue_redraw()


func _process(delta: float) -> void:
	if _hit_left > 0.0:
		_hit_left = maxf(_hit_left - delta, 0.0)
		queue_redraw()


func _draw() -> void:
	var c: Vector2 = (size * 0.5).floor()
	var color: Color = Settings.crosshair_color
	var gap: float = Settings.crosshair_gap
	var length: float = Settings.crosshair_length
	var t: float = Settings.crosshair_thickness
	var half_t: float = t * 0.5

	draw_rect(Rect2(c.x - half_t, c.y - gap - length, t, length), color)
	draw_rect(Rect2(c.x - half_t, c.y + gap, t, length), color)
	draw_rect(Rect2(c.x - gap - length, c.y - half_t, length, t), color)
	draw_rect(Rect2(c.x + gap, c.y - half_t, length, t), color)
	if Settings.crosshair_dot:
		draw_rect(Rect2(c.x - half_t, c.y - half_t, t, t), color)

	if _hit_left <= 0.0:
		return
	var marker_color: Color = _hit_color
	marker_color.a = _hit_left / HIT_MARKER_TIME
	for dir: Vector2 in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
		var n: Vector2 = dir.normalized()
		draw_line(c + n * HIT_MARKER_INNER, c + n * HIT_MARKER_OUTER, marker_color, HIT_MARKER_WIDTH, true)
