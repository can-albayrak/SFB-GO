"""Turns the downloaded weapon models (private_assets/weapons/: .glb, .blend, .obj, .fbx) into game-ready .glb files.

Run headless (does not touch any open Blender window):
    blender --background --factory-startup --python tools/blender/process_weapon_models.py -- <project_root> [ids...] [--preview DIR]
or with Blender as a Python module (pip install bpy; used in the cloud, no Blender install):
    python tools/blender/process_weapon_models.py -- <project_root> [ids...] [--preview DIR]

Output: assets/models/weapons/real/<id>.glb plus assets/models/weapons/real/muzzles.json
(muzzle / tip point of every model in Godot space, metres, for the weapon scenes).
Conventions match tools/blender/build_placeholders.py: Blender Z up, the weapon points along +Y
(Godot -Z after export), origin at the firing hand. Every model is joined into one mesh, scaled
to a real-world length, decimated when too dense, textures capped at MAX_TEXTURE px.
The raw files stay out of git (private_assets/); the processed .glb files are committed.
"""

import json
import math
import os
import sys

import bpy
from mathutils import Euler, Matrix, Vector

MAX_TEXTURE = 512
RAW_DIR = "private_assets/weapons"
OUT_DIR = "assets/models/weapons/real"

# Packs Can sent on 2026-10-02 (unzipped into private_assets/weapons/packs/).
PSX_PACK = "packs/PSX-Weapon-Pack/"
REVOLVER_PACK = "packs/PSXRevolverPack[FIXED]/Files/"
# Packs Can sent on 2026-10-06 (same folder).
PISTOL_PACK = "packs/PSXPistolPack[FIXED]/Files/"
SHOTGUN_PACK = "packs/PSXShotgunPack[FIXED]/Files/"
HEAVY_PACK = "packs/Heavy Weapons Pack/"

# id -> settings. "raw": file in RAW_DIR. "kind" sets the hand position (see HAND_SHARE).
# "length": metres along the long axis. Optional, all decided on the --preview renders:
#   "flip": the automatic axis guess pointed the muzzle backwards (turn 180 degrees about up),
#   "drop": parts whose name contains any of these are removed (spare shells, casings, ...),
#   "drop_exact": parts with exactly these names are removed (when one name is part of another),
#   "max_x": parts centred beyond this raw X are removed (a second, exploded copy),
#   "undo_euler": degrees (XYZ) the author left the whole model rotated by,
#   "axes": (forward, up) raw axes such as ("-x", "z") when the size-based guess is wrong,
#   "tint": RGB multiplier for the colour (darkens a too-light texture; colours an untextured model),
#   "opaque": True when the texture's alpha is not meant as see-through (new PSX revolver: drawn invisible),
#   "attach": (file, object) a part taken from another model, put on the front of this one's barrel
#             (USP-S: the pistol pack's suppressor).
MODELS = {
    "assault_rifle": {"raw": "packs/MachineGunPSX/GLB/MachineGunPSX.glb", "kind": "rifle", "length": 0.88},
    "burst_rifle": {"raw": "ps1-style_steyr_aug.glb", "kind": "rifle", "length": 0.79, "flip": True},
    "lmg": {"raw": "low-poly_m249_saw.glb", "kind": "rifle", "length": 1.0, "flip": True},
    "heavy_rifle": {"raw": PSX_PACK + "Remington-m700/Remington-m700.blend", "kind": "rifle", "length": 1.2},
    "marksman_rifle": {"raw": "svd.glb", "kind": "rifle", "length": 1.22},
    "smg": {"raw": PSX_PACK + "MAC-11/MAC-11.blend", "kind": "pistol", "length": 0.32},
    "dual_pistols": {"raw": PSX_PACK + "Glock-18/Glock-18.blend", "kind": "pistol", "length": 0.2},
    "pistol": {"raw": PISTOL_PACK + "Glock 17/Glock17.obj", "kind": "pistol", "length": 0.19,
               "drop_exact": ("9MM", "Supressor"), "drop": ("GlockMagazine",)},  # Spare mags beside it.
    "usp_s": {"raw": PISTOL_PACK + "USP/USP.obj", "kind": "pistol", "length": 0.33, "drop_exact": ("9MM",),
              "attach": (PISTOL_PACK + "Glock 17/Glock17.obj", "Supressor")},
    "shotgun": {"raw": PSX_PACK + "Remington-870/Remington-870.blend", "kind": "rifle", "length": 1.0,
                "drop": ("ShotgunBullet",)},
    "double_barrel": {"raw": SHOTGUN_PACK + "DoubleBarrelShotgun/DoubleBarrelShotgun.obj", "kind": "rifle",
                      "length": 1.05, "drop": ("Shell",)},
    "grenade_launcher": {"raw": HEAVY_PACK + "grenadelauncher.blend", "kind": "rifle", "length": 0.8, "flip": True},
    "railgun": {"raw": "ps1_style_railgun.glb", "kind": "rifle", "length": 1.1, "flip": True,
                "tint": (0.1, 0.11, 0.14)},  # Linear base colour (no texture): ~0.35 on screen.
    "minigun": {"raw": "low-poly_m134_minigun.glb", "kind": "rifle", "length": 1.0, "flip": True},
    "rocket_launcher": {"raw": HEAVY_PACK + "bazooka.blend", "kind": "rifle", "length": 1.1},
    "musket": {"raw": "hunting_rifle.glb", "kind": "rifle", "length": 1.3},
    "revolver": {"raw": "packs/PSXRevolverNew/PSX Revolver/Revolver.fbx", "kind": "pistol", "length": 0.3,
                 "opaque": True},
    "knife": {"raw": "combat_knife.glb", "kind": "melee", "length": 0.3},
    "throwing_knife": {"raw": "throwing_knife.glb", "kind": "melee", "length": 0.3, "flip": True},
    "sledgehammer": {"raw": "sledge_hammer.glb", "kind": "melee", "length": 0.9, "flip": True},
    "chainsaw": {"raw": "ps1_low-poly_chainsaw.glb", "kind": "melee", "length": 0.8, "axes": ("-x", "z")},
    "frag_grenade": {"raw": "grenade.glb", "kind": "throwable", "length": 0.11},
    "flashbang": {"raw": "flashbang.glb", "kind": "throwable", "length": 0.13},
}
MAX_TRIS = {"rifle": 2500, "pistol": 2500, "melee": 1500, "throwable": 900}

HAND_SHARE = {"rifle": (0.36, 0.6), "pistol": (0.3, 0.55), "melee": (0.15, 0.5), "throwable": (0.5, 0.5)}
INF = float("inf")
TIP_SLICE = 0.03  # Share of the length at the front used to find the muzzle height.


def reset() -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)


def load_raw(path: str) -> None:
    """Brings the raw model into the (empty) scene, whatever its format."""
    ext = os.path.splitext(path)[1].lower()
    if ext == ".blend":
        bpy.ops.wm.open_mainfile(filepath=path)
        if bpy.context.object is not None and bpy.context.object.mode != "OBJECT":
            bpy.ops.object.mode_set(mode="OBJECT")  # Saved while editing (Remington-870).
        relink_missing_images(os.path.dirname(path))
    elif ext == ".obj":
        bpy.ops.wm.obj_import(filepath=path)
        relink_missing_images(os.path.dirname(path))
    elif ext == ".fbx":
        bpy.ops.import_scene.fbx(filepath=path)
        relink_missing_images(os.path.dirname(path))
    else:
        bpy.ops.import_scene.gltf(filepath=path)


def relink_missing_images(folder: str) -> None:
    """Points images that failed to load at a file of the same name (any case) under `folder`
    (packs saved on Windows: "fn-fal_texture.png" is really "FN_FAL_texture.png")."""
    files = {}
    for base, _dirs, names in os.walk(folder):
        for name in names:
            files.setdefault(name.lower(), os.path.join(base, name))
    for image in bpy.data.images:
        if image.source != "FILE" or image.size[0] > 0:
            continue
        wanted = os.path.basename(bpy.path.abspath(image.filepath).replace("\\", "/")).lower()
        if wanted in files:
            image.filepath = files[wanted]
            image.reload()


def import_joined(path: str, drop: tuple, max_x: float, drop_exact: tuple = ()) -> bpy.types.Object:
    load_raw(path)
    meshes = []
    for o in [o for o in bpy.context.scene.objects if o.type == "MESH"]:
        centre = sum((o.matrix_world @ Vector(c) for c in o.bound_box), Vector()) / 8.0
        if any(part in o.name for part in drop) or o.name in drop_exact or centre.x > max_x:
            bpy.data.objects.remove(o, do_unlink=True)
        else:
            meshes.append(o)
    bpy.ops.object.select_all(action="DESELECT")
    for o in bpy.context.scene.objects:
        o.animation_data_clear()  # FBX keys (new PSX revolver) would re-scale the joined mesh.
    for o in meshes:
        o.hide_set(False)
        bpy.context.view_layer.objects.active = o
        for mod in list(o.modifiers):  # Mirror halves (Heavy Weapons Pack grenade launcher).
            bpy.ops.object.modifier_apply(modifier=mod.name)
    for o in meshes:
        o.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    if len(meshes) > 1:
        bpy.ops.object.join()
    obj = bpy.context.active_object
    world = obj.matrix_world.copy()
    obj.parent = None
    obj.matrix_world = world  # Keep the world placement after unparenting.
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    for o in list(bpy.context.scene.objects):
        if o != obj:
            bpy.data.objects.remove(o, do_unlink=True)
    return obj


def attach_part(obj: bpy.types.Object, path: str, part: str) -> bpy.types.Object:
    """Brings `part` of another model in and puts it on the front of `obj`'s barrel: along the
    long axis its back touches the front end, across it is centred on the front slice."""
    names = {o.name for o in bpy.data.objects}
    if path.lower().endswith(".obj"):
        bpy.ops.wm.obj_import(filepath=path)
    else:
        bpy.ops.import_scene.fbx(filepath=path)
    relink_missing_images(os.path.dirname(path))
    new = [o for o in bpy.data.objects if o.name not in names]
    extra = next(o for o in new if o.name.startswith(part))
    for o in new:
        if o != extra:
            bpy.data.objects.remove(o, do_unlink=True)
    bpy.ops.object.select_all(action="DESELECT")
    extra.select_set(True)
    bpy.context.view_layer.objects.active = extra
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    lo, hi = bounds(obj)
    axis = max(range(3), key=lambda i: hi[i] - lo[i])
    elo, ehi = bounds(extra)
    ecentre = (elo + ehi) * 0.5
    front_is_max = ecentre[axis] > (lo[axis] + hi[axis]) * 0.5
    end = hi[axis] if front_is_max else lo[axis]
    cut = (hi[axis] - lo[axis]) * TIP_SLICE
    front = [v.co for v in obj.data.vertices if (v.co[axis] >= end - cut if front_is_max else v.co[axis] <= end + cut)]
    target = sum(front, Vector()) / len(front)
    move = Vector(target - ecentre)
    move[axis] = (end - elo[axis]) if front_is_max else (end - ehi[axis])
    extra.data.transform(Matrix.Translation(move))
    bpy.ops.object.select_all(action="DESELECT")
    extra.select_set(True)
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.join()
    return bpy.context.active_object


def bounds(obj: bpy.types.Object) -> tuple:
    vs = [v.co for v in obj.data.vertices]
    lo = Vector((min(v.x for v in vs), min(v.y for v in vs), min(v.z for v in vs)))
    hi = Vector((max(v.x for v in vs), max(v.y for v in vs), max(v.z for v in vs)))
    return lo, hi


AXIS = {"x": Vector((1, 0, 0)), "y": Vector((0, 1, 0)), "z": Vector((0, 0, 1))}


def _axis(name: str) -> Vector:
    return -AXIS[name[1:]] if name.startswith("-") else AXIS[name]


def orient(obj: bpy.types.Object, cfg: dict) -> None:
    """Undo the author's rotation, then forward -> +Y and up -> +Z. By default the longest
    axis is forward, the middle one up, the shortest sideways; cfg can name them instead."""
    if "undo_euler" in cfg:
        rot = Euler([math.radians(a) for a in cfg["undo_euler"]], "XYZ").to_matrix()
        obj.data.transform(rot.inverted().to_4x4())
    if "axes" in cfg:
        forward, up = _axis(cfg["axes"][0]), _axis(cfg["axes"][1])
    else:
        lo, hi = bounds(obj)
        size = hi - lo
        order = sorted(range(3), key=lambda i: size[i])  # shortest, middle, longest
        forward, up = list(AXIS.values())[order[2]], list(AXIS.values())[order[1]]
    side = forward.cross(up)
    m = Matrix((side, forward, up))  # Rows: raw vectors that become X, Y, Z.
    if cfg.get("flip", False):
        m = Matrix.Rotation(math.pi, 3, "Z") @ m
    obj.data.transform(m.to_4x4())
    obj.data.update()


def scale_and_place(obj: bpy.types.Object, kind: str, length: float) -> None:
    lo, hi = bounds(obj)
    s = length / max(hi.y - lo.y, 1e-6)
    obj.data.transform(Matrix.Scale(s, 4))
    lo, hi = bounds(obj)
    share_y, share_z = HAND_SHARE[kind]
    hand = Vector(((lo.x + hi.x) * 0.5, lo.y + (hi.y - lo.y) * share_y, lo.z + (hi.z - lo.z) * share_z))
    obj.data.transform(Matrix.Translation(-hand))
    obj.data.update()


def decimate(obj: bpy.types.Object, max_tris: int) -> None:
    tris = sum(len(p.vertices) - 2 for p in obj.data.polygons)
    if tris <= max_tris:
        return
    mod = obj.modifiers.new("Decimate", "DECIMATE")
    mod.ratio = max_tris / tris
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.modifier_apply(modifier=mod.name)


def make_opaque() -> None:
    for mat in bpy.data.materials:
        if mat.node_tree is None:
            continue
        bsdf = next((n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None)
        if bsdf is not None:
            for link in list(bsdf.inputs["Alpha"].links):
                mat.node_tree.links.remove(link)
            bsdf.inputs["Alpha"].default_value = 1.0
        mat.blend_method = "OPAQUE"


def cap_textures() -> None:
    for image in bpy.data.images:
        w, h = image.size
        if max(w, h) > MAX_TEXTURE:
            f = MAX_TEXTURE / max(w, h)
            image.scale(max(1, int(w * f)), max(1, int(h * f)))
            image.pack()


def apply_tint(tint: tuple) -> None:
    """Multiplies textures by tint; untextured materials get it as their base colour."""
    for image in bpy.data.images:
        if image.size[0] == 0:
            continue
        px = list(image.pixels)
        for i in range(0, len(px), 4):
            px[i] *= tint[0]
            px[i + 1] *= tint[1]
            px[i + 2] *= tint[2]
        image.pixels = px
        image.pack()
    for mat in bpy.data.materials:
        if mat.node_tree is None:
            continue
        bsdf = next((n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None)
        if bsdf is not None and not bsdf.inputs["Base Color"].is_linked:
            bsdf.inputs["Base Color"].default_value = (*tint, 1.0)


def muzzle_point(obj: bpy.types.Object) -> list:
    """Front-most point (Blender), at the average height of the front slice; returned in Godot space."""
    lo, hi = bounds(obj)
    cut = hi.y - (hi.y - lo.y) * TIP_SLICE
    front = [v.co for v in obj.data.vertices if v.co.y >= cut]
    z = sum(v.z for v in front) / len(front)
    x = sum(v.x for v in front) / len(front)
    return [round(x, 4), round(z, 4), round(-hi.y, 4)]  # Godot: (x, z, -y)


def process(root: str, wid: str, preview: str) -> dict:
    cfg = MODELS[wid]
    kind = cfg["kind"]
    reset()
    obj = import_joined(os.path.join(root, RAW_DIR, cfg["raw"]), cfg.get("drop", ()), cfg.get("max_x", INF),
                        cfg.get("drop_exact", ()))
    if "attach" in cfg:
        obj = attach_part(obj, os.path.join(root, RAW_DIR, cfg["attach"][0]), cfg["attach"][1])
    orient(obj, cfg)
    scale_and_place(obj, kind, cfg["length"])
    decimate(obj, MAX_TRIS[kind])
    cap_textures()
    if cfg.get("opaque", False):
        make_opaque()
    if "tint" in cfg:
        apply_tint(cfg["tint"])
    obj.name = wid
    tris = sum(len(p.vertices) - 2 for p in obj.data.polygons)
    muzzle = muzzle_point(obj)
    os.makedirs(os.path.join(root, OUT_DIR), exist_ok=True)
    out = os.path.join(root, OUT_DIR, wid + ".glb")
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.ops.export_scene.gltf(filepath=out, export_format="GLB", use_selection=True, export_apply=True)
    if preview:
        render_side(obj, os.path.join(preview, wid + ".png"))
    lo, hi = bounds(obj)
    print(f"[weapons] {wid}: {tris} tris, {hi.y - lo.y:.2f} m long, muzzle {muzzle}")
    return {"muzzle": muzzle, "length": round(hi.y - lo.y, 4), "tris": tris}


def render_side(obj: bpy.types.Object, path: str) -> None:
    """Side view from +X: forward (+Y) points to the right, up (+Z) up, red dot = origin (hand)."""
    scene = bpy.context.scene
    # Cycles on the CPU: Workbench needs a GPU context (fails headless in the cloud).
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = 16
    world = bpy.data.worlds.new("Preview")
    world.color = (1.0, 1.0, 1.0)
    scene.world = world
    scene.render.resolution_x, scene.render.resolution_y = 640, 320
    lo, hi = bounds(obj)
    centre = (lo + hi) * 0.5
    span = max(hi.y - lo.y, (hi.z - lo.z) * 2.0) * 1.15
    cam_data = bpy.data.cameras.new("Cam")
    cam_data.type = "ORTHO"
    cam_data.ortho_scale = span
    cam = bpy.data.objects.new("Cam", cam_data)
    scene.collection.objects.link(cam)
    cam.location = (centre.x + 5.0, centre.y, centre.z)
    cam.rotation_euler = (math.pi / 2, 0.0, math.pi / 2)
    scene.camera = cam
    bpy.ops.mesh.primitive_uv_sphere_add(radius=span * 0.012, location=(0.0, 0.0, 0.0))
    dot = bpy.context.active_object
    mat = bpy.data.materials.new("Dot")
    mat.diffuse_color = (1.0, 0.0, 0.0, 1.0)
    dot.data.materials.append(mat)
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)


if __name__ == "__main__":
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    preview_dir = ""
    if "--preview" in argv:
        i = argv.index("--preview")
        preview_dir = os.path.abspath(argv[i + 1])
        del argv[i:i + 2]
        os.makedirs(preview_dir, exist_ok=True)
    project = os.path.abspath(argv[0]) if argv else os.getcwd()
    wanted = argv[1:] or list(MODELS)
    muzzles_path = os.path.join(project, OUT_DIR, "muzzles.json")
    data = {}
    if os.path.exists(muzzles_path):
        with open(muzzles_path, encoding="utf-8") as fh:
            data = json.load(fh)
    for wid in wanted:
        data[wid] = process(project, wid, preview_dir)
    with open(muzzles_path, "w", encoding="utf-8", newline="\n") as fh:
        json.dump(dict(sorted(data.items())), fh, indent=2)
        fh.write("\n")
