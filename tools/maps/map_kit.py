"""Shared builder for the hand-made blockout maps (Ice Yard, Snow Town): boxes, cylinders,
ramps, lamps and markers, written as one Godot scene with CSG collision on layer 1.

Materials (MATERIALS) use the Poly Haven textures in assets/textures/env (CC0, 256 px,
tools/fetch_polyhaven_textures.py) with world-space triplanar UVs and nearest filtering (PS2
look); the ones without a texture use a soft noise grit. Axes: x east, z south, y up.
Every horizontal coordinate is multiplied by `scale` (heights are not), like the first Ice Yard.
"""

import math
import os

TEX_DIR = "res://assets/textures/env"

# name -> (texture id or None, tint RGB, metres per texture repeat, roughness, extra lines)
MATERIALS = {
    "snow": ("snow_02", (0.86, 0.89, 0.95), 3.0, 0.9, []),
    "snow_dirty": ("snow_floor", (0.78, 0.8, 0.86), 2.5, 0.9, []),
    "snow_path": ("asphalt_snow", (0.8, 0.82, 0.88), 2.5, 0.9, []),
    "cobble": ("cobblestone_floor_02", (0.72, 0.74, 0.8), 2.0, 0.9, []),
    "concrete": ("concrete_wall_001", (0.62, 0.65, 0.72), 3.0, 0.95, []),
    "factory": ("factory_wall", (0.55, 0.62, 0.62), 3.0, 0.9, []),
    "brick": ("brick_wall_02", (0.78, 0.74, 0.74), 2.0, 0.95, []),
    "brick_painted": ("painted_brick", (0.75, 0.8, 0.85), 2.0, 0.95, []),
    "planks": ("distressed_painted_planks", (0.85, 0.82, 0.78), 2.0, 0.9, []),
    "crate": ("brown_planks_03", (0.95, 0.85, 0.72), 1.2, 0.85, []),
    "door": ("rough_pine_door", (0.9, 0.85, 0.8), 2.2, 0.85, []),
    "container_red": ("container_side", (1.25, 0.36, 0.3), 2.5, 0.7, []),
    "container_blue": ("container_side", (0.32, 0.55, 1.1), 2.5, 0.7, []),
    "container_green": ("container_side", (0.75, 0.9, 0.75), 2.5, 0.7, []),
    "metal": ("corrugated_iron", (0.7, 0.72, 0.76), 2.0, 0.6, []),
    "roof": ("grey_roof_tiles", (0.78, 0.8, 0.86), 2.0, 0.9, []),
    "bark": ("bark_brown_02", (0.8, 0.75, 0.72), 1.5, 1.0, []),
    "ice": (None, (0.34, 0.54, 0.68), 1.6, 0.25, ["metallic_specular = 0.8"]),
    "trim": (None, (0.2, 0.22, 0.26), 2.0, 0.9, []),
    "pine": (None, (0.16, 0.3, 0.24), 2.0, 1.0, []),
    "barrel": (None, (0.62, 0.17, 0.12), 2.0, 0.7, []),
    "barrel_blue": (None, (0.16, 0.26, 0.5), 2.0, 0.7, []),
    "window": (None, (0.14, 0.18, 0.24), 2.0, 0.15, ["metallic_specular = 1.0"]),
    "lamp": (None, (1.0, 0.82, 0.55), 2.0, 0.5, ["emission_enabled = true", "emission = Color(1, 0.78, 0.45, 1)",
                                                 "emission_energy_multiplier = 2.5"]),
    "window_lit": (None, (0.9, 0.72, 0.42), 2.0, 0.5, ["emission_enabled = true", "emission = Color(1, 0.72, 0.38, 1)",
                                                       "emission_energy_multiplier = 1.4"]),
}

RAMP_TUCK = 0.3  # The low end runs on under the floor, so there is no lip.


def f(v):
    return f"{round(v, 4):g}"


class MapBuilder:
    def __init__(self, scale=1.0):
        self.scale = scale
        self.nodes = []  # (kind, name, parent, data)
        self.clips = []  # (name, center, size)
        self.markers = []  # (group, name, position, yaw, extra)
        self.groups = []  # parent paths in creation order
        self._names = set()

    # --- Geometry ----------------------------------------------------------------------

    def _group(self, parent):
        parts = parent.split("/")
        for i in range(1, len(parts) + 1):
            path = "/".join(parts[:i])
            if path not in self.groups:
                self.groups.append(path)

    def _add(self, kind, name, parent, data):
        key = (parent, name)
        assert key not in self._names, f"duplicate node {parent}/{name}"
        self._names.add(key)
        self._group(parent)
        self.nodes.append((kind, name, parent, data))

    def box(self, parent, name, x0, x1, y0, y1, z0, z1, mat, collide=True):
        s = self.scale
        x0, x1 = sorted((x0 * s, x1 * s))
        z0, z1 = sorted((z0 * s, z1 * s))
        y0, y1 = sorted((y0, y1))
        if x1 - x0 < 0.01 or y1 - y0 < 0.01 or z1 - z0 < 0.01:
            return
        self._add("box", name, parent, {
            "center": ((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2), "size": (x1 - x0, y1 - y0, z1 - z0),
            "mat": mat, "rot": None, "collide": collide})

    def prop(self, parent, name, x, z, sx, sy, sz, y=0.0, mat="crate", collide=True):
        self.box(parent, name, x - sx / 2, x + sx / 2, y, y + sy, z - sz / 2, z + sz / 2, mat, collide)

    def rotated_box(self, parent, name, x, y, z, sx, sy, sz, yaw_deg, mat, collide=True):
        """A box of size (sx, sy, sz) (metres, unscaled) whose bottom centre is at (x, y, z), turned about up."""
        self._add("box", name, parent, {
            "center": (x * self.scale, y + sy / 2, z * self.scale), "size": (sx, sy, sz), "mat": mat,
            "rot": (0.0, math.radians(yaw_deg), 0.0), "collide": collide})

    def tilted_box(self, parent, name, cx, cy, cz, sx, sy, sz, rot_deg, mat, collide=True):
        """A box centred at (cx, cy, cz) (x, z scaled) of size (sx, sy, sz) metres, rotated by Euler
        degrees (x, y, z) (gable roofs; the size is not scaled)."""
        self._add("box", name, parent, {
            "center": (cx * self.scale, cy, cz * self.scale), "size": (sx, sy, sz), "mat": mat,
            "rot": tuple(math.radians(a) for a in rot_deg), "collide": collide})

    def cyl(self, parent, name, x, z, radius, y0, y1, mat, collide=True, sides=12, cone=False):
        """Upright cylinder (or a cone, point up)."""
        self._add("cyl", name, parent, {
            "center": (x * self.scale, (y0 + y1) / 2, z * self.scale), "radius": radius, "height": y1 - y0,
            "mat": mat, "collide": collide, "sides": sides, "cone": cone})

    def ramp(self, parent, name, axis, a0, a1, w0, w1, y_low, y_high, mat="snow", thick=0.3):
        """Walkable ramp along `axis` from coordinate a0 (y_low) to a1 (y_high); a1 must be exactly
        the edge of the floor it reaches (flush top)."""
        s = self.scale
        a0, a1, w0, w1 = a0 * s, a1 * s, w0 * s, w1 * s
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
        self._add("box", name, parent, {"center": center, "size": size, "mat": mat, "rot": rot, "collide": True})

    def clip(self, name, x0, x1, y0, y1, z0, z1):
        """Invisible wall (grapples and bhop jumps stop at the map's edge)."""
        s = self.scale
        self.clips.append((name, ((x0 + x1) / 2 * s, (y0 + y1) / 2, (z0 + z1) / 2 * s),
                           (abs(x1 - x0) * s, abs(y1 - y0), abs(z1 - z0) * s)))

    def lamp(self, parent, name, x, y, z, color=(1.0, 0.78, 0.5), energy=1.6, reach=11.0, shadow=False):
        self._add("light", name, parent, {"pos": (x * self.scale, y, z * self.scale), "color": color,
                                          "energy": energy, "range": reach, "shadow": shadow})

    def marker(self, group, name, x, y, z, face=(0.0, 0.0), extra=None):
        s = self.scale
        x, z, face = x * s, z * s, (face[0] * s, face[1] * s)
        yaw = math.atan2(-(face[0] - x), -(face[1] - z))
        self.markers.append((group, name, (x, y, z), yaw, extra))

    # --- Output --------------------------------------------------------------------------

    def write(self, path, root_name, environment, sun):
        used = sorted({d["mat"] for kind, _n, _p, d in self.nodes if kind in ("box", "cyl")})
        textures = sorted({MATERIALS[m][0] for m in used if MATERIALS[m][0]})
        out = ["[gd_scene format=3]", "",
               '[ext_resource type="PackedScene" path="res://scenes/pickups/pickup.tscn" id="1_pickup"]',
               '[ext_resource type="Resource" path="res://data/pickups/health.tres" id="2_health"]',
               '[ext_resource type="Resource" path="res://data/pickups/speed.tres" id="3_speed"]',
               '[ext_resource type="Resource" path="res://data/pickups/double_jump.tres" id="4_double_jump"]']
        for tex in textures:
            out.append(f'[ext_resource type="Texture2D" path="{TEX_DIR}/{tex}.png" id="tex_{tex}"]')
        out.append("")
        out.append(environment.strip("\n"))
        out.append('''
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
noise = SubResource("GritNoise")''')
        for m in used:
            tex, tint, repeat, rough, extra = MATERIALS[m]
            out.append(f'\n[sub_resource type="StandardMaterial3D" id="Mat_{m}"]')
            out.append(f"albedo_color = Color({f(tint[0])}, {f(tint[1])}, {f(tint[2])}, 1)")
            out.append(f'albedo_texture = {"ExtResource" if tex else "SubResource"}("{("tex_" + tex) if tex else "GritTexture"}")')
            out.append(f"roughness = {f(rough)}")
            uv = 1.0 / repeat
            out.append(f"uv1_scale = Vector3({f(uv)}, {f(uv)}, {f(uv)})")
            out.append("uv1_triplanar = true")
            out.append("uv1_world_triplanar = true")
            out.append("texture_filter = 2")
            out.extend(extra)
        for name, _c, sz in self.clips:
            out.append(f'\n[sub_resource type="BoxShape3D" id="Shape_{name}"]')
            out.append(f"size = Vector3({f(sz[0])}, {f(sz[1])}, {f(sz[2])})")
        out.append(f'\n[node name="{root_name}" type="Node3D"]')
        out.append('\n[node name="WorldEnvironment" type="WorldEnvironment" parent="."]')
        out.append('environment = SubResource("Env")')
        out.append(sun.strip("\n"))
        for group_path in self.groups:
            parent, _, leaf = group_path.rpartition("/")
            out.append(f'\n[node name="{leaf}" type="Node3D" parent="{parent or "."}"]')
        for kind, name, parent, d in self.nodes:
            if kind == "light":
                p, c = d["pos"], d["color"]
                out.append(f'\n[node name="{name}" type="OmniLight3D" parent="{parent}"]')
                out.append(f"position = Vector3({f(p[0])}, {f(p[1])}, {f(p[2])})")
                out.append(f"light_color = Color({f(c[0])}, {f(c[1])}, {f(c[2])}, 1)")
                out.append(f"light_energy = {f(d['energy'])}")
                out.append(f"omni_range = {f(d['range'])}")
                if d["shadow"]:
                    out.append("shadow_enabled = true")
                continue
            c = d["center"]
            if kind == "box":
                out.append(f'\n[node name="{name}" type="CSGBox3D" parent="{parent}"]')
            else:
                out.append(f'\n[node name="{name}" type="CSGCylinder3D" parent="{parent}"]')
            out.append(f"position = Vector3({f(c[0])}, {f(c[1])}, {f(c[2])})")
            if d.get("rot") is not None:
                r = d["rot"]
                out.append(f"rotation = Vector3({f(r[0])}, {f(r[1])}, {f(r[2])})")
            if d["collide"]:
                out.append("use_collision = true")
            if kind == "box":
                s = d["size"]
                out.append(f"size = Vector3({f(s[0])}, {f(s[1])}, {f(s[2])})")
            else:
                out.append(f"radius = {f(d['radius'])}")
                out.append(f"height = {f(d['height'])}")
                out.append(f"sides = {d['sides']}")
                if d["cone"]:
                    out.append("cone = true")
            out.append(f'material = SubResource("Mat_{d["mat"]}")')
        out.append('\n[node name="Clips" type="Node3D" parent="Geometry"]')
        for name, c, _sz in self.clips:
            out.append(f'\n[node name="{name}" type="StaticBody3D" parent="Geometry/Clips"]')
            out.append(f"position = Vector3({f(c[0])}, {f(c[1])}, {f(c[2])})")
            out.append(f'\n[node name="Shape" type="CollisionShape3D" parent="Geometry/Clips/{name}"]')
            out.append(f'shape = SubResource("Shape_{name}")')
        defs = {"health": "2_health", "speed": "3_speed", "double_jump": "4_double_jump"}
        for group in ["SpawnPoints", "Pickups", "AirdropPoints"]:
            out.append(f'\n[node name="{group}" type="Node3D" parent="."]')
            for g, name, p, yaw, extra in self.markers:
                if g != group:
                    continue
                if group == "Pickups":
                    out.append(f'\n[node name="{name}" parent="Pickups" instance=ExtResource("1_pickup")]')
                    out.append(f"position = Vector3({f(p[0])}, {f(p[1])}, {f(p[2])})")
                    out.append(f'def = ExtResource("{defs[extra]}")')
                else:
                    out.append(f'\n[node name="{name}" type="Marker3D" parent="{group}"]')
                    out.append(f"position = Vector3({f(p[0])}, {f(p[1])}, {f(p[2])})")
                    if group == "SpawnPoints":
                        out.append(f"rotation = Vector3(0, {f(yaw)}, 0)")
        os.makedirs(os.path.dirname(path), exist_ok=True)
        text = "\n".join(line for line in out if line != "")
        # Blank line before every [section] (Godot's own layout).
        text = text.replace("\n[", "\n\n[")
        with open(path, "w", encoding="utf-8", newline="\n") as fh:
            fh.write(text.rstrip("\n") + "\n")

    def preview(self, path, half):
        """Top-down PNG (Pillow): low cover yellow, tall white, ramps blue, markers coloured."""
        from PIL import Image, ImageDraw

        px_per_m = 10
        lo, size = -half - 2, int(2 * half + 4)
        img = Image.new("RGB", (size * px_per_m, size * px_per_m), (20, 20, 24))
        d = ImageDraw.Draw(img)

        def px(x, z):
            return ((x - lo) * px_per_m, (z - lo) * px_per_m)

        for kind, name, parent, data in self.nodes:
            if kind == "light" or "Backdrop" in parent or name.startswith("Ground") or not data["collide"]:
                continue
            c = data["center"]
            if kind == "cyl":
                r = data["radius"]
                d.ellipse([px(c[0] - r, c[2] - r), px(c[0] + r, c[2] + r)], fill=(200, 140, 90))
                continue
            s, rot = data["size"], data["rot"]
            top = c[1] + s[1] / 2
            color = (70, 120, 200) if rot is not None and rot[1] == 0 else (200, 170, 60) if top < 1.3 else (220, 220, 220)
            hx, hz = s[0] / 2, s[2] / 2
            if rot is not None and rot[1] == 0:
                hx = s[0] / 2 * abs(math.cos(rot[2])) if rot[2] else hx
                hz = s[2] / 2 * abs(math.cos(rot[0])) if rot[0] else hz
            elif rot is not None:
                ext = max(hx, hz)
                hx = hz = ext
            d.rectangle([px(c[0] - hx, c[2] - hz), px(c[0] + hx, c[2] + hz)], fill=color)
        for g, name, p, _yaw, _extra in self.markers:
            color = {"SpawnPoints": (60, 220, 90), "Pickups": (90, 200, 255), "AirdropPoints": (255, 80, 80)}[g]
            x, y = px(p[0], p[2])
            d.ellipse([x - 6, y - 6, x + 6, y + 6], fill=color)
            d.text((x + 7, y - 6), name, fill=color)
        os.makedirs(os.path.dirname(path), exist_ok=True)
        img.save(path)


def turn(x, z, quarter):
    """Point (x, z) turned by quarter * 90 degrees about the centre."""
    for _ in range(quarter % 4):
        x, z = -z, x
    return x, z
