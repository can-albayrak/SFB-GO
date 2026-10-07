class_name Crosshair
extends Control
## Crosshair drawn from Settings, plus the hit marker: a classic X shown when a hit lands
## (at once for hitscan shots, see HitFeedback). Body / leg hits are white, headshots red,
## a kill a bigger, longer red X. Every marker pops: it starts larger and settles (GDD "Vuruş hissi").

const HIT_MARKER_TIME: float = 0.2
const KILL_MARKER_TIME: float = 0.4
const KILL_MARKER_SCALE: float = 1.7
const KILL_MARKER_WIDTH: float = 3.0
const POP_SCALE: float = 1.5 ## Marker size right when it appears; settles to 1 over POP_TIME.
const POP_TIME: float = 0.08
const HIT_MARKER_INNER: float = 6.0
const HIT_MARKER_OUTER: float = 13.0
const HIT_MARKER_WIDTH: float = 2.0
const HIT_COLOR: Color = Color(1.0, 1.0, 1.0)
const HEAD_COLOR: Color = Color(1.0, 0.2, 0.15)
const KILL_COLOR: Color = Color(1.0, 0.1, 0.05)

var _hit_left: float = 0.0
var _hit_total: float = HIT_MARKER_TIME
var _hit_killed: bool = false
var _hit_color: Color = HIT_COLOR


func _ready() -> void:
	Settings.changed.connect(queue_redraw)


func show_hit(zone: Hitbox.Zone, killed: bool, _amount: float) -> void:
	if not Settings.hit_marker_enabled:
		return
	_hit_killed = killed
	_hit_total = KILL_MARKER_TIME if killed else HIT_MARKER_TIME
	_hit_left = _hit_total
	if killed:
		_hit_color = KILL_COLOR
	else:
		_hit_color = HEAD_COLOR if zone == Hitbox.Zone.HEAD else HIT_COLOR
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
	marker_color.a = _hit_left / _hit_total
	var pop: float = lerpf(POP_SCALE, 1.0, clampf((_hit_total - _hit_left) / POP_TIME, 0.0, 1.0))
	var marker_scale: float = pop * (KILL_MARKER_SCALE if _hit_killed else 1.0)
	var width: float = KILL_MARKER_WIDTH if _hit_killed else HIT_MARKER_WIDTH
	for dir: Vector2 in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
		var n: Vector2 = dir.normalized()
		draw_line(c + n * HIT_MARKER_INNER * marker_scale, c + n * HIT_MARKER_OUTER * marker_scale, marker_color, width, true)
