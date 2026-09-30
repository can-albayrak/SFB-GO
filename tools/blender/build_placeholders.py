"""Builds low-poly placeholder models (soldier + weapons) and exports them as .glb.

Run headless (does not touch any open Blender window):
    blender --background --factory-startup --python tools/blender/build_placeholders.py -- <project_root>

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


if __name__ == "__main__":
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    OUT = os.path.abspath(argv[0]) if argv else os.getcwd()
    for build in (build_soldier, build_assault_rifle, build_pistol, build_heavy_rifle, build_shotgun):
        reset_scene()
        build()
