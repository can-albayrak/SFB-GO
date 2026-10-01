class_name HudWeaponIcon
extends Control
## Placeholder weapon silhouette for the HUD (GDD: replaced by icons rendered from the
## weapon models once they exist). Light fill with a black outline, PS2 style.

enum Shape { RIFLE, PISTOL, BLADE }

const FILL: Color = Color("dfe4ea")
const OUTLINE: Color = Color(0.0, 0.0, 0.0, 1.0)
const OUTLINE_WIDTH: float = 1.5
## Outlines in their own units (from the HUD mock-up); scaled to fit the control.
const RIFLE_POINTS: PackedVector2Array = [
	Vector2(2, 14), Vector2(96, 14), Vector2(104, 10), Vector2(130, 10), Vector2(130, 16),
	Vector2(148, 16), Vector2(148, 22), Vector2(130, 22), Vector2(130, 26), Vector2(104, 26),
	Vector2(100, 34), Vector2(88, 34), Vector2(84, 26), Vector2(62, 26), Vector2(56, 40),
	Vector2(42, 40), Vector2(46, 26), Vector2(20, 26), Vector2(12, 30), Vector2(2, 30)]
const RIFLE_SIZE: Vector2 = Vector2(150, 44)
const PISTOL_POINTS: PackedVector2Array = [
	Vector2(4, 8), Vector2(70, 8), Vector2(70, 18), Vector2(40, 18), Vector2(36, 34),
	Vector2(22, 34), Vector2(26, 18), Vector2(4, 18)]
const PISTOL_SIZE: Vector2 = Vector2(74, 38)
const BLADE_POINTS: PackedVector2Array = [
	Vector2(4, 16), Vector2(22, 12), Vector2(26, 12), Vector2(26, 9), Vector2(30, 9),
	Vector2(30, 13), Vector2(66, 13), Vector2(76, 18), Vector2(30, 21), Vector2(30, 25),
	Vector2(26, 25), Vector2(26, 21), Vector2(22, 21), Vector2(4, 21)]
const BLADE_SIZE: Vector2 = Vector2(80, 34)

var shape: Shape = Shape.RIFLE:
	set(v):
		shape = v
		queue_redraw()


## A silhouette that fits the weapon (until real icons exist).
static func shape_for(def: WeaponDef, slot: int) -> Shape:
	if def.fire_type == WeaponDef.FireType.MELEE or def.fire_type == WeaponDef.FireType.THROWN:
		return Shape.BLADE
	return Shape.PISTOL if slot == 1 or def.dual_wield else Shape.RIFLE


func _draw() -> void:
	var points: PackedVector2Array = RIFLE_POINTS
	var source: Vector2 = RIFLE_SIZE
	match shape:
		Shape.PISTOL:
			points = PISTOL_POINTS
			source = PISTOL_SIZE
		Shape.BLADE:
			points = BLADE_POINTS
			source = BLADE_SIZE
	var scale_factor: float = minf(size.x / source.x, size.y / source.y)
	var offset: Vector2 = Vector2(size.x - source.x * scale_factor, (size.y - source.y * scale_factor) * 0.5)
	var placed := PackedVector2Array()
	for point: Vector2 in points:
		placed.append(offset + point * scale_factor)
	draw_colored_polygon(placed, FILL)
	var closed := placed.duplicate()
	closed.append(placed[0])
	draw_polyline(closed, OUTLINE, OUTLINE_WIDTH)
