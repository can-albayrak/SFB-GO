"""Builds the mall blockout scene (stage 7) from the layout below.

    python tools/maps/build_mall_blockout.py [--preview DIR]

Writes scenes/maps/mall/mall.tscn: CSG boxes with collision (layer 1, so grapple, bullets and
step-up see them), SpawnPoints, Pickups and AirdropPoints. Layout rules: docs/GDD.md
"Harita tasarım kuralları". Once the layout settles the scene can be edited by hand in Godot
and this script retired; until then edit here and re-run (it overwrites the scene).

--preview DIR also draws a top-down PNG per level (needs Pillow), for checking the plan.

Axes: x east, z south (north = -z), y up. Building 64 x 48 m: x -32..32, z -24..24.
Levels: ground 0 m, upper 5 m, roof 10 m. Outside: loading dock (west), parking (east),
north and south strips, all inside a fenced site x -48..62, z -32..32.
"""

import math
import os
import sys

ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "scenes", "maps", "mall", "mall.tscn")

UPPER = 5.0
ROOF = 10.0
SLAB = 0.4  # Floor slab thickness; walls stop under the slab above.
WALL = 0.4
DOOR_H = 3.0  # Door openings; a lintel fills the rest up to the slab.
RAIL_H = 1.1  # Railings and parapets are half cover.

CLIP_H = 60.0  # Invisible site walls: higher than a grapple can reach from the roof (40 m).

boxes = []  # (name, parent, center, size, material, rotation)
clips = []  # (name, center, size): invisible StaticBody3D walls
markers = []  # (group, name, position, yaw, extra)


def add_box(parent, name, x0, x1, y0, y1, z0, z1, mat="Mat_concrete"):
    x0, x1 = sorted((x0, x1))
    y0, y1 = sorted((y0, y1))
    z0, z1 = sorted((z0, z1))
    if x1 - x0 < 0.01 or y1 - y0 < 0.01 or z1 - z0 < 0.01:
        return
    boxes.append((name, parent, ((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2), (x1 - x0, y1 - y0, z1 - z0), mat, None))


def prop(parent, name, x, z, sx, sy, sz, y=0.0, mat="Mat_crate"):
    """A box standing on the floor at height y, centred on x/z."""
    add_box(parent, name, x - sx / 2, x + sx / 2, y, y + sy, z - sz / 2, z + sz / 2, mat)


def _segments(a0, a1, openings):
    """Splits a0..a1 around the openings; returns (solid spans, opening spans)."""
    solid, cuts, cursor = [], [], a0
    for o0, o1 in sorted(openings):
        o0, o1 = max(o0, a0), min(o1, a1)
        if o1 <= o0:
            continue
        if o0 > cursor:
            solid.append((cursor, o0))
        cuts.append((o0, o1))
        cursor = max(cursor, o1)
    if cursor < a1:
        solid.append((cursor, a1))
    return solid, cuts


def wall(parent, name, axis, at, a0, a1, y0, y1, openings=(), door_h=DOOR_H, mat="Mat_wall", thick=WALL):
    """A wall along `axis` ("x": runs along x at z=at; "z": runs along z at x=at) with door openings."""
    solid, cuts = _segments(a0, a1, openings)
    parts = [(s0, s1, y0, y1) for s0, s1 in solid]
    if y1 - y0 > door_h + 0.05:
        parts += [(c0, c1, y0 + door_h, y1) for c0, c1 in cuts]  # Lintels.
    for i, (s0, s1, b0, b1) in enumerate(parts):
        if axis == "x":
            add_box(parent, f"{name}_{i}", s0, s1, b0, b1, at - thick / 2, at + thick / 2, mat)
        else:
            add_box(parent, f"{name}_{i}", at - thick / 2, at + thick / 2, b0, b1, s0, s1, mat)


def slab(parent, name, x0, x1, z0, z1, top, holes=(), mat="Mat_floor"):
    """A floor slab with rectangular holes, cut into a grid of boxes and merged along x."""
    xs = sorted({x0, x1} | {v for h in holes for v in (h[0], h[1]) if x0 < v < x1})
    zs = sorted({z0, z1} | {v for h in holes for v in (h[2], h[3]) if z0 < v < z1})

    def is_hole(cx, cz):
        return any(h[0] <= cx <= h[1] and h[2] <= cz <= h[3] for h in holes)

    count = 0
    for j in range(len(zs) - 1):
        run = None
        for i in range(len(xs) - 1):
            cx, cz = (xs[i] + xs[i + 1]) / 2, (zs[j] + zs[j + 1]) / 2
            if is_hole(cx, cz):
                if run is not None:
                    add_box(parent, f"{name}_{count}", run, xs[i], top - SLAB, top, zs[j], zs[j + 1], mat)
                    count += 1
                    run = None
            elif run is None:
                run = xs[i]
        if run is not None:
            add_box(parent, f"{name}_{count}", run, xs[-1], top - SLAB, top, zs[j], zs[j + 1], mat)
            count += 1


RAMP_TUCK = 0.3  # The low end runs on under the floor it starts from, so there is no lip.


def ramp(parent, name, axis, a0, a1, w0, w1, y_low, y_high, thick=0.3, mat="Mat_concrete"):
    """A walkable ramp along `axis`, rising from coordinate a0 (y_low) to a1 (y_high).
    w0..w1 is its extent across. Used for escalators and stairs (step visuals come later).
    a1 must be exactly the edge of the floor it reaches: the top meets that floor flush.
    A top ending short of the edge leaves a convex lip where the capsule's rounded bottom
    gets a tilted contact, floor snap refuses it and players walking down take off."""
    run, rise = a1 - a0, y_high - y_low
    slope = math.hypot(run, rise)
    a0 -= RAMP_TUCK * run / slope
    y_low -= RAMP_TUCK * rise / slope
    run, rise = a1 - a0, y_high - y_low
    length = math.hypot(run, rise)
    mid_a, mid_y, mid_w = (a0 + a1) / 2, (y_low + y_high) / 2, (w0 + w1) / 2
    if axis == "z":
        angle = math.atan2(-rise, run)  # Rotation about x maps local +z onto the slope.
        if math.cos(angle) < 0:
            angle += math.pi
        normal = (0.0, math.cos(angle), math.sin(angle))
        center = (mid_w - normal[0] * thick / 2, mid_y - normal[1] * thick / 2, mid_a - normal[2] * thick / 2)
        size = (abs(w1 - w0), thick, length)
        rot = (angle, 0.0, 0.0)
    else:
        angle = math.atan2(rise, run)  # Rotation about z maps local +x onto the slope.
        if math.cos(angle) < 0:
            angle += math.pi
        normal = (-math.sin(angle), math.cos(angle), 0.0)
        center = (mid_a - normal[0] * thick / 2, mid_y - normal[1] * thick / 2, mid_w - normal[2] * thick / 2)
        size = (length, thick, abs(w1 - w0))
        rot = (0.0, 0.0, angle)
    boxes.append((name, parent, center, size, mat, rot))


def marker(group, name, x, y, z, face=(0.0, 0.0), extra=None):
    """face: point the marker looks toward (spawns face into the action)."""
    yaw = math.atan2(-(face[0] - x), -(face[1] - z))
    markers.append((group, name, (x, y, z), yaw, extra))


# --- Layout ---------------------------------------------------------------------------

def build():
    G, U, R, X = "Geometry/Ground", "Geometry/Upper", "Geometry/Roof", "Geometry/Outside"
    g_top, u0, u_top = UPPER - SLAB, UPPER, ROOF - SLAB

    # Site floor and fence (the fence is full cover; nobody leaves the site).
    add_box(X, "SiteFloor", -48, 62, -1, 0, -32, 32, "Mat_floor")
    wall(X, "FenceN", "x", -32, -48, 62, 0, 3, mat="Mat_concrete", thick=0.3)
    wall(X, "FenceS", "x", 32, -48, 62, 0, 3, mat="Mat_concrete", thick=0.3)
    wall(X, "FenceW", "z", -48, -32, 32, 0, 3, mat="Mat_concrete", thick=0.3)
    wall(X, "FenceE", "z", 62, -32, 32, 0, 3, mat="Mat_concrete", thick=0.3)
    # A bhop off the roof clears the 3 m fence (the strips are only 8 m wide): invisible
    # walls on the fence line keep everyone on the site.
    for name, c, size in [("ClipN", (7, -32.4), (111, 0.6)), ("ClipS", (7, 32.4), (111, 0.6)),
                          ("ClipW", (-48.4, 0), (0.6, 65)), ("ClipE", (62.4, 0), (0.6, 65))]:
        clips.append((name, (c[0], CLIP_H / 2, c[1]), (size[0], CLIP_H, size[1])))

    # Outer walls. Ground: service door west and north, supermarket door west, main entrance
    # south, two department store doors east. Upper: food court opens west (fire escape) and
    # east (balcony over the parking).
    wall(G, "OuterN", "x", -24, -32, 32, 0, g_top, [(10, 11.5)])
    wall(G, "OuterS", "x", 24, -32, 32, 0, g_top, [(-3, 3)], door_h=3.5)
    wall(G, "OuterE", "z", 32, -24, 24, 0, g_top, [(-3, 1), (6, 10)])
    wall(G, "OuterW", "z", -32, -24, 24, 0, g_top, [(-23, -20.5), (4, 8)])
    wall(U, "OuterN", "x", -24, -32, 32, u0, u_top)
    wall(U, "OuterS", "x", 24, -32, 32, u0, u_top)
    wall(U, "OuterE", "z", 32, -24, 24, u0, u_top, [(13.5, 17.5)])
    wall(U, "OuterW", "z", -32, -24, 24, u0, u_top, [(14, 16)])

    # Ground floor --------------------------------------------------------------
    # North shops (4 x 8 m) along the ring, a narrow service corridor behind them.
    wall(G, "NorthShopFronts", "x", -12, -16, 16, 0, g_top, [(-14, -10), (-6, -2), (2, 6), (10, 14)])
    wall(G, "ServiceSouth", "x", -20, -32, 16, 0, g_top, [(-26, -24.5), (-13.5, -12), (5, 6.5)])
    wall(G, "ShopDivA", "z", -8, -20, -12, 0, g_top, [(-17, -15.5)])
    wall(G, "ShopDivB", "z", 0, -20, -12, 0, g_top)
    wall(G, "ShopDivC", "z", 8, -20, -12, 0, g_top, [(-17, -15.5)])
    # Ring walls toward the wings; the corridor's east end runs into the department store.
    wall(G, "RingWestWall", "z", -16, -20, 24, 0, g_top, [(-6, -2), (2, 6), (18, 19.5)])
    wall(G, "RingEastWall", "z", 16, -20, 24, 0, g_top, [(-6, -2), (2, 6), (18, 19.5)])
    # South: two shops either side of the entrance corridor.
    wall(G, "SouthShopFronts", "x", 12, -16, 16, 0, g_top, [(-12, -7), (-3, 3), (7, 12)])
    wall(G, "EntranceWallW", "z", -3, 12, 24, 0, g_top, [(17, 19)])
    wall(G, "EntranceWallE", "z", 3, 12, 24, 0, g_top, [(17, 19)])

    # Atrium: dry fountain (half cover, jump on it), kiosks (full cover), planters.
    prop(G, "FountainBasin", -4, 1.5, 4, 0.8, 4, mat="Mat_concrete")
    prop(G, "FountainStatue", -4, 1.5, 1, 2.4, 1, mat="Mat_concrete")
    prop(G, "KioskW", -13, -9, 2.5, 2.4, 2.5)
    prop(G, "KioskE", 13, 9, 2.5, 2.4, 2.5)
    for i, (px, pz) in enumerate([(-12.5, 4), (12.5, -4), (6, -9.5), (-6, 9.5)]):
        prop(G, f"Planter{i}", px, pz, 1.6, 1.0, 1.6, mat="Mat_concrete")
    # Escalators: both start at the atrium centre line and land on the east / west gallery.
    ramp(G, "EscalatorW", "x", 0, -10, -6, -4, 0, UPPER)
    ramp(G, "EscalatorE", "x", 0, 10, 4, 6, 0, UPPER)

    # Supermarket (west wing): shelf rows (full cover), checkout counters (half cover),
    # stairs up along the west wall.
    for i, sx in enumerate([-26, -22.5, -19]):
        prop(G, f"ShelfN{i}", sx, -8, 0.8, 2.0, 12)
        prop(G, f"ShelfS{i}", sx, 8, 0.8, 2.0, 12)
    for i, cx in enumerate([-29, -24, -19]):
        prop(G, f"Checkout{i}", cx, 17, 3, 1.1, 0.8)
    ramp(G, "StairsWest", "z", -6, -18, -31.6, -29.1, 0, UPPER)
    wall(G, "StairsWestRail", "z", -28.9, -18, -6, 0, RAIL_H, mat="Mat_concrete", thick=0.2)

    # Service corridor: crates (half cover).
    prop(G, "ServiceCrateA", -8, -22.4, 1.2, 1.2, 1.2)
    prop(G, "ServiceCrateB", 4, -21, 1.0, 1.0, 1.0)

    # Department store (east wing): racks (half cover), tall shelves, display tables, counter,
    # stairs up along the east wall.
    for i, (rx, rz) in enumerate([(20, -14), (24, -14), (20, -4), (24, -4), (20, 6), (24, 6)]):
        prop(G, f"Rack{i}", rx, rz, 2.5, 1.2, 0.6)
    prop(G, "TallShelf", 24, -20.5, 5, 2.0, 0.8)
    prop(G, "DisplayA", 20, 16, 2, 1.0, 1.5)
    prop(G, "DisplayB", 26, 16, 2, 1.0, 1.5)
    prop(G, "Counter", 27.5, -6, 0.8, 1.1, 3)
    ramp(G, "StairsEast", "z", -8, -20, 29.1, 31.6, 0, UPPER)
    wall(G, "StairsEastRail", "z", 28.9, -20, -8, 0, RAIL_H, mat="Mat_concrete", thick=0.2)

    # South shops: a little cover each.
    prop(G, "ShopSWShelf", -10, 20, 4, 2.0, 0.8)
    prop(G, "ShopSETable", 9, 17, 2, 1.0, 1.5)

    # Upper floor ---------------------------------------------------------------
    slab(U, "Slab", -32, 32, -24, 24, UPPER, holes=[
        (-10, 10, -7, 7),          # Atrium void.
        (-31.75, -28.75, -18, -6),  # West stairs.
        (28.75, 31.75, -20, -8),    # East stairs.
    ])
    # Gallery railings around the void, open where the escalators land.
    wall(U, "RailVoidW", "z", -10, -7, 7, u0, u0 + RAIL_H, [(-6, -4)], mat="Mat_concrete", thick=0.2)
    wall(U, "RailVoidE", "z", 10, -7, 7, u0, u0 + RAIL_H, [(4, 6)], mat="Mat_concrete", thick=0.2)
    wall(U, "RailVoidN", "x", -7, -10, 10, u0, u0 + RAIL_H, mat="Mat_concrete", thick=0.2)
    wall(U, "RailVoidS", "x", 7, -10, 10, u0, u0 + RAIL_H, mat="Mat_concrete", thick=0.2)
    wall(U, "RailStairsW", "z", -28.75, -18, -6, u0, u0 + RAIL_H, mat="Mat_concrete", thick=0.2)
    wall(U, "RailStairsE", "z", 28.75, -20, -8, u0, u0 + RAIL_H, mat="Mat_concrete", thick=0.2)

    # Upper north shops (dead space behind them is closed off).
    wall(U, "NorthShopFronts", "x", -12, -16, 16, u0, u_top, [(-14, -10), (-6, -2), (2, 6), (10, 14)])
    wall(U, "NorthShopBack", "x", -20, -16, 16, u0, u_top)
    wall(U, "ShopDivA", "z", -8, -20, -12, u0, u_top, [(-17, -15.5)])
    wall(U, "ShopDivB", "z", 0, -20, -12, u0, u_top, [(-17, -15.5)])
    wall(U, "ShopDivC", "z", 8, -20, -12, u0, u_top, [(-17, -15.5)])
    wall(U, "RingWestWall", "z", -16, -24, 12, u0, u_top, [(-6, -2), (2, 6)])
    wall(U, "RingEastWall", "z", 16, -24, 12, u0, u_top, [(-6, -2), (2, 6)])
    prop(U, "ShopCrate0", -12, -17, 1.2, 1.2, 1.2, y=u0)
    prop(U, "ShopShelf1", -4, -18.5, 4, 2.0, 0.8, y=u0)
    prop(U, "ShopCrate2", 4, -15, 1.2, 1.2, 1.2, y=u0)
    prop(U, "ShopShelf3", 12, -18.5, 4, 2.0, 0.8, y=u0)

    # Food court: one long corridor across the whole building (Hawk's sightline), split from
    # the gallery by a wall, counters (half cover) and stall walls along the south.
    wall(U, "FoodCourtWall", "x", 12, -32, 32, u0, u_top, [(-26, -24.5), (-14, -10), (-3, 3), (10, 14), (22, 23.5)])
    for i, cx in enumerate([-26, -18, -10, -2, 6, 14, 22, 29]):
        prop(U, f"FoodCounter{i}", cx, 18.6, 5 if i < 7 else 4, 1.1, 0.8, y=u0)
    for i, wx in enumerate([-22, -14, -6, 2, 10, 18, 26]):
        add_box(U, f"StallWall{i}_0", wx - 0.2, wx + 0.2, u0, u_top, 19, 24, "Mat_wall")
    for i, (tx, tz) in enumerate([(-25, 16.8), (-17, 14.2), (-9, 16.8), (0, 14.2), (9, 16.8), (17, 14.2), (25, 16.8)]):
        prop(U, f"Table{i}", tx, tz, 1.6, 1.0, 1.6, y=u0)

    # West upper: storage hall with the stair opening, offices along the ring wall.
    wall(U, "StorageWall", "z", -24, -24, 12, u0, u_top, [(-18, -16.5), (-6, -4.5), (4, 5.5)])
    wall(U, "OfficeWallA", "x", -12, -24, -16, u0, u_top, [(-21, -19.5)])
    wall(U, "OfficeWallB", "x", 0, -24, -16, u0, u_top, [(-21, -19.5)])
    prop(U, "StorageCrateA", -27, 4, 1.2, 1.2, 1.2, y=u0)
    prop(U, "StorageCrateB", -26.5, -21, 2.0, 2.0, 2.0, y=u0)
    prop(U, "OfficeDesk", -20, -4, 2, 1.0, 1, y=u0)

    # East upper: department store floor, stairs on to the roof.
    for i, (rx, rz) in enumerate([(21, -10), (25, -2), (21, 4)]):
        prop(U, f"Rack{i}", rx, rz, 2.5, 1.2, 0.6, y=u0)
    prop(U, "TallShelf", 22, -16, 4, 2.0, 0.8, y=u0)
    ramp(U, "StairsRoof", "z", -6, 6, 29.1, 31.6, u0, ROOF)
    wall(U, "StairsRoofRail", "z", 28.9, -6, 6, u0, u0 + RAIL_H, mat="Mat_concrete", thick=0.2)

    # Roof ----------------------------------------------------------------------
    slab(R, "Slab", -32, 32, -24, 24, ROOF, holes=[
        (-6, 6, -4, 4),            # Skylight over the atrium (open: drop in, airdrops fall through).
        (28.75, 31.75, -6, 6),     # Roof stairs.
    ])
    wall(R, "ParapetN", "x", -24, -32, 32, ROOF, ROOF + RAIL_H, mat="Mat_concrete", thick=0.3)
    wall(R, "ParapetS", "x", 24, -32, 32, ROOF, ROOF + RAIL_H, mat="Mat_concrete", thick=0.3)
    wall(R, "ParapetE", "z", 32, -24, 24, ROOF, ROOF + RAIL_H, mat="Mat_concrete", thick=0.3)
    wall(R, "ParapetW", "z", -32, -24, 24, ROOF, ROOF + RAIL_H, [(-3, 0)], mat="Mat_concrete", thick=0.3)
    for name, a, b0, b1, ax in [("CurbN", -4, -6, 6, "x"), ("CurbS", 4, -6, 6, "x"), ("CurbW", -6, -4, 4, "z"), ("CurbE", 6, -4, 4, "z")]:
        wall(R, name, ax, a, b0, b1, ROOF, ROOF + 0.4, mat="Mat_concrete", thick=0.3)
    prop(R, "AirConA", -20, -15, 2.5, 1.4, 2, y=ROOF)
    prop(R, "AirConB", 18, 10, 2.5, 1.4, 2, y=ROOF)
    prop(R, "AirConTall", -8, -16, 2.5, 2.4, 2, y=ROOF)
    prop(R, "WaterTank", 20, -16, 3, 3, 3, y=ROOF, mat="Mat_concrete")
    prop(R, "VentA", 8, 15, 1, 1.2, 1, y=ROOF)
    prop(R, "VentB", -18, 16, 1, 1.2, 1, y=ROOF)
    # Machine rooms (full cover) and more units break up the roof's long sightlines.
    prop(R, "MachineRoomW", -24, 8, 4, 3, 4, y=ROOF, mat="Mat_wall")
    prop(R, "MachineRoomE", 10, -12, 4, 3, 4, y=ROOF, mat="Mat_wall")
    for i, (ax, az) in enumerate([(-26, -6), (-12, 12), (2, 18), (14, 0), (24, 18), (26, -8), (-2, -10)]):
        prop(R, f"AirConRow{i}", ax, az, 2.5, 1.4, 2, y=ROOF)

    # Outside ---------------------------------------------------------------------
    # Parking (east): cars and barriers (half cover), a booth (full cover).
    for i, (cx, cz) in enumerate([(40, -20), (48, -10), (56, -22), (40, 12), (48, 22), (56, 8)]):
        prop(X, f"Car{i}", cx, cz, 4.4, 1.4, 1.9)
    for i, (bx, bz) in enumerate([(44, 0), (54, -5), (54, 5)]):
        prop(X, f"Barrier{i}", bx, bz, 3, 0.9, 0.6, mat="Mat_concrete")
    prop(X, "Booth", 58, 0, 2.4, 2.6, 2.4, mat="Mat_concrete")
    prop(X, "TiresA", 36, -28, 1.2, 1.0, 1.2)
    prop(X, "TiresB", 60, 28, 1.2, 1.0, 1.2)
    # Balcony off the food court's east end, stairs down to the parking.
    slab(X, "Balcony", 32, 36, 12.5, 18.5, UPPER, mat="Mat_concrete")
    wall(X, "BalconyRail", "z", 36, 12.5, 18.5, UPPER, UPPER + RAIL_H, mat="Mat_concrete", thick=0.2)
    ramp(X, "BalconyStairs", "z", 30.5, 18.5, 33, 35.5, 0, UPPER)

    # Loading dock (west): raised dock with a ramp, containers (full cover), crates.
    add_box(X, "Dock", -36, -32.2, 0, 1.2, -20, -2, "Mat_concrete")
    ramp(X, "DockRamp", "z", 3, -2, -36, -33, 0, 1.2)
    prop(X, "ContainerA", -42, -22, 2.5, 2.6, 6, mat="Mat_wall")
    prop(X, "ContainerB", -44, 6, 6, 2.6, 2.5, mat="Mat_wall")
    prop(X, "DockCrateA", -39, -12, 1.2, 1.2, 1.2)
    prop(X, "DockCrateB", -40.5, 22, 2.0, 2.0, 2.0)
    # Fire escape: ground -> landing at the food court door -> roof.
    ramp(X, "FireEscapeLow", "z", 29, 17, -34.5, -32.3, 0, UPPER)
    slab(X, "FireLanding", -37, -32, 12, 17, UPPER, mat="Mat_concrete")
    ramp(X, "FireEscapeHigh", "z", 12, 0, -37, -35, UPPER, ROOF)
    slab(X, "FireBridge", -37, -32, -3, 0, ROOF, mat="Mat_concrete")
    wall(X, "FireLandingRail", "z", -37, 12, 17, UPPER, UPPER + RAIL_H, mat="Mat_concrete", thick=0.2)

    # North and south strips: dumpsters, barriers, a car.
    prop(X, "DumpsterA", -10, -28, 2, 1.4, 1.2, mat="Mat_wall")
    prop(X, "DumpsterB", 20, -28, 2, 1.4, 1.2, mat="Mat_wall")
    prop(X, "BarrierS0", -14, 28, 3, 0.9, 0.6, mat="Mat_concrete")
    prop(X, "BarrierS1", 14, 28, 3, 0.9, 0.6, mat="Mat_concrete")
    prop(X, "CarS", 24, 28, 4.4, 1.4, 1.9)

    # Gameplay markers ----------------------------------------------------------
    # Spawns: spread over every zone and level (GDD: 10-12), facing the building centre.
    for i, (x, y, z) in enumerate([
        (-24.25, 0, 9), (-4, 0, -16), (-28, 0, -21.75), (23, 0, 19), (48, 0, -24), (52, 0, 16),
        (-42, 0, -8), (-29, UPPER, 14.5), (28, UPPER, 14.5), (-20, UPPER, -18), (22, UPPER, -20), (0, ROOF, -16),
    ]):
        marker("SpawnPoints", f"Spawn{i + 1}", x, y + 0.1, z)
    # Pickups (GDD: 5-6): Health in narrow, safe spots; Speed / Double Jump in open, risky ones.
    for name, kind, (x, y, z) in [
        ("HealthService", "health", (-2, 0, -21.75)),
        ("HealthOffice", "health", (-20, UPPER, -6)),
        ("HealthShop", "health", (10, 0, 20)),
        ("SpeedAtrium", "speed", (6, 0, 1.5)),
        ("SpeedParking", "speed", (44, 0, -6)),
        ("DoubleJumpRoof", "double_jump", (-12, ROOF, 0)),
    ]:
        marker("Pickups", name, x, y, z, extra=kind)
    # Airdrops (open sky): atrium under the skylight, parking, roof, loading dock.
    for i, (x, y, z) in enumerate([(3.5, 0, -1.5), (50, 0, 0), (-16, ROOF, -4), (-41, 0, 14)]):
        marker("AirdropPoints", f"Drop{i + 1}", x, y, z)


# --- Scene writer ---------------------------------------------------------------------

HEADER = """[gd_scene format=3]

[ext_resource type="PackedScene" path="res://scenes/pickups/pickup.tscn" id="1_pickup"]
[ext_resource type="Resource" path="res://data/pickups/health.tres" id="2_health"]
[ext_resource type="Resource" path="res://data/pickups/speed.tres" id="3_speed"]
[ext_resource type="Resource" path="res://data/pickups/double_jump.tres" id="4_double_jump"]

[sub_resource type="ProceduralSkyMaterial" id="SkyMat"]
sky_top_color = Color(0.17, 0.2, 0.25, 1)
sky_horizon_color = Color(0.4, 0.44, 0.5, 1)
ground_bottom_color = Color(0.1, 0.11, 0.13, 1)
ground_horizon_color = Color(0.36, 0.39, 0.44, 1)

[sub_resource type="Sky" id="Sky"]
sky_material = SubResource("SkyMat")

[sub_resource type="Environment" id="Env"]
background_mode = 2
sky = SubResource("Sky")
ambient_light_source = 3
ambient_light_energy = 0.7
tonemap_mode = 2
fog_enabled = true
fog_light_color = Color(0.33, 0.37, 0.43, 1)
fog_density = 0.007
fog_sky_affect = 0.6

[sub_resource type="FastNoiseLite" id="GritNoise"]
noise_type = 5
frequency = 0.18
fractal_octaves = 3

[sub_resource type="Gradient" id="GritRamp"]
colors = PackedColorArray(0.72, 0.72, 0.72, 1, 1, 1, 1, 1)

[sub_resource type="NoiseTexture2D" id="GritTexture"]
width = 128
height = 128
seamless = true
color_ramp = SubResource("GritRamp")
noise = SubResource("GritNoise")

[sub_resource type="StandardMaterial3D" id="Mat_floor"]
albedo_color = Color(0.4, 0.41, 0.43, 1)
albedo_texture = SubResource("GritTexture")
roughness = 0.95
uv1_scale = Vector3(0.35, 0.35, 0.35)
uv1_triplanar = true
texture_filter = 2

[sub_resource type="StandardMaterial3D" id="Mat_wall"]
albedo_color = Color(0.33, 0.35, 0.39, 1)
albedo_texture = SubResource("GritTexture")
roughness = 0.95
uv1_scale = Vector3(0.5, 0.5, 0.5)
uv1_triplanar = true
texture_filter = 2

[sub_resource type="StandardMaterial3D" id="Mat_crate"]
albedo_color = Color(0.45, 0.42, 0.34, 1)
albedo_texture = SubResource("GritTexture")
roughness = 0.85
uv1_scale = Vector3(1.2, 1.2, 1.2)
uv1_triplanar = true
texture_filter = 2

[sub_resource type="StandardMaterial3D" id="Mat_concrete"]
albedo_color = Color(0.62, 0.62, 0.62, 1)
albedo_texture = SubResource("GritTexture")
roughness = 0.95
uv1_scale = Vector3(0.6, 0.6, 0.6)
uv1_triplanar = true
texture_filter = 2

[node name="Mall" type="Node3D"]

[node name="WorldEnvironment" type="WorldEnvironment" parent="."]
environment = SubResource("Env")

[node name="Sun" type="DirectionalLight3D" parent="."]
rotation = Vector3(-0.872665, 0.523599, 0)
position = Vector3(0, 30, 0)
light_color = Color(0.86, 0.9, 1, 1)
light_energy = 0.95
shadow_enabled = true

[node name="Geometry" type="Node3D" parent="."]

[node name="Ground" type="Node3D" parent="Geometry"]

[node name="Upper" type="Node3D" parent="Geometry"]

[node name="Roof" type="Node3D" parent="Geometry"]

[node name="Outside" type="Node3D" parent="Geometry"]
"""

PICKUP_DEFS = {"health": "2_health", "speed": "3_speed", "double_jump": "4_double_jump"}


def f(v):
    return f"{round(v, 4):g}"


def write_scene():
    clip_subs = "".join(
        f'\n[sub_resource type="BoxShape3D" id="Shape_{name}"]\nsize = Vector3({f(sz[0])}, {f(sz[1])}, {f(sz[2])})\n'
        for name, c, sz in clips)
    header = HEADER.replace('\n[node name="Mall"', clip_subs + '\n[node name="Mall"', 1)
    out = [header]
    names = set()
    for name, parent, c, s, mat, rot in boxes:
        key = (parent, name)
        assert key not in names, f"duplicate node {parent}/{name}"
        names.add(key)
        out.append(f'\n[node name="{name}" type="CSGBox3D" parent="{parent}"]')
        out.append(f"position = Vector3({f(c[0])}, {f(c[1])}, {f(c[2])})")
        if rot is not None:
            out.append(f"rotation = Vector3({f(rot[0])}, {f(rot[1])}, {f(rot[2])})")
        out.append("use_collision = true")
        out.append(f"size = Vector3({f(s[0])}, {f(s[1])}, {f(s[2])})")
        out.append(f'material = SubResource("{mat}")\n')
    out.append('\n[node name="Clips" type="Node3D" parent="Geometry"]')
    for name, c, sz in clips:
        out.append(f'\n[node name="{name}" type="StaticBody3D" parent="Geometry/Clips"]')
        out.append(f"position = Vector3({f(c[0])}, {f(c[1])}, {f(c[2])})")
        out.append(f'\n[node name="Shape" type="CollisionShape3D" parent="Geometry/Clips/{name}"]')
        out.append(f'shape = SubResource("Shape_{name}")')
    for group in ["SpawnPoints", "Pickups", "AirdropPoints"]:
        out.append(f'\n[node name="{group}" type="Node3D" parent="."]\n')
        for g, name, p, yaw, extra in markers:
            if g != group:
                continue
            if group == "Pickups":
                out.append(f'[node name="{name}" parent="Pickups" instance=ExtResource("1_pickup")]')
                out.append(f"position = Vector3({f(p[0])}, {f(p[1])}, {f(p[2])})")
                out.append(f'def = ExtResource("{PICKUP_DEFS[extra]}")\n')
            else:
                out.append(f'[node name="{name}" type="Marker3D" parent="{group}"]')
                out.append(f"position = Vector3({f(p[0])}, {f(p[1])}, {f(p[2])})")
                if group == "SpawnPoints":
                    out.append(f"rotation = Vector3(0, {f(yaw)}, 0)")
                out.append("")
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w", encoding="utf-8", newline="\n") as fh:
        fh.write("\n".join(out).rstrip("\n") + "\n")


def write_preview(folder):
    from PIL import Image, ImageDraw

    scale = 8
    x_min, z_min, w, h = -48, -32, 110, 64
    levels = [("ground", -1.0, UPPER - SLAB - 0.01), ("upper", UPPER - SLAB, ROOF - SLAB - 0.01), ("roof", ROOF - SLAB, 99)]
    os.makedirs(folder, exist_ok=True)
    for label, y_lo, y_hi in levels:
        img = Image.new("RGB", (w * scale, h * scale), (20, 20, 24))
        d = ImageDraw.Draw(img)

        def px(x, z):
            return ((x - x_min) * scale, (z - z_min) * scale)

        for name, parent, c, s, mat, rot in boxes:
            top = c[1] + s[1] / 2
            bottom = c[1] - s[1] / 2
            if rot is not None:  # Ramps: draw their footprint.
                if rot[0] != 0:
                    half = (s[0] / 2, s[2] / 2 * abs(math.cos(rot[0])))
                else:
                    half = (s[0] / 2 * abs(math.cos(rot[2])), s[2] / 2)
                if not (bottom < y_hi and top > y_lo):
                    continue
                d.rectangle([px(c[0] - half[0], c[2] - half[1]), px(c[0] + half[0], c[2] + half[1])], fill=(70, 120, 200))
                continue
            if not (bottom <= y_hi and top >= y_lo) or bottom > y_lo + 2.5:
                continue  # Other levels, and lintels over doors (so doors show).
            height = top - max(bottom, y_lo)
            if s[1] <= SLAB + 0.01 or name.startswith("SiteFloor"):
                color = (60, 60, 66)  # Walkable floor.
            elif height < 1.3:
                color = (200, 170, 60)  # Half cover.
            else:
                color = (220, 220, 220)  # Full cover / wall.
            d.rectangle([px(c[0] - s[0] / 2, c[2] - s[2] / 2), px(c[0] + s[0] / 2, c[2] + s[2] / 2)], fill=color)
        for g, name, p, yaw, extra in markers:
            if not (y_lo <= p[1] - 0.1 <= y_hi + 0.2 or (label == "roof" and p[1] >= ROOF - 0.2)):
                continue
            color = {"SpawnPoints": (60, 220, 90), "Pickups": (90, 200, 255), "AirdropPoints": (255, 80, 80)}[g]
            x, y = px(p[0], p[2])
            d.ellipse([x - 6, y - 6, x + 6, y + 6], fill=color)
            d.text((x + 7, y - 6), name, fill=color)
        img.save(os.path.join(folder, f"mall_{label}.png"))


if __name__ == "__main__":
    build()
    write_scene()
    if "--preview" in sys.argv:
        write_preview(sys.argv[sys.argv.index("--preview") + 1])
    print(f"wrote {os.path.relpath(OUT, ROOT)}: {len(boxes)} boxes, {len(markers)} markers")
