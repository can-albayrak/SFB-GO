"""Writes the first-person grip markers and stance of every weapon view scene.

    python tools/apply_view_grips.py

For each scenes/weapons/<id>.tscn: "RightHand" / "LeftHand" Marker3D nodes (centre of the fist
in the weapon's own space; rotation = how the fist is turned, see FirstPersonArms) and the root's
"arms_twist" metadata (degrees the arms turn, left shoulder forward). The points were read off
side views of the processed models (scale grid, origin = the model's hand point).
Re-running replaces the old values; nodes the table leaves out are removed.
"""

import math
import os
import re

ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), ".."))
HANDGUARD = (-90.0, 0.0, 50.0)  # Support fist under a handguard, palm up.

# id -> (twist degrees, right grip, left grip or None); a grip is (x, y, z, rotation) with the
# rotation as Euler degrees (x, y, z) or a single roll about the barrel, or ("along", d) for a
# melee weapon: d model units along its handle axis (model -Z) from the model's origin. Melee fists
# take their rotation from the model (FirstPersonArms), so these markers only place them.
GRIPS = {
    "assault_rifle": (20.0, (0.0, -0.048, 0.056, 0.0), (0.0, 0.03, -0.22, HANDGUARD)),
    "burst_rifle": (18.0, (0.0, -0.047, -0.03, 0.0), (0.0, -0.05, -0.197, 0.0)),
    "lmg": (20.0, (0.0, -0.069, 0.037, 0.0), (0.0, -0.02, -0.17, HANDGUARD)),
    "heavy_rifle": (20.0, (0.0, -0.03, 0.08, 0.0), (0.0, 0.0, -0.17, HANDGUARD)),
    "marksman_rifle": (20.0, (0.0, -0.052, 0.12, 0.0), (0.0, -0.007, -0.18, HANDGUARD)),
    "shotgun": (22.0, (0.0, -0.03, 0.06, 0.0), (0.0, 0.013, -0.3, HANDGUARD)),
    "grenade_launcher": (22.0, (0.0, -0.08, 0.081, 0.0), (0.0, -0.09, -0.324, 0.0)),
    "musket": (20.0, (0.0, -0.019, 0.092, 0.0), (0.0, 0.03, -0.16, HANDGUARD)),
    "railgun": (12.0, (0.0, -0.074, 0.026, 0.0), (0.0, -0.097, -0.113, 0.0)),
    "minigun": (15.0, (0.0, -0.141, -0.024, 0.0), (0.0, -0.09, -0.18, HANDGUARD)),
    "rocket_launcher": (15.0, (0.0, -0.091, -0.052, 0.0), (0.0, -0.03, -0.286, HANDGUARD)),
    "smg": (12.0, (0.0, 0.0, -0.03, 0.0), (0.0, 0.045, -0.15, HANDGUARD)),
    "pistol": (0.0, (-0.015, -0.03, 0.026, 0.0), None),  # One-handed (WeaponDef.view_hands).
    "revolver": (0.0, (-0.015, -0.041, 0.053, 0.0), None),
    "sledgehammer": (10.0, ("along", 0.15), ("along", -0.09)),
    "chainsaw": (15.0, (0.0, -0.019, 0.037, 0.0), (0.0, 0.048, -0.074, 0.0)),
}


def f(v):
    return f"{round(v, 4):g}"


def apply(weapon_id, twist, right, left):
    path = os.path.join(ROOT, "scenes", "weapons", f"{weapon_id}.tscn")
    with open(path, encoding="utf-8") as fh:
        text = fh.read()
    # Drop old markers (a node block runs to the next blank line or node).
    text = re.sub(r'\n\[node name="(RightHand|LeftHand)" type="Marker3D" parent="\."\]\n(?:[^\[\n].*\n)*', "\n", text)
    text = re.sub(r'\nmetadata/arms_twist = [^\n]*', "", text)
    root_end = text.index("\n\n", text.index('[node name="'))
    text = text[:root_end] + f"\nmetadata/arms_twist = {f(twist)}" + text[root_end:]
    text = text.rstrip("\n") + "\n"
    for name, grip in (("RightHand", right), ("LeftHand", left)):
        if grip is None:
            continue
        if grip[0] == "along":
            grip = (*_along_handle(text, grip[1]), 0.0)
        x, y, z, rot = grip
        euler = rot if isinstance(rot, tuple) else (0.0, 0.0, rot)
        text += f'\n[node name="{name}" type="Marker3D" parent="."]\n'
        text += f"position = Vector3({f(x)}, {f(y)}, {f(z)})\n"
        if any(euler):
            text += "rotation = Vector3(%s)\n" % ", ".join(f(math.radians(a)) for a in euler)
    with open(path, "w", encoding="utf-8", newline="\n") as fh:
        fh.write(text)


def _along_handle(text, d):
    """Weapon-space point d model units along the Model node's -Z (Godot Euler order YXZ)."""
    block = text[text.index('[node name="Model"'):]
    block = block.split("\n\n")[0]
    rot = re.search(r"rotation = Vector3\(([^)]*)\)", block)
    scl = re.search(r"scale = Vector3\(([^)]*)\)", block)
    rx, ry, _rz = (float(v) for v in rot.group(1).split(",")) if rot else (0.0, 0.0, 0.0)
    scale = float(scl.group(1).split(",")[2]) if scl else 1.0
    # Column z of Ry * Rx * Rz (Rz turns about z itself, so it does not matter here).
    z_col = (math.sin(ry) * math.cos(rx), -math.sin(rx), math.cos(ry) * math.cos(rx))
    return tuple(-d * scale * c for c in z_col)


if __name__ == "__main__":
    for weapon_id, (twist, right, left) in GRIPS.items():
        apply(weapon_id, twist, right, left)
    print(f"wrote grips for {len(GRIPS)} weapons")
