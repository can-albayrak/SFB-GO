"""Builds low-poly placeholder models (soldier + weapons) and exports them as .glb.

Run headless (does not touch any open Blender window):
    blender --background --factory-startup --python tools/blender/build_placeholders.py -- <project_root> [names...]

Conventions (Blender space): Z up, models face +Y (becomes Godot -Z forward after glTF export).
Soldier origin = between the feet. Weapon origin = trigger / firing-hand position.
Each model is joined into one mesh (one draw call per material). Real models replace these in stage 8.
"""

import math
import os
import sys

import bpy

# Weapon muzzle tips (Blender Y forward, Z up). Mirrored in the Godot weapon scenes' Muzzle markers.
MUZZLES = {
    "assault_rifle": (0.0, 0.62, 0.035),
    "pistol": (0.0, 0.15, 0.045),
    "heavy_rifle": (0.0, 0.84, 0.035),
    "shotgun": (0.0, 0.58, 0.055),
    "burst_rifle": (0.0, 0.60, 0.04),
    "lmg": (0.0, 0.70, 0.04),
    "musket": (0.0, 0.945, 0.035),
    "revolver": (0.0, 0.22, 0.048),
}

_materials: dict = {}


def reset_scene() -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    _materials.clear()


def mat(name: str, rgb: tuple, rough: float = 0.8, metal: float = 0.0) -> bpy.types.Material:
    if name in _materials:
        return _materials[name]
    m = bpy.data.materials.new(name)
    if bpy.app.version < (5, 0, 0):
        m.use_nodes = True  # Always on from Blender 5.
    bsdf = m.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*rgb, 1.0)
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Metallic"].default_value = metal
    m.diffuse_color = (*rgb, 1.0)
    _materials[name] = m
    return m


def _finish_part(obj: bpy.types.Object, material: bpy.types.Material) -> bpy.types.Object:
    obj.data.materials.append(material)
    return obj


def box(size: tuple, loc: tuple, material, rot: tuple = (0, 0, 0)) -> bpy.types.Object:
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=loc, rotation=[math.radians(a) for a in rot])
    obj = bpy.context.active_object
    obj.scale = size
    return _finish_part(obj, material)


def cyl(radius: float, depth: float, loc: tuple, material, rot: tuple = (0, 0, 0), verts: int = 12) -> bpy.types.Object:
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=verts, radius=radius, depth=depth, location=loc, rotation=[math.radians(a) for a in rot])
    return _finish_part(bpy.context.active_object, material)


def along_y(radius: float, depth: float, loc: tuple, material, verts: int = 12) -> bpy.types.Object:
    """Cylinder whose axis points forward (barrels, scopes)."""
    return cyl(radius, depth, loc, material, rot=(90, 0, 0), verts=verts)


def export(name: str, path: str) -> None:
    objs = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    bpy.ops.object.join()
    joined = bpy.context.active_object
    joined.name = name
    bpy.ops.object.shade_flat()
    os.makedirs(os.path.dirname(path), exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_apply=True)
    print(f"[placeholders] {name}: {len(joined.data.polygons)} faces -> {path}")


# --- Soldier (Wolf look: military vest, beret) ----------------------------------------------

def build_soldier() -> None:
    skin = mat("Skin", (0.72, 0.53, 0.40), 0.7)
    fatigue = mat("Fatigue", (0.36, 0.38, 0.27))
    vest = mat("Vest", (0.11, 0.12, 0.09), 0.9)
    boots = mat("Boots", (0.10, 0.08, 0.06), 0.6)
    black = mat("Black", (0.05, 0.05, 0.05), 0.5)
    beret = mat("Beret", (0.36, 0.05, 0.05), 0.9)

    for side in (-1, 1):
        box((0.15, 0.28, 0.12), (0.11 * side, 0.03, 0.06), boots)            # boot
        box((0.16, 0.18, 0.78), (0.11 * side, 0.0, 0.51), fatigue)           # leg
        box((0.17, 0.19, 0.12), (0.11 * side, 0.02, 0.52), vest)             # knee pad
        box((0.12, 0.13, 0.30), (0.29 * side, 0.0, 1.30), fatigue)           # upper arm
        box((0.14, 0.15, 0.10), (0.29 * side, 0.0, 1.42), vest)              # shoulder pad

    box((0.40, 0.22, 0.14), (0.0, 0.0, 0.90), fatigue)                       # hips
    box((0.42, 0.24, 0.06), (0.0, 0.0, 0.96), black)                         # belt
    box((0.42, 0.24, 0.48), (0.0, 0.0, 1.22), fatigue)                       # torso
    box((0.46, 0.30, 0.36), (0.0, 0.0, 1.22), vest)                          # plate carrier
    for x in (-0.13, 0.0, 0.13):
        box((0.10, 0.05, 0.11), (x, 0.17, 1.12), vest)                       # mag pouches
    box((0.30, 0.10, 0.30), (0.0, -0.18, 1.22), vest)                        # back panel

    # Arms held forward in a rifle-ready pose.
    box((0.10, 0.30, 0.10), (0.24, 0.16, 1.14), fatigue)                     # right forearm
    box((0.10, 0.34, 0.10), (-0.17, 0.20, 1.17), fatigue, rot=(0, 0, 28))    # left forearm
    box((0.09, 0.09, 0.09), (0.22, 0.33, 1.13), black)                       # right glove
    box((0.09, 0.09, 0.09), (-0.07, 0.36, 1.17), black)                      # left glove

    cyl(0.06, 0.10, (0.0, 0.0, 1.50), skin)                                  # neck
    box((0.22, 0.24, 0.24), (0.0, 0.01, 1.63), skin)                         # head
    box((0.20, 0.02, 0.045), (0.0, 0.13, 1.66), black)                       # sunglasses
    cyl(0.145, 0.05, (0.02, 0.0, 1.77), beret, rot=(0, -12, 0), verts=16)    # beret
    export("Soldier", os.path.join(OUT, "assets/models/characters/soldier.glb"))


# --- Weapons -------------------------------------------------------------------------------

def gun_materials() -> tuple:
    return (
        mat("GunMetal", (0.07, 0.07, 0.08), 0.45, 0.6),
        mat("Polymer", (0.14, 0.14, 0.13), 0.8),
    )


def build_assault_rifle() -> None:
    metal, poly = gun_materials()
    box((0.05, 0.34, 0.08), (0.0, 0.05, 0.03), metal)                        # receiver
    box((0.03, 0.30, 0.015), (0.0, 0.06, 0.078), metal)                      # top rail
    box((0.055, 0.22, 0.065), (0.0, 0.32, 0.025), poly)                      # handguard
    along_y(0.012, 0.18, (0.0, 0.51, 0.035), metal)                          # barrel
    along_y(0.018, 0.05, (0.0, 0.595, 0.035), metal)                         # muzzle brake
    box((0.01, 0.015, 0.04), (0.0, 0.41, 0.075), metal)                      # front sight
    box((0.03, 0.02, 0.03), (0.0, -0.07, 0.09), metal)                       # rear sight
    box((0.035, 0.07, 0.16), (0.0, 0.12, -0.08), poly, rot=(12, 0, 0))       # magazine
    box((0.035, 0.045, 0.11), (0.0, -0.04, -0.05), poly, rot=(-20, 0, 0))    # pistol grip
    box((0.04, 0.22, 0.07), (0.0, -0.23, 0.0), poly)                         # stock
    box((0.045, 0.02, 0.11), (0.0, -0.345, -0.01), metal)                    # butt pad
    export("AssaultRifle", os.path.join(OUT, "assets/models/weapons/assault_rifle.glb"))


def build_pistol() -> None:
    metal, poly = gun_materials()
    box((0.03, 0.19, 0.035), (0.0, 0.05, 0.045), metal)                      # slide
    box((0.028, 0.15, 0.025), (0.0, 0.04, 0.015), poly)                      # frame
    along_y(0.007, 0.012, (0.0, 0.146, 0.045), metal, verts=8)               # barrel tip
    box((0.03, 0.045, 0.11), (0.0, -0.02, -0.045), poly, rot=(-15, 0, 0))    # grip
    box((0.01, 0.05, 0.008), (0.0, 0.03, -0.012), poly)                      # trigger guard
    box((0.008, 0.01, 0.01), (0.0, 0.135, 0.067), metal)                     # front sight
    export("Pistol", os.path.join(OUT, "assets/models/weapons/pistol.glb"))


def build_heavy_rifle() -> None:
    metal, poly = gun_materials()
    olive = mat("Olive", (0.25, 0.27, 0.18), 0.85)
    box((0.05, 0.32, 0.07), (0.0, 0.05, 0.03), metal)                        # receiver
    along_y(0.015, 0.56, (0.0, 0.49, 0.035), metal)                          # barrel
    box((0.045, 0.07, 0.04), (0.0, 0.80, 0.035), metal)                      # muzzle brake
    along_y(0.022, 0.30, (0.0, 0.05, 0.115), metal, verts=16)                # scope tube
    along_y(0.03, 0.05, (0.0, -0.11, 0.115), metal, verts=16)                # eyepiece
    along_y(0.034, 0.07, (0.0, 0.22, 0.115), metal, verts=16)                # objective
    for y in (-0.02, 0.12):
        box((0.02, 0.02, 0.05), (0.0, y, 0.08), metal)                       # scope rings
    box((0.045, 0.30, 0.085), (0.0, -0.26, 0.0), olive)                      # stock
    box((0.04, 0.12, 0.04), (0.0, -0.22, 0.06), olive)                       # cheek rest
    box((0.035, 0.045, 0.11), (0.0, -0.04, -0.05), poly, rot=(-20, 0, 0))    # grip
    box((0.035, 0.08, 0.07), (0.0, 0.12, -0.045), poly)                      # magazine
    box((0.055, 0.20, 0.06), (0.0, 0.30, 0.02), olive)                       # forend
    export("HeavyRifle", os.path.join(OUT, "assets/models/weapons/heavy_rifle.glb"))


def build_shotgun() -> None:
    metal, poly = gun_materials()
    wood = mat("Wood", (0.33, 0.19, 0.09), 0.75)
    box((0.05, 0.22, 0.08), (0.0, 0.02, 0.03), metal)                        # receiver
    along_y(0.017, 0.46, (0.0, 0.35, 0.055), metal)                          # barrel
    along_y(0.014, 0.38, (0.0, 0.31, 0.02), metal)                           # tube magazine
    box((0.052, 0.14, 0.05), (0.0, 0.30, 0.02), wood)                        # pump
    box((0.035, 0.045, 0.10), (0.0, -0.10, -0.045), wood, rot=(-25, 0, 0))   # grip
    box((0.045, 0.28, 0.08), (0.0, -0.27, -0.01), wood)                      # stock
    box((0.01, 0.01, 0.012), (0.0, 0.56, 0.078), metal)                      # bead sight
    export("Shotgun", os.path.join(OUT, "assets/models/weapons/shotgun.glb"))


def build_burst_rifle() -> None:
    """Bullpup-ish burst rifle: short body, carry handle optic, tan furniture."""
    metal, poly = gun_materials()
    tan = mat("Tan", (0.55, 0.47, 0.33), 0.85)
    box((0.055, 0.46, 0.09), (0.0, 0.0, 0.03), tan)                          # body shell
    box((0.03, 0.26, 0.03), (0.0, 0.05, 0.095), metal)                       # carry rail
    along_y(0.02, 0.10, (0.0, 0.10, 0.125), metal, verts=12)                 # optic
    along_y(0.013, 0.22, (0.0, 0.43, 0.04), metal)                           # barrel
    box((0.03, 0.04, 0.03), (0.0, 0.56, 0.04), metal)                        # flash hider
    box((0.035, 0.065, 0.14), (0.0, -0.12, -0.07), poly, rot=(8, 0, 0))      # magazine (behind grip)
    box((0.035, 0.045, 0.11), (0.0, 0.08, -0.05), poly, rot=(-15, 0, 0))     # grip
    box((0.05, 0.03, 0.10), (0.0, -0.235, 0.0), poly)                        # butt pad
    export("BurstRifle", os.path.join(OUT, "assets/models/weapons/burst_rifle.glb"))


def build_lmg() -> None:
    """Belt-fed look: long heavy body, box magazine, bipod folded under the barrel."""
    metal, poly = gun_materials()
    olive = mat("Olive", (0.25, 0.27, 0.18), 0.85)
    box((0.07, 0.42, 0.10), (0.0, 0.05, 0.03), metal)                        # receiver
    box((0.075, 0.18, 0.02), (0.0, 0.08, 0.09), metal)                       # feed cover
    along_y(0.018, 0.42, (0.0, 0.47, 0.04), metal)                           # barrel
    along_y(0.028, 0.16, (0.0, 0.36, 0.04), metal, verts=10)                 # barrel jacket
    box((0.02, 0.03, 0.06), (0.0, 0.66, 0.04), metal)                        # front sight / muzzle
    box((0.10, 0.12, 0.12), (-0.07, 0.10, -0.06), olive)                     # box magazine
    box((0.035, 0.045, 0.11), (0.0, -0.06, -0.06), poly, rot=(-20, 0, 0))    # grip
    box((0.05, 0.24, 0.09), (0.0, -0.27, 0.0), poly)                         # stock
    for side in (-1, 1):
        box((0.012, 0.22, 0.012), (0.025 * side, 0.46, 0.005), metal)        # folded bipod legs
    box((0.04, 0.10, 0.02), (0.0, 0.24, -0.015), metal)                      # carry grip mount
    export("LMG", os.path.join(OUT, "assets/models/weapons/lmg.glb"))


def build_musket() -> None:
    """Cowboy primary: long single-shot musket, walnut stock, iron barrel, flintlock."""
    metal, _ = gun_materials()
    wood = mat("Walnut", (0.30, 0.17, 0.08), 0.7)
    brass = mat("Brass", (0.62, 0.48, 0.20), 0.4, 0.8)
    box((0.045, 0.62, 0.05), (0.0, 0.20, 0.0), wood)                         # forestock
    box((0.045, 0.30, 0.10), (0.0, -0.22, -0.035), wood, rot=(-8, 0, 0))     # butt stock
    box((0.05, 0.02, 0.12), (0.0, -0.375, -0.055), brass)                    # butt plate
    box((0.035, 0.05, 0.10), (0.0, -0.04, -0.05), wood, rot=(-20, 0, 0))     # wrist / grip
    along_y(0.011, 0.92, (0.0, 0.48, 0.035), metal)                          # barrel
    along_y(0.015, 0.03, (0.0, 0.93, 0.035), brass)                          # muzzle band
    for y in (0.25, 0.45):
        along_y(0.016, 0.02, (0.0, y, 0.03), brass)                          # barrel bands
    box((0.012, 0.06, 0.03), (0.022, 0.02, 0.045), metal)                    # lock plate
    box((0.008, 0.02, 0.035), (0.022, 0.0, 0.07), metal, rot=(30, 0, 0))     # hammer
    box((0.006, 0.015, 0.015), (0.0, 0.92, 0.055), metal)                    # front sight
    export("Musket", os.path.join(OUT, "assets/models/weapons/musket.glb"))


def build_revolver() -> None:
    """Cowboy secondary: heavy six-shooter with a long barrel and wooden grip."""
    metal, _ = gun_materials()
    wood = mat("Walnut", (0.30, 0.17, 0.08), 0.7)
    box((0.03, 0.09, 0.05), (0.0, 0.02, 0.035), metal)                       # frame
    cyl(0.026, 0.05, (0.0, 0.03, 0.04), metal, rot=(90, 0, 0), verts=6)      # cylinder (hex)
    along_y(0.009, 0.16, (0.0, 0.14, 0.048), metal)                          # barrel
    box((0.012, 0.16, 0.012), (0.0, 0.14, 0.034), metal)                     # ejector rod housing
    box((0.028, 0.045, 0.10), (0.0, -0.035, -0.035), wood, rot=(-25, 0, 0))  # grip
    box((0.008, 0.03, 0.02), (0.0, -0.025, 0.07), metal, rot=(-30, 0, 0))    # hammer
    box((0.008, 0.012, 0.012), (0.0, 0.215, 0.06), metal)                    # front sight
    export("Revolver", os.path.join(OUT, "assets/models/weapons/revolver.glb"))


def build_knife() -> None:
    """Combat knife, blade forward (+Y), origin at the grip."""
    metal = mat("Blade", (0.55, 0.56, 0.58), 0.3, 0.9)
    black = mat("Black", (0.05, 0.05, 0.05), 0.6)
    box((0.028, 0.11, 0.03), (0.0, -0.02, 0.0), black)                       # handle
    box((0.07, 0.012, 0.035), (0.0, 0.04, 0.0), black)                       # guard
    box((0.006, 0.16, 0.03), (0.0, 0.125, 0.004), metal)                     # blade
    box((0.006, 0.03, 0.018), (0.0, 0.215, 0.008), metal, rot=(-35, 0, 0))   # tip
    export("Knife", os.path.join(OUT, "assets/models/weapons/knife.glb"))


def build_frag() -> None:
    olive = mat("Olive", (0.25, 0.27, 0.18), 0.85)
    metal, _ = gun_materials()
    bpy.ops.mesh.primitive_uv_sphere_add(segments=10, ring_count=6, radius=0.045, location=(0.0, 0.0, 0.0))
    _finish_part(bpy.context.active_object, olive)                           # body
    cyl(0.018, 0.03, (0.0, 0.0, 0.05), metal)                                # fuse
    box((0.012, 0.06, 0.012), (0.0, 0.025, 0.045), metal, rot=(20, 0, 0))    # spoon
    export("FragGrenade", os.path.join(OUT, "assets/models/weapons/frag_grenade.glb"))


def build_flashbang() -> None:
    grey = mat("FlashGrey", (0.55, 0.57, 0.6), 0.6, 0.3)
    metal, _ = gun_materials()
    cyl(0.03, 0.11, (0.0, 0.0, 0.0), grey)                                   # canister
    cyl(0.018, 0.025, (0.0, 0.0, 0.065), metal)                              # fuse
    box((0.012, 0.06, 0.012), (0.0, 0.025, 0.06), metal, rot=(20, 0, 0))     # spoon
    export("Flashbang", os.path.join(OUT, "assets/models/weapons/flashbang.glb"))


if __name__ == "__main__":
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    OUT = os.path.abspath(argv[0]) if argv else os.getcwd()
    # Optional names after the root build only those (e.g. `-- . musket revolver`), so models
    # tuned by hand after an earlier run are not overwritten.
    only = set(argv[1:])
    for build in (build_soldier, build_assault_rifle, build_pistol, build_heavy_rifle, build_shotgun,
                  build_burst_rifle, build_lmg, build_knife, build_frag, build_flashbang,
                  build_musket, build_revolver):
        if only and build.__name__.removeprefix("build_") not in only:
            continue
        reset_scene()
        build()
