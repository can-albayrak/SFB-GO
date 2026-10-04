"""Points the weapon scenes and WeaponDefs at the processed models in assets/models/weapons/real/.

    py tools/apply_weapon_models.py

Run after tools/blender/process_weapon_models.py (it writes real/muzzles.json). For every entry
below it rewrites the first-person scene (model path, view model scale, optional rotation,
removes placeholder parts, Muzzle marker from the model's muzzle) and the WeaponDef's third-person
model (world_model, world_model_scale 1, world_muzzle). Safe to re-run: it sets values, it does
not accumulate them.
"""

import json
import os
import re

ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), ".."))
REAL = "res://assets/models/weapons/real"

# scene -> model id, view model scale, rotation (None keeps the scene's), placeholder nodes to drop,
# whether the Muzzle marker follows the model (guns) or stays (melee). Every scale is multiplied
# by VIEW_SCALE (Can: "a bit small", 2026-10-02).
VIEW_SCALE = 1.2
SCENES = {
    "assault_rifle": ("assault_rifle", 0.78, None, (), True),
    "burst_rifle": ("burst_rifle", 0.65, None, (), True),
    "marksman_rifle": ("marksman_rifle", 0.6, None, (), True),
    "lmg": ("lmg", 0.63, None, (), True),
    "heavy_rifle": ("heavy_rifle", 0.6, None, (), True),
    "smg": ("smg", 1.0, None, (), True),
    "pistol": ("pistol", 0.9, None, (), True),
    "dual_pistols": ("dual_pistols", 0.8, None, (), True),
    "revolver": ("revolver", 0.8, None, (), True),
    "shotgun": ("shotgun", 0.68, None, (), True),
    "grenade_launcher": ("grenade_launcher", 0.7, None, ("Drum",), True),
    "railgun": ("railgun", 0.65, None, ("Coil",), True),
    "minigun": ("minigun", 0.75, None, ("Barrels",), True),
    "rocket_launcher": ("rocket_launcher", 0.65, None, ("Tube", "Grip"), True),
    "musket": ("musket", 0.55, None, (), True),
    "knife": ("knife", 0.85, None, (), False),
    "throwing_knife": ("throwing_knife", 0.75, None, (), False),
    "sledgehammer": ("sledgehammer", 0.5, None, (), False),
    "chainsaw": ("chainsaw", 0.55, (0.0, 0.0, 0.0), (), False),
}
# WeaponDef (data/weapons/<name>.tres) -> model id for the third-person model.
DEFS = {
    "assault_rifle": "assault_rifle", "burst_rifle": "burst_rifle", "marksman_rifle": "marksman_rifle",
    "lmg": "lmg", "heavy_rifle": "heavy_rifle", "smg": "smg", "pistol": "pistol",
    "dual_pistols": "dual_pistols", "revolver": "revolver", "shotgun": "shotgun",
    "grenade_launcher": "grenade_launcher", "railgun": "railgun", "minigun": "minigun",
    "rocket_launcher": "rocket_launcher", "musket": "musket", "throwing_knives": "throwing_knife",
    "sledgehammer": "sledgehammer", "chainsaw": "chainsaw", "knife": "knife",
}
# Other scenes that only swap the model file and scale (projectiles).
PROJECTILES = {
    "frag_grenade": ("frag_grenade", 1.0),
    "flashbang": ("flashbang", 1.0),
    "thrown_knife": ("throwing_knife", 1.35),
}


def vec(v):
    return "Vector3(%s)" % ", ".join(f"{round(x, 4):g}" for x in v)


def blocks(text):
    """Splits a .tscn/.tres into [header_lines..., block, block, ...] at lines starting with '['."""
    parts, current = [], []
    for line in text.split("\n"):
        if line.startswith("[") and current:
            parts.append(current)
            current = []
        current.append(line)
    parts.append(current)
    return parts


def set_prop(block, key, value):
    for i, line in enumerate(block):
        if line.startswith(key + " = "):
            block[i] = f"{key} = {value}"
            return
    insert = len(block)
    while insert > 1 and block[insert - 1] == "":
        insert -= 1
    block.insert(insert, f"{key} = {value}")


def drop_prop(block, key):
    block[:] = [line for line in block if not line.startswith(key + " = ")]


def node_name(block):
    m = re.match(r'\[node name="([^"]+)"', block[0])
    return m.group(1) if m else None


def get_vec(block, key, default):
    for line in block:
        if line.startswith(key + " = Vector3("):
            return [float(x) for x in line[len(key) + 11:-1].split(",")]
    return default


def model_ext(parts, model_id):
    """Points (or adds) the model ext_resource at the real model; returns its id."""
    path = f"{REAL}/{model_id}.glb"
    for block in parts:
        line = block[0]
        if line.startswith("[ext_resource") and 'type="PackedScene"' in line and "assets/models/" in line:
            block[0] = re.sub(r'path="[^"]+"', f'path="{path}"', line)
            block[0] = re.sub(r' uid="[^"]+"', "", block[0])
            return re.search(r'id="([^"]+)"', line).group(1)
    last_ext = max(i for i, b in enumerate(parts) if b[0].startswith("[ext_resource"))
    parts.insert(last_ext + 1, [f'[ext_resource type="PackedScene" path="{path}" id="9_real"]', ""])
    return "9_real"


def apply_scene(name, cfg, muzzles):
    model_id, scale, rotation, drop, follow_muzzle = cfg
    scale *= VIEW_SCALE
    path = os.path.join(ROOT, "scenes", "weapons", name + ".tscn")
    if not os.path.exists(path):
        src = os.path.join(ROOT, "scenes", "weapons", "burst_rifle.tscn")  # Same structure.
        text = open(src, encoding="utf-8").read().replace('[node name="BurstRifle"', '[node name="MarksmanRifle"')
    else:
        text = open(path, encoding="utf-8").read()
    parts = blocks(text)
    ext = model_ext(parts, model_id)
    parts = [b for b in parts if node_name(b) not in drop]
    models = [b for b in parts if b[0].startswith("[node") and "instance=ExtResource" in b[0]]
    if not models:  # Placeholder made of primitives: add one Model node before Muzzle.
        at = next(i for i, b in enumerate(parts) if node_name(b) == "Muzzle")
        parts.insert(at, [f'[node name="Model" parent="." instance=ExtResource("{ext}")]', ""])
        models = [parts[at]]
    muzzle = muzzles[model_id]["muzzle"]
    for block in models:
        set_prop(block, "scale", vec([scale] * 3))
        if rotation is not None:
            if rotation == (0.0, 0.0, 0.0):
                drop_prop(block, "rotation")
            else:
                set_prop(block, "rotation", vec(rotation))
    if follow_muzzle:
        for block in parts:
            if node_name(block) not in ("Muzzle", "LeftMuzzle"):
                continue
            # Each muzzle follows the model on its side (dual pistols); otherwise the only model.
            side = get_vec(block, "position", [0.0, 0.0, 0.0])[0]
            model = min(models, key=lambda b: abs(get_vec(b, "position", [0.0, 0.0, 0.0])[0] - side))
            origin = get_vec(model, "position", [0.0, 0.0, 0.0])
            set_prop(block, "position", vec([origin[i] + muzzle[i] * scale for i in range(3)]))
    parts = drop_unused_subresources(parts)
    with open(path, "w", encoding="utf-8", newline="\n") as fh:
        fh.write("\n".join(line for part in parts for line in part).rstrip("\n") + "\n")


def drop_unused_subresources(parts):
    """Removes sub_resources nothing references any more (the dropped placeholder meshes)."""
    while True:
        text = "\n".join(line for part in parts for line in part)
        unused = []
        for block in parts:
            m = re.match(r'\[sub_resource [^\]]*id="([^"]+)"', block[0])
            if m and text.count(f'SubResource("{m.group(1)}")') == 0:
                unused.append(block)
        if not unused:
            return parts
        parts = [b for b in parts if b not in unused]


def apply_def(name, model_id, muzzles):
    path = os.path.join(ROOT, "data", "weapons", name + ".tres")
    parts = blocks(open(path, encoding="utf-8").read())
    world_id = None
    for block in parts:
        if block[0].startswith("[resource]"):
            for line in block:
                m = re.match(r'world_model = ExtResource\("([^"]+)"\)', line)
                if m:
                    world_id = m.group(1)
    for block in parts:
        line = block[0]
        if world_id and line.startswith("[ext_resource") and f'id="{world_id}"' in line:
            block[0] = re.sub(r'path="[^"]+"', f'path="{REAL}/{model_id}.glb"', line)
            block[0] = re.sub(r' uid="[^"]+"', "", block[0])
        if line.startswith("[resource]"):
            set_prop(block, "world_model_scale", "1.0")
            set_prop(block, "world_muzzle", vec(muzzles[model_id]["muzzle"]))
            if name == "marksman_rifle":
                set_prop(block, "scene", 'ExtResource("2_scene")')
        if name == "marksman_rifle" and line.startswith("[ext_resource") and 'id="2_scene"' in line:
            block[0] = re.sub(r'path="[^"]+"', 'path="res://scenes/weapons/marksman_rifle.tscn"', line)
            block[0] = re.sub(r' uid="[^"]+"', "", block[0])
    with open(path, "w", encoding="utf-8", newline="\n") as fh:
        fh.write("\n".join(line for part in parts for line in part).rstrip("\n") + "\n")


def apply_projectile(name, cfg):
    model_id, scale = cfg
    path = os.path.join(ROOT, "scenes", "projectiles", name + ".tscn")
    parts = blocks(open(path, encoding="utf-8").read())
    model_ext(parts, model_id)
    for block in parts:
        if node_name(block) == "Model":
            set_prop(block, "scale", vec([scale] * 3))
    with open(path, "w", encoding="utf-8", newline="\n") as fh:
        fh.write("\n".join(line for part in parts for line in part).rstrip("\n") + "\n")


if __name__ == "__main__":
    with open(os.path.join(ROOT, "assets", "models", "weapons", "real", "muzzles.json"), encoding="utf-8") as fh:
        muzzle_data = json.load(fh)
    for scene_name, scene_cfg in SCENES.items():
        apply_scene(scene_name, scene_cfg, muzzle_data)
    for def_name, def_model in DEFS.items():
        apply_def(def_name, def_model, muzzle_data)
    for projectile_name, projectile_cfg in PROJECTILES.items():
        apply_projectile(projectile_name, projectile_cfg)
    print(f"applied {len(SCENES)} scenes, {len(DEFS)} weapon defs, {len(PROJECTILES)} projectiles")
