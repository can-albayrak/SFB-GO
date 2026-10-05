"""Builds the Train Factory map scene around the converted CS Online map dm_trainfactory.

    python tools/maps/import_goldsrc_bsp.py dm_trainfactory.bsp WAD_DIR \\
        scenes/maps/train_factory/train_factory.glb scenes/maps/train_factory/lightmap.png \\
        --info tools/maps/train_factory_info.json
    python tools/maps/build_train_factory.py

The BSP and WADs are not in the repo (private_assets/, Nexon's map); the converted glb,
lightmap and info JSON are. Writes scenes/maps/train_factory/train_factory.tscn:
- Geometry: the glb (mesh + "-colonly" trimesh collision) under GoldSrcMap (lightmap shader).
- Ladders: Area3D boxes on the ladder layer (7) from the map's func_ladder brushes, a little
  thicker and taller so the capsule touches them and steps off at the top.
- SpawnPoints / Pickups / AirdropPoints below, for free-for-all: the original map only has two
  team spawn rooms, so spawns are spread over the hall in mirrored pairs (the map is the same
  turned 180 degrees). Floor heights come from a probe of the collision mesh.
The trains and their doors stay still (the doors shut); exploding barrels are left out.
"""

import json
import math
import os

ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "scenes", "maps", "train_factory", "train_factory.tscn")
INFO = os.path.join(os.path.dirname(__file__), "train_factory_info.json")

MAIN = 1.63  # Hall floor.
TRACK = 0.41  # Floor between the platforms, by the tracks.
LADDER_PAD = 0.2  # Metres added on each side of the thin ladder brushes.
LADDER_TOP = 0.15  # Metres added above the top, to step off.

# (x, z, floor y); each one is mirrored to (-x, -z).
SPAWNS = [(-32, 16, MAIN), (-15, 13, MAIN), (0, -20, MAIN), (-4, 3, MAIN), (10, -15, MAIN),
          (-15, -9, MAIN), (-27, -20, MAIN), (-29, -3, MAIN)]
PICKUPS = [(-3, -15, MAIN, "health"), (-18, 5, TRACK, "double_jump"), (-12, -18, MAIN, "speed")]
DROPS = [(-10, 8, MAIN), (4, 18, MAIN)]


def vec(v):
    return "Vector3(%s, %s, %s)" % tuple(("%.4g" % c) for c in v)


def main():
    info = json.load(open(INFO))
    lines = ['[gd_scene format=3]', '',
             '[ext_resource type="Script" path="res://scripts/maps/goldsrc_map.gd" id="1_goldsrc"]',
             '[ext_resource type="PackedScene" path="res://scenes/maps/train_factory/train_factory.glb" id="2_glb"]',
             '[ext_resource type="Texture2D" path="res://scenes/maps/train_factory/lightmap.png" id="3_lightmap"]',
             '[ext_resource type="PackedScene" path="res://scenes/pickups/pickup.tscn" id="4_pickup"]',
             '[ext_resource type="Resource" path="res://data/pickups/health.tres" id="5_health"]',
             '[ext_resource type="Resource" path="res://data/pickups/speed.tres" id="6_speed"]',
             '[ext_resource type="Resource" path="res://data/pickups/double_jump.tres" id="7_double_jump"]', '',
             '[sub_resource type="ProceduralSkyMaterial" id="SkyMat"]',
             'sky_top_color = Color(0.32, 0.4, 0.52, 1)',
             'sky_horizon_color = Color(0.55, 0.58, 0.62, 1)',
             'ground_bottom_color = Color(0.2, 0.2, 0.22, 1)',
             'ground_horizon_color = Color(0.55, 0.58, 0.62, 1)', '',
             '[sub_resource type="Sky" id="Sky"]', 'sky_material = SubResource("SkyMat")', '',
             '[sub_resource type="Environment" id="Env"]',
             'background_mode = 2', 'sky = SubResource("Sky")',
             'ambient_light_source = 2', 'ambient_light_color = Color(0.62, 0.63, 0.66, 1)',
             'ambient_light_energy = 0.55', 'tonemap_mode = 2',
             'fog_enabled = true', 'fog_light_color = Color(0.25, 0.26, 0.28, 1)', 'fog_density = 0.006',
             'fog_sky_affect = 0.0', '']
    ladders = info["ladders"]
    for i, _ in enumerate(ladders):
        lines += ['[sub_resource type="BoxShape3D" id="Ladder%d"]' % i]
        lo, hi = ladders[i]["min"], ladders[i]["max"]
        size = [hi[0] - lo[0] + 2 * LADDER_PAD, hi[1] - lo[1] + LADDER_TOP, hi[2] - lo[2] + 2 * LADDER_PAD]
        lines += ['size = %s' % vec(size), '']

    lines += ['[node name="TrainFactory" type="Node3D"]', '',
              '[node name="WorldEnvironment" type="WorldEnvironment" parent="."]', 'environment = SubResource("Env")', '']
    sun = info["sun"]
    # light_environment: pitch below the horizon, yaw around GoldSrc Z (0 = +X, 90 = +Y = Godot -Z).
    lines += ['[node name="Sun" type="DirectionalLight3D" parent="."]',
              'rotation = %s' % vec((math.radians(sun["pitch"]), math.radians(sun["yaw"] - 90.0), 0.0)),
              'light_color = Color(1, 0.95, 0.86, 1)', 'light_energy = 0.45', '']
    lines += ['[node name="Geometry" type="Node3D" parent="."]', 'script = ExtResource("1_goldsrc")',
              'lightmap = ExtResource("3_lightmap")', '',
              '[node name="Hall" parent="Geometry" instance=ExtResource("2_glb")]', '',
              '[node name="Ladders" type="Node3D" parent="."]', '']
    for i, ladder in enumerate(ladders):
        lo, hi = ladder["min"], ladder["max"]
        centre = [(lo[0] + hi[0]) / 2, (lo[1] + hi[1] + LADDER_TOP) / 2, (lo[2] + hi[2]) / 2]
        lines += ['[node name="Ladder%d" type="Area3D" parent="Ladders"]' % (i + 1), 'position = %s' % vec(centre),
                  'collision_layer = 64', 'collision_mask = 0', 'monitoring = false', '',
                  '[node name="Shape" type="CollisionShape3D" parent="Ladders/Ladder%d"]' % (i + 1),
                  'shape = SubResource("Ladder%d")' % i, '']

    def mirrored(points):
        out = []
        for p in points:
            out.append(p)
            out.append((-p[0], -p[1]) + tuple(p[2:]))
        return out

    lines += ['[node name="SpawnPoints" type="Node3D" parent="."]', '']
    for i, (x, z, y) in enumerate(mirrored(SPAWNS)):
        yaw = math.atan2(x, z)  # Face the middle of the hall: forward (-Z) turned toward -position.
        lines += ['[node name="Spawn%d" type="Marker3D" parent="SpawnPoints"]' % (i + 1),
                  'position = %s' % vec((x, y + 0.1, z)), 'rotation = %s' % vec((0, yaw, 0)), '']
    lines += ['[node name="Pickups" type="Node3D" parent="."]', '']
    ids = {"health": "5_health", "speed": "6_speed", "double_jump": "7_double_jump"}
    for i, (x, z, y, kind) in enumerate(mirrored(PICKUPS)):
        lines += ['[node name="Pickup%d" parent="Pickups" instance=ExtResource("4_pickup")]' % (i + 1),
                  'position = %s' % vec((x, y, z)), 'def = ExtResource("%s")' % ids[kind], '']
    lines += ['[node name="AirdropPoints" type="Node3D" parent="."]', '']
    for i, (x, z, y) in enumerate(mirrored(DROPS)):
        lines += ['[node name="Drop%d" type="Marker3D" parent="AirdropPoints"]' % (i + 1), 'position = %s' % vec((x, y, z)), '']
    with open(OUT, "w") as f:
        f.write("\n".join(lines))
    print("wrote", OUT)


if __name__ == "__main__":
    main()
