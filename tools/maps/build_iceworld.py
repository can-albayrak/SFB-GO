"""Builds the Ice Yard map: a bigger take on CS 1.6's fy_iceworld, low-poly PSX snow look.

    python tools/maps/build_iceworld.py [--preview DIR]

Writes scenes/maps/ice_yard/ice_yard.tscn (tools/maps/map_kit.py: CSG with collision on layer 1,
Poly Haven textures, SpawnPoints, Pickups, AirdropPoints). Edit the layout here and re-run.
--preview DIR draws a top-down PNG (needs Pillow).

Axes: x east, z south (north = -z), y up. Walled yard 67 x 67 m: the layout below is written
for 56 x 56 m (x, z -28..28) and every horizontal coordinate is scaled by SCALE (heights are
not). Overcast late afternoon. Four-way rotational symmetry (every quarter is the previous one
turned 90 degrees), so no side is better in free-for-all:
- Centre: ice plaza 14 x 14 behind 3.5 m ice walls with a 4 m gap in every side; a frozen
  fountain in the middle (basin, 5 m ice column), low crates around it, four lamp posts.
- Mid ring: in every quarter a long ice wall (2.5 m) and crate stacks (1 / 2 m, jumpable).
- Yard: a shipping container (2.6 m) with barrels in every quarter, lone crates.
- Corners: 3 m plank sniper nests under a tin roof, each with a ramp along the yard wall and a
  crate step on the other side.
- Spawns along the yard walls (3 per side), facing the plaza; trodden paths lead to the plaza.
- Concrete yard walls with buttresses and a lamp over every side's middle spawn. Outside
  (backdrop only, unreachable): warehouses, a water tower and pines; invisible walls stop
  grapples and bhop jumps there.
"""

import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from map_kit import MapBuilder, turn  # noqa: E402

ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "scenes", "maps", "ice_yard", "ice_yard.tscn")

SCALE = 1.2  # Horizontal scale of the whole layout (Can: 20% bigger than the first version).
HALF = 28.0  # Yard half size (inside of the walls), before SCALE.
WALL_H = 6.0
WALL_T = 1.0
PLAZA = 7.0  # Plaza half size.
PLAZA_WALL_H = 3.5
PLAZA_GAP = 2.0  # Half width of the opening in each plaza side.
NEST = 6.0  # Corner nest size.
NEST_H = 3.0
NEST_ROOF_H = 5.4
CLIP_H = 60.0  # Invisible walls over the yard walls: higher than any grapple reaches.
DECAL = 0.02  # Height of the walk-through paths and floors laid on the snow.

m = MapBuilder(SCALE)


def qbox(parent, name, q, x0, x1, y0, y1, z0, z1, mat, collide=True):
    """A box given for quarter 0, turned into `q`."""
    ax, az = turn(x0, z0, q)
    bx, bz = turn(x1, z1, q)
    m.box(parent, f"{name}{q}", ax, bx, y0, y1, az, bz, mat, collide)


def qcyl(parent, name, q, x, z, radius, y0, y1, mat, collide=True, sides=12, cone=False):
    tx, tz = turn(x, z, q)
    m.cyl(parent, f"{name}{q}", tx, tz, radius, y0, y1, mat, collide, sides, cone)


def qramp(parent, name, q, x_low, x_high, z0, z1, y_low, y_high, mat):
    """A ramp given for quarter 0 (rising along x), turned into `q`."""
    if q == 0:
        m.ramp(parent, f"{name}{q}", "x", x_low, x_high, z0, z1, y_low, y_high, mat)
    elif q == 1:  # (x, z) -> (-z, x): runs along z.
        m.ramp(parent, f"{name}{q}", "z", x_low, x_high, -z1, -z0, y_low, y_high, mat)
    elif q == 2:  # (x, z) -> (-x, -z)
        m.ramp(parent, f"{name}{q}", "x", -x_low, -x_high, -z1, -z0, y_low, y_high, mat)
    else:  # (x, z) -> (z, -x)
        m.ramp(parent, f"{name}{q}", "z", -x_low, -x_high, z0, z1, y_low, y_high, mat)


def build():
    g = "Geometry/Yard"
    d = "Geometry/Detail"
    # Ground: one slab under everything (the backdrop strip included).
    m.box(g, "Ground", -HALF - 32, HALF + 32, -1.0, 0.0, -HALF - 32, HALF + 32, "snow")

    # Yard walls with a darker cap; the clip walls above stop grapples and bhop jumps.
    for i, (x0, x1, z0, z1) in enumerate([
            (-HALF - WALL_T, HALF + WALL_T, -HALF - WALL_T, -HALF), (-HALF - WALL_T, HALF + WALL_T, HALF, HALF + WALL_T),
            (-HALF - WALL_T, -HALF, -HALF, HALF), (HALF, HALF + WALL_T, -HALF, HALF)]):
        m.box(g, f"YardWall{i}", x0, x1, 0.0, WALL_H, z0, z1, "concrete")
        m.box(g, f"YardWallCap{i}", x0 - 0.15, x1 + 0.15, WALL_H, WALL_H + 0.3, z0 - 0.15, z1 + 0.15, "trim")
        m.clip(f"Clip{i}", x0, x1, WALL_H, WALL_H + CLIP_H, z0, z1)

    # Plaza: ice walls, a gap in the middle of every side, the frozen fountain and crates inside.
    for q in range(4):
        qbox(g, "PlazaWallA", q, -PLAZA, -PLAZA_GAP, 0.0, PLAZA_WALL_H, -PLAZA - 0.5, -PLAZA + 0.5, "ice")
        qbox(g, "PlazaWallB", q, PLAZA_GAP, PLAZA + 0.5, 0.0, PLAZA_WALL_H, -PLAZA - 0.5, -PLAZA + 0.5, "ice")
        qbox(d, "PlazaWallCapA", q, -PLAZA - 0.1, -PLAZA_GAP, PLAZA_WALL_H, PLAZA_WALL_H + 0.15, -PLAZA - 0.6, -PLAZA + 0.6, "snow", False)
        qbox(d, "PlazaWallCapB", q, PLAZA_GAP, PLAZA + 0.6, PLAZA_WALL_H, PLAZA_WALL_H + 0.15, -PLAZA - 0.6, -PLAZA + 0.6, "snow", False)
        # Low crate inside each plaza corner (jump spot, peeks over the walls' gaps).
        qbox(g, "PlazaCrate", q, 3.0, 4.6, 0.0, 1.0, -4.6, -3.0, "crate")
        # Lamp post in each inner corner.
        qcyl(d, "PlazaLampPost", q, 5.6, -5.6, 0.1, 0.0, 3.4, "trim", sides=6)
        lx, lz = turn(5.6, -5.6, q)
        m.prop(d, f"PlazaLampHead{q}", lx, lz, 0.45, 0.35, 0.45, y=3.4, mat="lamp", collide=False)
        m.lamp(d, f"PlazaLight{q}", lx, 3.3, lz, energy=1.4, reach=9.0)
    m.box(d, "PlazaFloor", -PLAZA + 0.5, PLAZA - 0.5, 0.0, DECAL, -PLAZA + 0.5, PLAZA - 0.5, "ice", False)
    # Frozen fountain: snowy basin (a 0.5 m step), ice column (the old pillar's cover), icicle cap.
    m.cyl(g, "FountainBasin", 0.0, 0.0, 2.6, 0.0, 0.5, "concrete", sides=16)
    m.cyl(d, "FountainIce", 0.0, 0.0, 2.3, 0.5, 0.6, "ice", collide=False, sides=16)
    m.cyl(g, "Pillar", 0.0, 0.0, 1.2, 0.0, 5.0, "ice", sides=10)
    m.cyl(g, "PillarCap", 0.0, 0.0, 1.5, 5.0, 5.4, "trim", sides=10)
    m.cyl(d, "PillarIcicle", 0.0, 0.0, 0.9, 5.4, 6.4, "ice", collide=False, sides=10, cone=True)

    for q in range(4):
        # Mid ring: a long ice wall across the lane, offset so lanes stay open on one side.
        qbox(g, "MidWall", q, -12.0, -3.0, 0.0, 2.5, -15.6, -14.8, "ice")
        qbox(d, "MidWallSnow", q, -12.1, -2.9, 2.5, 2.65, -15.7, -14.7, "snow", False)
        # Crate stack next to it: 1 m, then 2 m behind (jump up, look over the mid wall).
        qbox(g, "CrateLow", q, 4.0, 5.6, 0.0, 1.0, -14.0, -12.4, "crate")
        qbox(g, "CrateHigh", q, 5.6, 7.6, 0.0, 2.0, -14.4, -12.4, "crate")
        # Lone crates in the open yard (half cover).
        qbox(g, "CrateYard", q, -20.0, -18.4, 0.0, 1.0, -9.0, -7.4, "crate")
        # Shipping container between the middle spawn and the corner, barrels at its inner end.
        mat = ["container_red", "container_blue", "container_green", "container_blue"][q]
        qbox(g, "Container", q, 8.0, 14.0, 0.0, 2.6, -21.5, -19.1, mat)
        qbox(d, "ContainerRibA", q, 7.95, 8.1, 0.05, 2.55, -21.55, -19.05, "trim", False)
        qbox(d, "ContainerRibB", q, 13.9, 14.05, 0.05, 2.55, -21.55, -19.05, "trim", False)
        qbox(d, "ContainerSnow", q, 8.1, 13.9, 2.6, 2.72, -21.4, -19.2, "snow", False)
        qcyl(g, "Barrel", q, 6.8, -18.6, 0.45, 0.0, 1.2, "barrel")
        qcyl(g, "BarrelB", q, 5.8, -19.6, 0.45, 0.0, 1.2, "barrel_blue")
        # Snow bank along the yard wall between spawns (knee-high, steps up).
        qbox(g, "SnowBank", q, -6.0, 6.0, 0.0, 0.35, -HALF, -HALF + 1.6, "snow")
        # Trodden path from the middle spawn to the plaza gap.
        qbox(d, "Path", q, -2.0, 2.0, 0.0, DECAL, -HALF + 1.6, -PLAZA - 0.5, "snow_path", False)
        # Buttresses along the yard wall (depth), a lamp over the middle spawn.
        for k, along in enumerate((-10.0, 10.0)):  # Clear of the nest ramps and step crates.
            qbox(g, f"Buttress{k}_", q, along - 0.45, along + 0.45, 0.0, WALL_H - 0.4, -HALF, -HALF + 0.35, "concrete")
        qbox(d, "WallLampArm", q, -0.15, 0.15, 4.2, 4.35, -HALF, -HALF + 0.8, "trim", False)
        qbox(d, "WallLampHead", q, -0.3, 0.3, 3.9, 4.2, -HALF + 0.5, -HALF + 1.0, "lamp", False)
        wx, wz = turn(0.0, -HALF + 1.5, q)
        m.lamp(d, f"WallLight{q}", wx, 3.8, wz, energy=1.2, reach=12.0)

        # Corner nest (north-west corner for quarter 0): plank deck, ramp along the north wall.
        qbox(g, "NestDeck", q, -HALF, -HALF + NEST, NEST_H - 0.4, NEST_H, -HALF, -HALF + NEST, "crate")
        qbox(g, "NestPost", q, -HALF + NEST - 0.6, -HALF + NEST, 0.0, NEST_H - 0.4, -HALF + NEST - 0.6, -HALF + NEST, "crate")
        qbox(g, "NestRail", q, -HALF + NEST - 0.2, -HALF + NEST, NEST_H, NEST_H + 1.0, -HALF + 2.0, -HALF + NEST, "crate")
        qbox(g, "NestRailFront", q, -HALF + 2.0, -HALF + NEST, NEST_H, NEST_H + 1.0, -HALF + NEST - 0.2, -HALF + NEST, "crate")
        # Tin roof over the nest on two posts at the open corner.
        qbox(g, "NestRoofPost", q, -HALF + NEST - 0.3, -HALF + NEST, NEST_H, NEST_ROOF_H, -HALF + NEST - 0.3, -HALF + NEST, "trim")
        qbox(g, "NestRoof", q, -HALF, -HALF + NEST + 0.4, NEST_ROOF_H, NEST_ROOF_H + 0.15, -HALF, -HALF + NEST + 0.4, "metal")
        # Second way up: crates 1 m and 2 m against the deck's south edge (two plain jumps).
        qbox(g, "NestStepHigh", q, -HALF, -HALF + 1.6, 0.0, 2.0, -HALF + NEST, -HALF + NEST + 1.6, "crate")
        qbox(g, "NestStepLow", q, -HALF + 1.6, -HALF + 3.2, 0.0, 1.0, -HALF + NEST + 1.6, -HALF + NEST + 3.2, "crate")
        # Ramp: from x = -HALF + NEST + 7 (ground) to the deck's east edge, along the north wall.
        qramp(g, "NestRamp", q, -HALF + NEST + 7.0, -HALF + NEST, -HALF, -HALF + 2.0, 0.0, NEST_H, "crate")

    # Spawns: 3 per side along the yard walls, facing the plaza.
    n = 1
    for q in range(4):
        for along in (-14.0, 0.0, 14.0):
            x, z = turn(along, -HALF + 3.0, q)
            m.marker("SpawnPoints", f"Spawn{n}", x, 0.1, z)
            n += 1

    # Pickups: health in two opposite mid lanes, speed in the other two, double jump in the plaza.
    for i, (q, kind) in enumerate([(0, "health"), (2, "health"), (1, "speed"), (3, "double_jump")]):
        x, z = turn(-1.0, -19.0, q)
        m.marker("Pickups", f"Pickup{i + 1}", x, 0.0, z, extra=kind)
    m.marker("Pickups", "Pickup5", 0.0, 0.0, 4.0, extra="health")

    # Airdrops: plaza (in front of the fountain) and two opposite open yard corners.
    m.marker("AirdropPoints", "Drop1", 0.0, 0.0, -4.0)
    x, z = turn(16.0, -20.0, 1)
    m.marker("AirdropPoints", "Drop2", x, 0.0, z)
    x, z = turn(16.0, -20.0, 3)
    m.marker("AirdropPoints", "Drop3", x, 0.0, z)

    backdrop()


def backdrop():
    """Outside the walls (unreachable): warehouses, a water tower, pines and snow banks."""
    b = "Geometry/Backdrop"
    for q in range(4):
        qbox(b, "Bank", q, -HALF - 12, HALF + 12, 0.0, 1.2, -HALF - 6, -HALF - 1, "snow", False)
    # Warehouses: two behind the north wall, one behind the south, one west (looming over the walls).
    for name, (x0, x1, z0, z1, h, mat) in {
            "WarehouseN1": (-24.0, -6.0, -HALF - 22.0, -HALF - 9.0, 11.0, "factory"),
            "WarehouseN2": (6.0, 20.0, -HALF - 18.0, -HALF - 8.0, 8.5, "metal"),
            "WarehouseS": (-10.0, 12.0, HALF + 9.0, HALF + 22.0, 10.0, "brick"),
            "WarehouseW": (-HALF - 20.0, -HALF - 9.0, 4.0, 20.0, 9.0, "factory")}.items():
        m.box(b, name, x0, x1, 0.0, h, z0, z1, mat, False)
        m.box(b, f"{name}Roof", x0 - 0.3, x1 + 0.3, h, h + 0.4, z0 - 0.3, z1 + 0.3, "snow", False)
    # Lit windows on the warehouse walls that face the yard.
    for k in range(4):
        x = -21.0 + k * 4.5
        m.box(b, f"WindowN{k}", x, x + 2.0, 6.5, 7.6, -HALF - 9.05, -HALF - 9.0, "window_lit", False)
        xs = -7.0 + k * 5.0
        m.box(b, f"WindowS{k}", xs, xs + 2.0, 6.0, 7.0, HALF + 9.0, HALF + 9.05, "window", False)
    # Water tower in the north-east.
    tx, tz = HALF + 12.0, -HALF - 10.0
    for k, (ox, oz) in enumerate([(-1.6, -1.6), (1.6, -1.6), (-1.6, 1.6), (1.6, 1.6)]):
        m.prop(b, f"TowerLeg{k}", tx + ox, tz + oz, 0.3, 12.0, 0.3, mat="trim", collide=False)
    m.cyl(b, "TowerTank", tx, tz, 2.8, 12.0, 16.0, "metal", collide=False, sides=12)
    m.cyl(b, "TowerTop", tx, tz, 3.0, 16.0, 17.6, "snow", collide=False, sides=12, cone=True)
    # Pines.
    for i in range(32):
        side = i % 4
        along = -HALF - 6 + (i // 4) * 9.0 + side * 2.3
        dist = HALF + 4.0 + (i * 7 % 6)
        x, z = turn(along, -dist, side)
        _pine(b, f"Pine{i}", x, z, 7.0 + (i * 3 % 5))


def _pine(parent, name, x, z, height):
    """Low-poly pine: trunk and three stacked cones."""
    m.cyl(parent, f"{name}Trunk", x, z, 0.25, 0.0, height * 0.3, "bark", collide=False, sides=6)
    for k, (share, radius) in enumerate([(0.22, 1.9), (0.45, 1.4), (0.66, 0.9)]):
        m.cyl(parent, f"{name}Leaves{k}", x, z, radius, height * share, height * (share + 0.38), "pine",
              collide=False, sides=7, cone=True)


ENVIRONMENT = """
[sub_resource type="ProceduralSkyMaterial" id="SkyMat"]
sky_top_color = Color(0.1, 0.13, 0.2, 1)
sky_horizon_color = Color(0.34, 0.36, 0.42, 1)
ground_bottom_color = Color(0.16, 0.17, 0.2, 1)
ground_horizon_color = Color(0.34, 0.36, 0.42, 1)

[sub_resource type="Sky" id="Sky"]
sky_material = SubResource("SkyMat")

[sub_resource type="Environment" id="Env"]
background_mode = 2
sky = SubResource("Sky")
ambient_light_source = 3
ambient_light_energy = 0.42
tonemap_mode = 2
fog_enabled = true
fog_light_color = Color(0.3, 0.33, 0.4, 1)
fog_density = 0.011
fog_sky_affect = 0.4
"""

SUN = """
[node name="Sun" type="DirectionalLight3D" parent="."]
rotation = Vector3(-0.7, 0.9, 0)
position = Vector3(0, 30, 0)
light_color = Color(0.86, 0.88, 1, 1)
light_energy = 0.5
shadow_enabled = true
"""


if __name__ == "__main__":
    build()
    m.write(OUT, "IceYard", ENVIRONMENT, SUN)
    if "--preview" in sys.argv:
        m.preview(os.path.join(sys.argv[sys.argv.index("--preview") + 1], "ice_yard.png"), HALF * SCALE + 2)
    print(f"wrote {os.path.relpath(OUT, ROOT)}: {len(m.nodes)} nodes, {len(m.markers)} markers")
