"""Builds the Ice Yard map: a bigger take on CS 1.6's fy_iceworld, low-poly PSX snow look.

    python tools/maps/build_iceworld.py [--preview DIR]

Writes scenes/maps/ice_yard/ice_yard.tscn: CSG boxes with collision (layer 1), SpawnPoints,
Pickups and AirdropPoints. Edit the layout here and re-run (it overwrites the scene).
--preview DIR draws a top-down PNG (needs Pillow).

Axes: x east, z south (north = -z), y up. Walled yard 67 x 67 m: the layout below is written
for 56 x 56 m (x, z -28..28) and every horizontal coordinate is scaled by SCALE (heights are
not), so all contacts and ramps stay flush. Overcast late-afternoon light, open sky.
Four-way rotational symmetry (every quarter is the previous one turned 90 degrees), so no
side is better in free-for-all:
- Centre: ice plaza 14 x 14 behind 3.5 m ice walls with a 4 m gap in every side; an ice pillar
  in the middle, low crates around it.
- Mid ring: in every quarter a long ice wall (2.5 m) and crate stacks (1 / 2 m, jumpable) as
  cover between the plaza and the yard walls.
- Corners: 3 m snow-covered sniper nests, each with a ramp along the yard wall and a crate
  step on the other side.
- Spawns along the yard walls (3 per side), facing the plaza. Pine trees and snow banks
  outside the walls are backdrop only; invisible walls stop grapples and bhop jumps there.
"""

import math
import os
import sys

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
CLIP_H = 60.0  # Invisible walls over the yard walls: higher than any grapple reaches.

boxes = []  # (name, parent, center, size, material, rotation)
clips = []  # (name, center, size)
markers = []  # (group, name, position, yaw, extra)


def add_box(parent, name, x0, x1, y0, y1, z0, z1, mat="Mat_wall"):
    x0, x1 = sorted((x0 * SCALE, x1 * SCALE))
    z0, z1 = z0 * SCALE, z1 * SCALE
    y0, y1 = sorted((y0, y1))
    z0, z1 = sorted((z0, z1))
    if x1 - x0 < 0.01 or y1 - y0 < 0.01 or z1 - z0 < 0.01:
        return
    boxes.append((name, parent, ((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2), (x1 - x0, y1 - y0, z1 - z0), mat, None))


def prop(parent, name, x, z, sx, sy, sz, y=0.0, mat="Mat_crate"):
    add_box(parent, name, x - sx / 2, x + sx / 2, y, y + sy, z - sz / 2, z + sz / 2, mat)


RAMP_TUCK = 0.3  # The low end runs on under the floor, so there is no lip.


def ramp(parent, name, axis, a0, a1, w0, w1, y_low, y_high, thick=0.3, mat="Mat_snow"):
    """Walkable ramp along `axis` from coordinate a0 (y_low) to a1 (y_high); a1 must be exactly
    the edge of the floor it reaches (flush top, see build_mall_blockout.py)."""
    a0, a1, w0, w1 = a0 * SCALE, a1 * SCALE, w0 * SCALE, w1 * SCALE
    run, rise = a1 - a0, y_high - y_low
    slope = math.hypot(run, rise)
    a0 -= RAMP_TUCK * run / slope
    y_low -= RAMP_TUCK * rise / slope
    run, rise = a1 - a0, y_high - y_low
    length = math.hypot(run, rise)
    mid_a, mid_y, mid_w = (a0 + a1) / 2, (y_low + y_high) / 2, (w0 + w1) / 2
    if axis == "z":
        angle = math.atan2(-rise, run)
        if math.cos(angle) < 0:
            angle += math.pi
        normal = (0.0, math.cos(angle), math.sin(angle))
        center = (mid_w - normal[0] * thick / 2, mid_y - normal[1] * thick / 2, mid_a - normal[2] * thick / 2)
        size = (abs(w1 - w0), thick, length)
        rot = (angle, 0.0, 0.0)
    else:
        angle = math.atan2(rise, run)
        if math.cos(angle) < 0:
            angle += math.pi
        normal = (-math.sin(angle), math.cos(angle), 0.0)
        center = (mid_a - normal[0] * thick / 2, mid_y - normal[1] * thick / 2, mid_w - normal[2] * thick / 2)
        size = (length, thick, abs(w1 - w0))
        rot = (0.0, 0.0, angle)
    boxes.append((name, parent, center, size, mat, rot))


def marker(group, name, x, y, z, face=(0.0, 0.0), extra=None):
    x, z, face = x * SCALE, z * SCALE, (face[0] * SCALE, face[1] * SCALE)
    yaw = math.atan2(-(face[0] - x), -(face[1] - z))
    markers.append((group, name, (x, y, z), yaw, extra))


def turn(x, z, quarter):
    """Point (x, z) turned by quarter * 90 degrees about the centre."""
    for _ in range(quarter % 4):
        x, z = -z, x
    return x, z


def quarter_box(parent, name, quarter, x0, x1, y0, y1, z0, z1, mat):
    """A box given for quarter 0, turned into `quarter`."""
    ax, az = turn(x0, z0, quarter)
    bx, bz = turn(x1, z1, quarter)
    add_box(parent, f"{name}{quarter}", ax, bx, y0, y1, az, bz, mat)


def build():
    g = "Geometry/Yard"
    # Ground: one slab under everything (outside strip included, for the backdrop).
    add_box(g, "Ground", -HALF - 14, HALF + 14, -1.0, 0.0, -HALF - 14, HALF + 14, "Mat_snow")

    # Yard walls with a darker cap; the clip walls above stop grapples and bhop jumps.
    for i, (x0, x1, z0, z1) in enumerate([
            (-HALF - WALL_T, HALF + WALL_T, -HALF - WALL_T, -HALF), (-HALF - WALL_T, HALF + WALL_T, HALF, HALF + WALL_T),
            (-HALF - WALL_T, -HALF, -HALF, HALF), (HALF, HALF + WALL_T, -HALF, HALF)]):
        add_box(g, f"YardWall{i}", x0, x1, 0.0, WALL_H, z0, z1, "Mat_wall")
        add_box(g, f"YardWallCap{i}", x0 - 0.15, x1 + 0.15, WALL_H, WALL_H + 0.3, z0 - 0.15, z1 + 0.15, "Mat_trim")
        cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
        clips.append((f"Clip{i}", (cx * SCALE, WALL_H + CLIP_H / 2, cz * SCALE), ((x1 - x0) * SCALE, CLIP_H, (z1 - z0) * SCALE)))

    # Plaza: ice walls, a gap in the middle of every side, pillar and crates inside.
    for q in range(4):
        # Side running along x at z = -PLAZA (north side for quarter 0), split by the gap.
        quarter_box(g, "PlazaWallA", q, -PLAZA, -PLAZA_GAP, 0.0, PLAZA_WALL_H, -PLAZA - 0.5, -PLAZA + 0.5, "Mat_ice")
        quarter_box(g, "PlazaWallB", q, PLAZA_GAP, PLAZA + 0.5, 0.0, PLAZA_WALL_H, -PLAZA - 0.5, -PLAZA + 0.5, "Mat_ice")
        # Low crate inside each plaza corner (jump spot, peeks over the walls' gaps).
        quarter_box(g, "PlazaCrate", q, 3.0, 4.6, 0.0, 1.0, -4.6, -3.0, "Mat_crate")
    add_box(g, "Pillar", -1.2, 1.2, 0.0, 5.0, -1.2, 1.2, "Mat_ice")
    add_box(g, "PillarCap", -1.5, 1.5, 5.0, 5.4, -1.5, 1.5, "Mat_trim")

    for q in range(4):
        # Mid ring: a long ice wall across the lane, offset so lanes stay open on one side.
        quarter_box(g, "MidWall", q, -12.0, -3.0, 0.0, 2.5, -15.6, -14.8, "Mat_ice")
        # Crate stack next to it: 1 m, then 2 m behind (jump up, look over the mid wall).
        quarter_box(g, "CrateLow", q, 4.0, 5.6, 0.0, 1.0, -14.0, -12.4, "Mat_crate")
        quarter_box(g, "CrateHigh", q, 5.6, 7.6, 0.0, 2.0, -14.4, -12.4, "Mat_crate")
        # Lone crates in the open yard (half cover).
        quarter_box(g, "CrateYard", q, -20.0, -18.4, 0.0, 1.0, -9.0, -7.4, "Mat_crate")
        quarter_box(g, "Barrel", q, 12.0, 12.9, 0.0, 1.2, -21.0, -20.1, "Mat_barrel")
        # Snow bank along the yard wall between spawns (knee-high, steps up).
        quarter_box(g, "SnowBank", q, -6.0, 6.0, 0.0, 0.35, -HALF, -HALF + 1.6, "Mat_snow")

        # Corner nest (north-west corner for quarter 0): 3 m deck, ramp along the north wall.
        quarter_box(g, "NestDeck", q, -HALF, -HALF + NEST, NEST_H - 0.4, NEST_H, -HALF, -HALF + NEST, "Mat_snow")
        quarter_box(g, "NestPost", q, -HALF + NEST - 0.6, -HALF + NEST, 0.0, NEST_H - 0.4, -HALF + NEST - 0.6, -HALF + NEST, "Mat_wall")
        quarter_box(g, "NestRail", q, -HALF + NEST - 0.2, -HALF + NEST, NEST_H, NEST_H + 1.0, -HALF + 2.0, -HALF + NEST, "Mat_trim")
        quarter_box(g, "NestRailFront", q, -HALF + 2.0, -HALF + NEST, NEST_H, NEST_H + 1.0, -HALF + NEST - 0.2, -HALF + NEST, "Mat_trim")
        # Second way up: crates 1 m and 2 m against the deck's south edge (two plain jumps).
        quarter_box(g, "NestStepHigh", q, -HALF, -HALF + 1.6, 0.0, 2.0, -HALF + NEST, -HALF + NEST + 1.6, "Mat_crate")
        quarter_box(g, "NestStepLow", q, -HALF + 1.6, -HALF + 3.2, 0.0, 1.0, -HALF + NEST + 1.6, -HALF + NEST + 3.2, "Mat_crate")
        # Ramp: from x = -HALF + NEST + 7 (ground) to the deck's east edge, along the north wall.
        x_low, x_high = -HALF + NEST + 7.0, -HALF + NEST
        _quarter_ramp(g, "NestRamp", q, x_low, x_high, -HALF, -HALF + 2.0, 0.0, NEST_H)

    # Spawns: 3 per side along the yard walls, facing the plaza.
    n = 1
    for q in range(4):
        for along in (-14.0, 0.0, 14.0):
            x, z = turn(along, -HALF + 3.0, q)
            marker("SpawnPoints", f"Spawn{n}", x, 0.1, z)
            n += 1

    # Pickups: health in two opposite mid lanes, speed in the other two, double jump in the plaza.
    for i, (q, kind) in enumerate([(0, "health"), (2, "health"), (1, "speed"), (3, "double_jump")]):
        x, z = turn(-1.0, -19.0, q)
        marker("Pickups", f"Pickup{i + 1}", x, 0.0, z, extra=kind)
    marker("Pickups", "Pickup5", 0.0, 0.0, 4.0, extra="health")

    # Airdrops: plaza (in front of the pillar) and two opposite open yard corners.
    marker("AirdropPoints", "Drop1", 0.0, 0.0, -4.0)
    x, z = turn(16.0, -20.0, 1)
    marker("AirdropPoints", "Drop2", x, 0.0, z)
    x, z = turn(16.0, -20.0, 3)
    marker("AirdropPoints", "Drop3", x, 0.0, z)

    # Backdrop outside the walls: pines and snow banks (unreachable).
    b = "Geometry/Backdrop"
    for i in range(28):
        side = i % 4
        along = -HALF - 6 + (i // 4) * 10.5 + (side * 2.3)
        dist = HALF + 5.0 + (i * 7 % 5)
        x, z = turn(along, -dist, side)
        _pine(b, f"Pine{i}", x, z, 6.0 + (i * 3 % 4))
    for q in range(4):
        quarter_box(b, "Bank", q, -HALF - 10, HALF + 10, 0.0, 1.2, -HALF - 12, -HALF - 3, "Mat_snow")


def _quarter_ramp(parent, name, q, x_low, x_high, z0, z1, y_low, y_high):
    """A ramp given for quarter 0 (rising along x), turned into `q`."""
    if q == 0:
        ramp(parent, f"{name}{q}", "x", x_low, x_high, z0, z1, y_low, y_high)
    elif q == 1:  # (x, z) -> (-z, x): runs along z.
        ramp(parent, f"{name}{q}", "z", x_low, x_high, -z1, -z0, y_low, y_high)
    elif q == 2:  # (x, z) -> (-x, -z)
        ramp(parent, f"{name}{q}", "x", -x_low, -x_high, -z1, -z0, y_low, y_high)
    else:  # (x, z) -> (z, -x)
        ramp(parent, f"{name}{q}", "z", -x_low, -x_high, z0, z1, y_low, y_high)


def _pine(parent, name, x, z, height):
    """Low-poly pine: trunk and three shrinking boxes."""
    prop(parent, f"{name}Trunk", x, z, 0.5, height * 0.3, 0.5, mat="Mat_bark")
    for k, (share, width) in enumerate([(0.25, 3.2), (0.5, 2.3), (0.72, 1.3)]):
        prop(parent, f"{name}Leaves{k}", x, z, width, height * 0.3, width, y=height * share, mat="Mat_pine")


HEADER = """[gd_scene format=3]

[ext_resource type="PackedScene" path="res://scenes/pickups/pickup.tscn" id="1_pickup"]
[ext_resource type="Resource" path="res://data/pickups/health.tres" id="2_health"]
[ext_resource type="Resource" path="res://data/pickups/speed.tres" id="3_speed"]
[ext_resource type="Resource" path="res://data/pickups/double_jump.tres" id="4_double_jump"]

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

[sub_resource type="FastNoiseLite" id="GritNoise"]
noise_type = 5
frequency = 0.18
fractal_octaves = 3

[sub_resource type="Gradient" id="GritRamp"]
colors = PackedColorArray(0.78, 0.78, 0.78, 1, 1, 1, 1, 1)

[sub_resource type="NoiseTexture2D" id="GritTexture"]
width = 64
height = 64
seamless = true
color_ramp = SubResource("GritRamp")
noise = SubResource("GritNoise")

[sub_resource type="StandardMaterial3D" id="Mat_snow"]
albedo_color = Color(0.66, 0.7, 0.76, 1)
albedo_texture = SubResource("GritTexture")
roughness = 0.9
uv1_scale = Vector3(0.4, 0.4, 0.4)
uv1_triplanar = true
texture_filter = 0

[sub_resource type="StandardMaterial3D" id="Mat_ice"]
albedo_color = Color(0.34, 0.54, 0.68, 1)
albedo_texture = SubResource("GritTexture")
roughness = 0.25
metallic_specular = 0.8
uv1_scale = Vector3(0.6, 0.6, 0.6)
uv1_triplanar = true
texture_filter = 0

[sub_resource type="StandardMaterial3D" id="Mat_wall"]
albedo_color = Color(0.36, 0.39, 0.45, 1)
albedo_texture = SubResource("GritTexture")
roughness = 0.95
uv1_scale = Vector3(0.5, 0.5, 0.5)
uv1_triplanar = true
texture_filter = 0

[sub_resource type="StandardMaterial3D" id="Mat_trim"]
albedo_color = Color(0.2, 0.22, 0.26, 1)
roughness = 0.9

[sub_resource type="StandardMaterial3D" id="Mat_crate"]
albedo_color = Color(0.42, 0.3, 0.18, 1)
albedo_texture = SubResource("GritTexture")
roughness = 0.85
uv1_scale = Vector3(1.4, 1.4, 1.4)
uv1_triplanar = true
texture_filter = 0

[sub_resource type="StandardMaterial3D" id="Mat_barrel"]
albedo_color = Color(0.62, 0.17, 0.12, 1)
albedo_texture = SubResource("GritTexture")
roughness = 0.7
uv1_triplanar = true
texture_filter = 0

[sub_resource type="StandardMaterial3D" id="Mat_bark"]
albedo_color = Color(0.3, 0.21, 0.14, 1)
roughness = 1.0

[sub_resource type="StandardMaterial3D" id="Mat_pine"]
albedo_color = Color(0.16, 0.3, 0.24, 1)
albedo_texture = SubResource("GritTexture")
roughness = 1.0
uv1_triplanar = true
texture_filter = 0

[node name="IceYard" type="Node3D"]

[node name="WorldEnvironment" type="WorldEnvironment" parent="."]
environment = SubResource("Env")

[node name="Sun" type="DirectionalLight3D" parent="."]
rotation = Vector3(-0.7, 0.9, 0)
position = Vector3(0, 30, 0)
light_color = Color(0.86, 0.88, 1, 1)
light_energy = 0.5
shadow_enabled = true

[node name="Geometry" type="Node3D" parent="."]

[node name="Yard" type="Node3D" parent="Geometry"]

[node name="Backdrop" type="Node3D" parent="Geometry"]
"""

PICKUP_DEFS = {"health": "2_health", "speed": "3_speed", "double_jump": "4_double_jump"}


def f(v):
    return f"{round(v, 4):g}"


def write_scene():
    clip_subs = "".join(
        f'\n[sub_resource type="BoxShape3D" id="Shape_{name}"]\nsize = Vector3({f(sz[0])}, {f(sz[1])}, {f(sz[2])})\n'
        for name, c, sz in clips)
    out = [HEADER.replace('\n[node name="IceYard"', clip_subs + '\n[node name="IceYard"', 1)]
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

    scale = 10
    lo, size = -HALF * SCALE - 2, int(2 * HALF * SCALE + 4)
    img = Image.new("RGB", (size * scale, size * scale), (20, 20, 24))
    d = ImageDraw.Draw(img)

    def px(x, z):
        return ((x - lo) * scale, (z - lo) * scale)

    for name, parent, c, s, mat, rot in boxes:
        if parent.endswith("Backdrop") or name == "Ground":
            continue
        top = c[1] + s[1] / 2
        color = (70, 120, 200) if rot is not None else (200, 170, 60) if top < 1.3 else (220, 220, 220)
        hx = s[0] / 2 if rot is None or rot[2] == 0 else s[0] / 2 * abs(math.cos(rot[2]))
        hz = s[2] / 2 if rot is None or rot[0] == 0 else s[2] / 2 * abs(math.cos(rot[0]))
        d.rectangle([px(c[0] - hx, c[2] - hz), px(c[0] + hx, c[2] + hz)], fill=color)
    for g, name, p, yaw, extra in markers:
        color = {"SpawnPoints": (60, 220, 90), "Pickups": (90, 200, 255), "AirdropPoints": (255, 80, 80)}[g]
        x, y = px(p[0], p[2])
        d.ellipse([x - 6, y - 6, x + 6, y + 6], fill=color)
        d.text((x + 7, y - 6), name, fill=color)
    os.makedirs(folder, exist_ok=True)
    img.save(os.path.join(folder, "ice_yard.png"))


if __name__ == "__main__":
    build()
    write_scene()
    if "--preview" in sys.argv:
        write_preview(sys.argv[sys.argv.index("--preview") + 1])
    print(f"wrote {os.path.relpath(OUT, ROOT)}: {len(boxes)} boxes, {len(markers)} markers")
