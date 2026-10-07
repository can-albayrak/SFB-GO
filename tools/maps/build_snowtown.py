"""Builds Snow Town: a snowy village block in the spirit of CS 1.6's fy_snow, our PSX look.

    python tools/maps/build_snowtown.py [--preview DIR]

Writes scenes/maps/snow_town/snow_town.tscn (tools/maps/map_kit.py). Edit here and re-run.

Axes: x east, z south, y up; 64 x 44 m inside brick town walls (x -32..32, z -22..22). Point
symmetry (every west piece has an east twin turned 180 degrees about the centre), so no side
is better in free-for-all. Evening, light snow haze, warm windows.
- Ends: a spawn house against the town wall (x -32..-23): doors to the street, windows north
  and south, a fireplace. Its flat roof is a lookout with a parapet: a ramp on the north side
  and two crates on the south side lead up.
- North-west: a shop (x -20..-8, z -21..-11) with a counter and shelves, doors to the street
  and to the courtyard.
- South-west: an open-fronted barn (x -20..-9, z 10..21) with crate stacks.
- Middle north: a courtyard behind a knee-high wall with a parked truck.
- Centre: the square with a big decorated pine on a snow mound (cover all round).
- Street (z -4..4): cobbles, a parked car and crates; four street lamps.
"""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from map_kit import MapBuilder  # noqa: E402

ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "scenes", "maps", "snow_town", "snow_town.tscn")

HX, HZ = 32.0, 22.0  # Half size inside the town walls.
TOWN_WALL_H = 5.0
TOWN_WALL_T = 1.0
CLIP_H = 60.0
WALL_T = 0.4  # House walls.
HOUSE_H = 3.2
SHOP_H = 3.4
BARN_H = 4.0
DOOR_H = 2.4
WIN_LOW, WIN_HIGH = 1.0, 2.0
DECAL = 0.02
ROOF_PITCH = 35.0  # Degrees, backdrop gables.

m = MapBuilder(1.0)


def mirror(x, z):
    return -x, -z


def sbox(parent, name, x0, x1, y0, y1, z0, z1, mat, collide=True):
    """West piece and its east twin (180 degrees about the centre)."""
    m.box(parent, f"{name}W", x0, x1, y0, y1, z0, z1, mat, collide)
    m.box(parent, f"{name}E", -x1, -x0, y0, y1, -z1, -z0, mat, collide)


def scyl(parent, name, x, z, radius, y0, y1, mat, collide=True, sides=12, cone=False):
    m.cyl(parent, f"{name}W", x, z, radius, y0, y1, mat, collide, sides, cone)
    m.cyl(parent, f"{name}E", -x, -z, radius, y0, y1, mat, collide, sides, cone)


def slamp(parent, name, x, y, z, **kw):
    m.lamp(parent, f"{name}W", x, y, z, **kw)
    m.lamp(parent, f"{name}E", -x, y, -z, **kw)


def sramp_z(parent, name, z_low, z_high, x0, x1, y_low, y_high, mat):
    """Ramp rising along z (west copy) and its twin."""
    m.ramp(parent, f"{name}W", "z", z_low, z_high, x0, x1, y_low, y_high, mat)
    m.ramp(parent, f"{name}E", "z", -z_low, -z_high, -x1, -x0, y_low, y_high, mat)


def smarker(group, name_w, name_e, x, y, z, face, extra=None):
    m.marker(group, name_w, x, y, z, face, extra)
    m.marker(group, name_e, -x, y, -z, (-face[0], -face[1]), extra)


def wall(parent, name, axis, fixed0, fixed1, a0, a1, height, mat, openings=()):
    """A wall running along `axis` ("x" or "z") between a0..a1, thickness fixed0..fixed1 on the other
    axis, with openings [(b0, b1, y0, y1)] (doors from y0 = 0, windows higher). Twinned."""
    cuts = sorted({a0, a1, *[c for o in openings for c in o[:2]]})
    k = 0
    for lo, hi in zip(cuts, cuts[1:]):
        hole = next((o for o in openings if o[0] <= lo and hi <= o[1]), None)
        spans = [(0.0, height)] if hole is None else [(0.0, hole[2]), (hole[3], height)]
        for y0, y1 in spans:
            if y1 - y0 < 0.01:
                continue
            if axis == "x":
                sbox(parent, f"{name}{k}", lo, hi, y0, y1, fixed0, fixed1, mat)
            else:
                sbox(parent, f"{name}{k}", fixed0, fixed1, y0, y1, lo, hi, mat)
            k += 1


def build():
    g = "Geometry/Town"
    d = "Geometry/Detail"
    m.box(g, "Ground", -HX - 30, HX + 30, -1.0, 0.0, -HZ - 30, HZ + 30, "snow")

    # Town walls: brick, a dark cap, clips above.
    for i, (x0, x1, z0, z1) in enumerate([
            (-HX - TOWN_WALL_T, HX + TOWN_WALL_T, -HZ - TOWN_WALL_T, -HZ), (-HX - TOWN_WALL_T, HX + TOWN_WALL_T, HZ, HZ + TOWN_WALL_T),
            (-HX - TOWN_WALL_T, -HX, -HZ, HZ), (HX, HX + TOWN_WALL_T, -HZ, HZ)]):
        m.box(g, f"TownWall{i}", x0, x1, 0.0, TOWN_WALL_H, z0, z1, "brick")
        m.box(d, f"TownWallCap{i}", x0 - 0.1, x1 + 0.1, TOWN_WALL_H, TOWN_WALL_H + 0.2, z0 - 0.1, z1 + 0.1, "snow", False)
        m.clip(f"Clip{i}", x0, x1, TOWN_WALL_H, TOWN_WALL_H + CLIP_H, z0, z1)

    # Street and square: cobbles laid on the snow; pavements in trodden snow.
    m.box(d, "Street", -23.0, 23.0, 0.0, DECAL, -4.0, 4.0, "cobble", False)
    m.box(d, "Square", -8.0, 8.0, 0.0, DECAL, -8.0, 8.0, "cobble", False)
    sbox(d, "Pavement", -23.0, -8.0, 0.0, DECAL * 0.5, -10.5, -4.0, "snow_path", False)

    spawn_house(g, d)
    shop(g, d)
    barn(g, d)
    courtyard(g, d)
    square(g, d)
    street(g, d)

    # Spawns: 8 per side (house 3, shop 2, barn 1, yards 2), all looking into the town.
    smarker("SpawnPoints", "Spawn1", "Spawn9", -29.0, 0.1, -3.5, (0.0, 0.0))
    smarker("SpawnPoints", "Spawn2", "Spawn10", -29.0, 0.1, 3.5, (0.0, 0.0))
    smarker("SpawnPoints", "Spawn3", "Spawn11", -25.5, 0.1, 0.0, (0.0, 0.0))
    smarker("SpawnPoints", "Spawn4", "Spawn12", -16.5, 0.1, -17.5, (-14.0, 0.0))
    smarker("SpawnPoints", "Spawn5", "Spawn13", -11.0, 0.1, -16.0, (-14.0, 0.0))
    smarker("SpawnPoints", "Spawn6", "Spawn14", -14.5, 0.1, 13.5, (-14.0, 0.0))
    smarker("SpawnPoints", "Spawn7", "Spawn15", -25.0, 0.1, -17.0, (0.0, 0.0))
    smarker("SpawnPoints", "Spawn8", "Spawn16", -25.0, 0.1, 16.0, (0.0, 0.0))

    # Pickups: health on the street, speed in the courtyards, double jump on the house roofs.
    smarker("Pickups", "Pickup1", "Pickup2", -19.5, 0.0, 2.0, (0.0, 0.0), "health")
    smarker("Pickups", "Pickup3", "Pickup4", 0.0, 0.0, -12.8, (0.0, 0.0), "speed")
    smarker("Pickups", "Pickup5", "Pickup6", -27.5, HOUSE_H + 0.3, 0.0, (0.0, 0.0), "double_jump")

    # Airdrops: two corners of the square, two courtyards (open sky everywhere).
    smarker("AirdropPoints", "Drop1", "Drop2", -6.0, 0.0, 6.0, (0.0, 0.0))
    smarker("AirdropPoints", "Drop3", "Drop4", 5.0, 0.0, -14.5, (0.0, 0.0))

    backdrop()


def spawn_house(g, d):
    """West spawn house x -32..-23, z -7..7 (the town wall is its back wall)."""
    x0, x1, z0, z1 = -HX, -23.0, -7.0, 7.0
    roof = HOUSE_H + 0.3
    # Street side: two doors.
    wall(g, "HouseFront", "z", x1 - WALL_T, x1, z0, z1, HOUSE_H, "planks",
         [(-5.5, -3.5, 0.0, DOOR_H), (3.5, 5.5, 0.0, DOOR_H)])
    # North and south walls with a window each.
    wall(g, "HouseNorth", "x", z0, z0 + WALL_T, x0, x1, HOUSE_H, "planks", [(-28.5, -26.5, WIN_LOW, WIN_HIGH)])
    wall(g, "HouseSouth", "x", z1 - WALL_T, z1, x0, x1, HOUSE_H, "planks", [(-28.5, -26.5, WIN_LOW, WIN_HIGH)])
    sbox(g, "HouseRoof", x0, x1 + 0.3, HOUSE_H, roof, z0 - 0.3, z1 + 0.3, "roof")
    # Roof parapet with a gap where the ramp arrives (north-west corner) and one for the crates (south).
    sbox(g, "ParapetEast", x1 - 0.25, x1 + 0.3, roof, roof + 0.8, z0 - 0.3, z1 + 0.3, "planks")
    sbox(g, "ParapetNorth", -29.6, x1, roof, roof + 0.8, z0 - 0.3, z0, "planks")
    sbox(g, "ParapetSouth", x0, -29.6, roof, roof + 0.8, z1, z1 + 0.3, "planks")
    sbox(g, "ParapetSouthB", -27.6, x1, roof, roof + 0.8, z1, z1 + 0.3, "planks")
    # Way up 1: ramp along the town wall, from z -14 up to the roof's north edge.
    sramp_z(g, "HouseRamp", -14.5, z0 - 0.3, x0, x0 + 2.2, 0.0, roof, "crate")
    # Way up 2: crates against the south wall (1.2 m, then 2.4 m: two plain jumps), below the gap.
    sbox(g, "HouseStepHigh", -29.4, -27.8, 0.0, 2.4, z1, z1 + 1.6, "crate")
    sbox(g, "HouseStepLow", -29.4, -27.8, 0.0, 1.2, z1 + 1.6, z1 + 3.2, "crate")
    # Inside: plank floor and ceiling, fireplace, table, warm light.
    sbox(d, "HouseFloor", x0, x1 - WALL_T, 0.0, DECAL, z0 + WALL_T, z1 - WALL_T, "crate", False)
    sbox(d, "HouseCeiling", x0, x1 - WALL_T, HOUSE_H - DECAL, HOUSE_H, z0 + WALL_T, z1 - WALL_T, "planks", False)
    sbox(g, "Fireplace", x0, x0 + 0.6, 0.0, 1.4, -1.2, 1.2, "brick")
    sbox(d, "FireGlow", x0 + 0.6, x0 + 0.65, 0.2, 0.8, -0.6, 0.6, "window_lit", False)
    sbox(d, "Chimney", x0, x0 + 0.6, 1.4, HOUSE_H, -0.6, 0.6, "brick", False)
    sbox(g, "Table", -28.9, -28.1, 0.0, 0.8, -0.8, 0.8, "door")
    slamp(d, "HouseLight", -27.5, 2.6, 0.0, energy=1.3, reach=8.0)


def shop(g, d):
    """North-west shop x -20..-8, z -21..-11."""
    x0, x1, z0, z1 = -20.0, -8.0, -21.0, -11.0
    roof = SHOP_H + 0.3
    wall(g, "ShopFront", "x", z1 - WALL_T, z1, x0, x1, SHOP_H, "brick_painted",
         [(-19.0, -17.0, WIN_LOW, WIN_HIGH), (-15.0, -13.0, 0.0, DOOR_H), (-11.0, -9.0, WIN_LOW, WIN_HIGH)])
    wall(g, "ShopBack", "x", z0, z0 + WALL_T, x0, x1, SHOP_H, "brick_painted")
    wall(g, "ShopWest", "z", x0, x0 + WALL_T, z0, z1, SHOP_H, "brick_painted", [(-17.0, -15.0, WIN_LOW, WIN_HIGH)])
    wall(g, "ShopEast", "z", x1 - WALL_T, x1, z0, z1, SHOP_H, "brick_painted", [(-17.0, -15.0, 0.0, DOOR_H)])
    sbox(g, "ShopRoof", x0 - 0.3, x1 + 0.3, SHOP_H, roof, z0 - 0.3, z1 + 0.3, "roof")
    sbox(d, "ShopSign", -16.5, -11.5, 2.6, 3.2, z1, z1 + 0.15, "window_lit", False)
    sbox(d, "ShopAwning", -15.6, -12.4, 2.5, 2.6, z1, z1 + 1.2, "metal", False)
    sbox(d, "ShopFloor", x0 + WALL_T, x1 - WALL_T, 0.0, DECAL, z0 + WALL_T, z1 - WALL_T, "door", False)
    sbox(d, "ShopCeiling", x0 + WALL_T, x1 - WALL_T, SHOP_H - DECAL, SHOP_H, z0 + WALL_T, z1 - WALL_T, "planks", False)
    # Counter and shelves.
    sbox(g, "Counter", -19.6, -15.5, 0.0, 1.1, -14.6, -13.9, "door")
    sbox(g, "Shelves", -18.0, -10.0, 0.0, 2.0, z0 + WALL_T, z0 + 1.0, "crate")
    slamp(d, "ShopLight", -14.0, 2.9, -16.0, energy=1.2, reach=9.0)


def barn(g, d):
    """South-west barn x -20..-9, z 10..21, open towards the street."""
    x0, x1, z0, z1 = -20.0, -9.0, 10.0, 21.0
    wall(g, "BarnWest", "z", x0, x0 + WALL_T, z0, z1, BARN_H, "planks")
    wall(g, "BarnBack", "x", z1 - WALL_T, z1, x0, x1, BARN_H, "planks")
    wall(g, "BarnEast", "z", x1 - WALL_T, x1, 14.0, z1, BARN_H, "planks")
    for k, px in enumerate((x0 + 0.2, -14.5, x1 - 0.2)):
        sbox(g, f"BarnPost{k}_", px - 0.2, px + 0.2, 0.0, BARN_H, z0, z0 + 0.4, "crate")
    sbox(g, "BarnRoof", x0 - 0.4, x1 + 0.4, BARN_H, BARN_H + 0.2, z0 - 0.8, z1 + 0.4, "metal")
    sbox(d, "BarnRoofSnow", x0 - 0.4, x1 + 0.4, BARN_H + 0.2, BARN_H + 0.32, z0 - 0.8, z1 + 0.4, "snow", False)
    sbox(d, "BarnFloor", x0 + WALL_T, x1 - WALL_T, 0.0, DECAL, z0, z1 - WALL_T, "planks", False)
    # Crate stacks (1.2 m and 2.4 m) and hay (planks) bales.
    sbox(g, "BarnCrateLow", -18.2, -17.0, 0.0, 1.2, 17.6, 18.8, "crate")
    sbox(g, "BarnCrateHigh", -17.0, -15.6, 0.0, 2.4, 17.4, 18.8, "crate")
    sbox(g, "BarnBale", -12.4, -10.4, 0.0, 1.0, 16.5, 17.7, "planks")
    sbox(g, "BarnBaleTop", -12.0, -10.8, 1.0, 2.0, 16.6, 17.6, "planks")


def courtyard(g, d):
    """Middle north courtyard x -8..9, z -22..-10.5: a knee-high wall with a gap, a parked truck."""
    sbox(g, "CourtWallA", -8.0, -2.0, 0.0, 1.2, -10.8, -10.4, "concrete")
    sbox(g, "CourtWallB", 2.0, 9.0, 0.0, 1.2, -10.8, -10.4, "concrete")
    sbox(d, "CourtWallSnowA", -8.0, -2.0, 1.2, 1.3, -10.85, -10.35, "snow", False)
    sbox(d, "CourtWallSnowB", 2.0, 9.0, 1.2, 1.3, -10.85, -10.35, "snow", False)
    # Truck: cab, cargo box, wheels (looks only).
    sbox(g, "TruckCab", -6.2, -4.0, 0.4, 2.4, -20.6, -18.2, "container_blue")
    sbox(d, "TruckWindow", -4.05, -4.0, 1.5, 2.2, -20.3, -18.5, "window", False)
    sbox(g, "TruckCargo", -4.0, 2.6, 0.4, 2.9, -20.8, -18.0, "container_red")
    sbox(g, "TruckChassis", -6.2, 2.6, 0.0, 0.4, -20.4, -18.4, "trim")
    for k, wx in enumerate((-5.2, -0.5, 1.6)):
        sbox(d, f"TruckWheelN{k}_", wx - 0.45, wx + 0.45, 0.0, 0.9, -20.75, -20.45, "trim", False)
        sbox(d, f"TruckWheelS{k}_", wx - 0.45, wx + 0.45, 0.0, 0.9, -18.35, -18.05, "trim", False)
    sbox(g, "CourtBarrel", 6.0, 6.9, 0.0, 1.2, -20.5, -19.6, "barrel")
    scyl(g, "CourtBarrelB", 7.4, -18.8, 0.45, 0.0, 1.2, "barrel_blue")


def square(g, d):
    """Centre: a decorated pine on a snow mound (shared by both halves, built once)."""
    m.cyl(g, "Mound", 0.0, 0.0, 3.0, 0.0, 0.45, "snow", sides=14)
    m.cyl(g, "TreeTrunk", 0.0, 0.0, 0.5, 0.45, 2.0, "bark", sides=8)
    for k, (y0, y1, r) in enumerate([(1.6, 4.6, 2.6), (3.6, 6.4, 2.0), (5.4, 8.0, 1.4), (7.2, 9.4, 0.8)]):
        m.cyl(g, f"TreeLeaves{k}", 0.0, 0.0, r, y0, y1, "pine", sides=8, cone=True)
    for k, (bx, by, bz) in enumerate([(1.9, 2.4, 0.6), (-1.6, 2.6, -1.1), (0.4, 3.9, 1.6), (-1.2, 4.3, 1.0),
                                       (1.1, 5.4, -0.9), (-0.6, 6.6, -0.7), (0.5, 7.2, 0.6)]):
        m.prop(d, f"Bauble{k}", bx, bz, 0.22, 0.22, 0.22, y=by, mat="lamp", collide=False)
    m.prop(d, "TreeStar", 0.0, 0.0, 0.4, 0.4, 0.4, y=9.35, mat="lamp", collide=False)
    # Benches around the mound (knee-high cover).
    sbox(g, "Bench", -6.5, -5.0, 0.0, 0.5, -2.0, 2.0, "door")


def street(g, d):
    """Street furniture on the west half (twinned): a parked car, crates, lamps."""
    # Car: body and cabin.
    sbox(g, "CarBody", -15.5, -11.2, 0.0, 1.0, 1.0, 2.9, "container_green")
    sbox(g, "CarCabin", -14.6, -12.2, 1.0, 1.65, 1.1, 2.8, "window")
    sbox(d, "CarSnow", -14.6, -12.2, 1.65, 1.75, 1.1, 2.8, "snow", False)
    # Crates on the pavement corner.
    sbox(g, "StreetCrateLow", -18.0, -16.8, 0.0, 1.2, -3.4, -2.2, "crate")
    sbox(g, "StreetCrateHigh", -19.3, -18.0, 0.0, 2.4, -3.6, -2.2, "crate")
    # Lamp posts (two per half) with their lights.
    for k, (lx, lz) in enumerate([(-10.0, -4.6), (3.0, -6.6)]):
        scyl(d, f"LampPost{k}_", lx, lz, 0.1, 0.0, 3.6, "trim", collide=False, sides=6)
        sbox(d, f"LampHead{k}_", lx - 0.22, lx + 0.22, 3.6, 3.95, lz - 0.22, lz + 0.22, "lamp", False)
        slamp(d, f"StreetLight{k}_", lx, 3.5, lz, energy=1.5, reach=12.0)
    # Snow drifts along the house fronts (look only).
    sbox(d, "Drift", -22.6, -21.2, 0.0, 0.25, -7.0, -6.0, "snow", False)


def backdrop():
    """Beyond the town walls (unreachable): gabled houses, a church spire, pines."""
    b = "Geometry/Backdrop"
    for k, (cx, cz, w, depth, h) in enumerate([(-22.0, -30.0, 10.0, 8.0, 6.5), (-6.0, -31.0, 12.0, 9.0, 7.5),
                                                 (14.0, -29.0, 9.0, 7.0, 6.0), (30.0, -32.0, 10.0, 8.0, 7.0),
                                                 (-42.0, -12.0, 8.0, 10.0, 6.5), (-43.0, 10.0, 8.0, 12.0, 7.0)]):
        for side, sign in (("W", 1), ("E", -1)):
            x, z = cx * sign, cz * sign
            mat = ["brick", "planks", "brick_painted"][k % 3]
            m.box(b, f"House{k}{side}", x - w / 2, x + w / 2, 0.0, h, z - depth / 2, z + depth / 2, mat, False)
            # Gable roof: two slabs pitched 35 degrees, rising from the eaves to the ridge (along x).
            half = depth / 2 + 0.4
            slab = half / math.cos(math.radians(ROOF_PITCH))
            rise = slab * math.sin(math.radians(ROOF_PITCH)) / 2
            m.tilted_box(b, f"House{k}{side}RoofA", x, h + rise, z - half / 2, w + 0.6, 0.25, slab, (-ROOF_PITCH, 0.0, 0.0), "roof", False)
            m.tilted_box(b, f"House{k}{side}RoofB", x, h + rise, z + half / 2, w + 0.6, 0.25, slab, (ROOF_PITCH, 0.0, 0.0), "roof", False)
            # A lit window on the side that faces the town.
            face = z + depth / 2 if z < 0 else z - depth / 2
            m.box(b, f"House{k}{side}Window", x - 1.0, x + 1.0, 2.5, 3.6, face - 0.03, face + 0.03, "window_lit", False)
    # Church with a spire, north-east beyond the wall.
    m.box(b, "Church", 18.0, 28.0, 0.0, 9.0, -48.0, -36.0, "concrete", False)
    m.box(b, "ChurchTower", 20.5, 25.5, 0.0, 17.0, -38.5, -33.5, "concrete", False)
    m.cyl(b, "ChurchSpire", 23.0, -36.0, 3.2, 17.0, 25.0, "roof", collide=False, sides=4, cone=True)
    for i in range(24):
        side = i % 2
        along = -HX - 4 + (i // 2) * 6.2
        z = (-HZ - 9.0 - (i * 7 % 5)) * (1 if side == 0 else -1)
        x = along * (1 if side == 0 else -1)
        _pine(b, f"Pine{i}", x, z, 6.0 + (i * 3 % 5))


def _pine(parent, name, x, z, height):
    m.cyl(parent, f"{name}Trunk", x, z, 0.25, 0.0, height * 0.3, "bark", collide=False, sides=6)
    for k, (share, radius) in enumerate([(0.22, 1.9), (0.45, 1.4), (0.66, 0.9)]):
        m.cyl(parent, f"{name}Leaves{k}", x, z, radius, height * share, height * (share + 0.38), "pine",
              collide=False, sides=7, cone=True)


ENVIRONMENT = """
[sub_resource type="ProceduralSkyMaterial" id="SkyMat"]
sky_top_color = Color(0.07, 0.08, 0.14, 1)
sky_horizon_color = Color(0.3, 0.3, 0.38, 1)
ground_bottom_color = Color(0.12, 0.12, 0.16, 1)
ground_horizon_color = Color(0.3, 0.3, 0.38, 1)

[sub_resource type="Sky" id="Sky"]
sky_material = SubResource("SkyMat")

[sub_resource type="Environment" id="Env"]
background_mode = 2
sky = SubResource("Sky")
ambient_light_source = 3
ambient_light_energy = 0.38
tonemap_mode = 2
fog_enabled = true
fog_light_color = Color(0.28, 0.29, 0.36, 1)
fog_density = 0.013
fog_sky_affect = 0.45
"""

SUN = """
[node name="Moon" type="DirectionalLight3D" parent="."]
rotation = Vector3(-0.85, -0.6, 0)
position = Vector3(0, 30, 0)
light_color = Color(0.72, 0.78, 1, 1)
light_energy = 0.42
shadow_enabled = true
"""


if __name__ == "__main__":
    build()
    m.write(OUT, "SnowTown", ENVIRONMENT, SUN)
    if "--preview" in sys.argv:
        m.preview(os.path.join(sys.argv[sys.argv.index("--preview") + 1], "snow_town.png"), HX + 2)
    print(f"wrote {os.path.relpath(OUT, ROOT)}: {len(m.nodes)} nodes, {len(m.markers)} markers")
