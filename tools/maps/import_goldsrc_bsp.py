"""Converts a GoldSrc (Half-Life / CS 1.6 / CS Online) BSP v30 map into a glTF binary for Godot.

    python tools/maps/import_goldsrc_bsp.py MAP.bsp WAD_DIR OUT.glb LIGHTMAP.png [--scale 0.0254] [--info OUT.json]

- Geometry: the world model (*0) plus static brush entities (func_wall, func_door shut,
  func_illusionary). Tool faces (sky, clip, trigger, origin, null) are dropped; func_train,
  func_ladder and trigger_* brushes are left out.
- Textures: from the BSP itself or the WAD3 files in WAD_DIR (looked up by name). "{" textures
  are cut out on their palette's last colour (blue in the editor). Nearest filtering is set in
  the Godot import, so they keep the pixelated look.
- Light: the map's own baked lightmaps, packed into one atlas (LIGHTMAP.png) that the mesh
  reads through its second UV set. GoldSrcMap (scripts/maps/goldsrc_map.gd) swaps the
  imported materials for an unshaded texture x lightmap shader.
- Collision: a separate "Collision-colonly" node (all solid faces), func_illusionary excluded.
- Axes: GoldSrc is Z up; Godot (x, y, z) = (x, z, -y) * scale. 1 unit = 1 inch (0.0254 m).
--info writes spawn points, lights and ladders (in Godot metres) for the scene builder.
"""

import argparse
import json
import math
import os
import re
import struct
import zlib

TOOL_TEXTURES = {"sky", "clip", "aaatrigger", "origin", "null", "hint", "skip", "bevel"}
STATIC_BRUSHES = {"func_wall", "func_door", "func_illusionary", "func_wall_toggle", "func_breakable"}
NO_COLLISION = {"func_illusionary"}
LUXEL = 16.0  # GoldSrc lightmap luxel size in texture units.
ATLAS_WIDTH = 1024


def read_lumps(data):
    version = struct.unpack_from("<i", data, 0)[0]
    if version != 30:
        raise SystemExit("not a BSP v30 file (version %d)" % version)
    return [struct.unpack_from("<ii", data, 4 + 8 * i) for i in range(15)]


def parse_entities(text):
    return [dict(re.findall(r'"([^"]*)"\s*"([^"]*)"', block)) for block in re.findall(r"\{([^{}]*)\}", text)]


def decode_miptex(data, base, palette_after_mips=True):
    name = data[base:base + 16].split(b"\0")[0].decode("latin1").lower()
    width, height = struct.unpack_from("<II", data, base + 16)
    offsets = struct.unpack_from("<4I", data, base + 24)
    if offsets[0] == 0:
        return name, width, height, None
    pixels = data[base + offsets[0]:base + offsets[0] + width * height]
    pal_ofs = base + offsets[3] + (width // 8) * (height // 8) + 2
    palette = data[pal_ofs:pal_ofs + 768]
    masked = name.startswith("{")
    rgba = bytearray(width * height * 4)
    for i, index in enumerate(pixels):
        r, g, b = palette[index * 3:index * 3 + 3]
        a = 0 if masked and index == 255 else 255
        rgba[i * 4:i * 4 + 4] = bytes((r, g, b, a)) if a else b"\0\0\0\0"
    return name, width, height, bytes(rgba)


def read_wads(wad_dir):
    found = {}
    for file_name in sorted(os.listdir(wad_dir)):
        if not file_name.lower().endswith(".wad"):
            continue
        data = open(os.path.join(wad_dir, file_name), "rb").read()
        if data[:4] != b"WAD3":
            continue
        count, table = struct.unpack_from("<ii", data, 4)
        for i in range(count):
            pos, _disk, _size, kind, _comp = struct.unpack_from("<iiibb", data, table + 32 * i)
            name = data[table + 32 * i + 16:table + 32 * i + 32].split(b"\0")[0].decode("latin1").lower()
            if kind == 0x43 and name not in found:
                found[name] = (data, pos)
    return found


def png_bytes(width, height, rgba):
    rows = b"".join(b"\0" + rgba[y * width * 4:(y + 1) * width * 4] for y in range(height))
    def chunk(kind, body):
        return struct.pack(">I", len(body)) + kind + body + struct.pack(">I", zlib.crc32(kind + body) & 0xFFFFFFFF)
    return (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0))
            + chunk(b"IDAT", zlib.compress(rows, 9)) + chunk(b"IEND", b""))


def dot(a, b):
    return a[0] * b[0] + a[1] * b[1] + a[2] * b[2]


class Atlas:
    """Shelf packer for the per-face lightmaps (1 px border, copied from the edge)."""

    def __init__(self, width):
        self.width = width
        self.x = 0
        self.y = 0
        self.row = 0
        self.blits = []  # (x, y, w, h, rgb bytes)

    def add(self, w, h, rgb):
        pw, ph = w + 2, h + 2
        if self.x + pw > self.width:
            self.x, self.y, self.row = 0, self.y + self.row, 0
        x, y = self.x, self.y
        self.x += pw
        self.row = max(self.row, ph)
        self.blits.append((x, y, w, h, rgb))
        return x + 1, y + 1

    def image(self):
        height = 1
        while height < self.y + self.row:
            height *= 2
        rgba = bytearray(self.width * height * 4)
        for x0, y0, w, h, rgb in self.blits:
            for y in range(-1, h + 1):
                sy = min(max(y, 0), h - 1)
                for x in range(-1, w + 1):
                    sx = min(max(x, 0), w - 1)
                    i = (sy * w + sx) * 3
                    o = ((y0 + 1 + y) * self.width + x0 + 1 + x) * 4
                    rgba[o:o + 4] = bytes((rgb[i], rgb[i + 1], rgb[i + 2], 255))
        return self.width, height, bytes(rgba)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("bsp")
    parser.add_argument("wad_dir")
    parser.add_argument("out")
    parser.add_argument("lightmap")
    parser.add_argument("--scale", type=float, default=0.0254)
    parser.add_argument("--info")
    args = parser.parse_args()
    scale = args.scale

    data = open(args.bsp, "rb").read()
    lumps = read_lumps(data)
    def lump(i):
        return lumps[i][0], lumps[i][1]

    entities = parse_entities(data[lumps[0][0]:lumps[0][0] + lumps[0][1]].decode("latin1"))
    planes_ofs, _ = lump(1)
    vert_ofs, vert_len = lump(3)
    verts = [struct.unpack_from("<3f", data, vert_ofs + 12 * i) for i in range(vert_len // 12)]
    tex_ofs, tex_len = lump(6)
    texinfos = [struct.unpack_from("<4f4fII", data, tex_ofs + 40 * i) for i in range(tex_len // 40)]
    face_ofs, face_len = lump(7)
    light_ofs, light_len = lump(8)
    lighting = data[light_ofs:light_ofs + light_len]
    edge_ofs, edge_len = lump(12)
    edges = [struct.unpack_from("<2H", data, edge_ofs + 4 * i) for i in range(edge_len // 4)]
    surf_ofs, surf_len = lump(13)
    surfedges = struct.unpack_from("<%di" % (surf_len // 4), data, surf_ofs)
    model_ofs, model_len = lump(14)
    models = [struct.unpack_from("<9f4i3i", data, model_ofs + 64 * i) for i in range(model_len // 64)]

    # Textures.
    wads = read_wads(args.wad_dir)
    mip_ofs, _ = lump(2)
    count = struct.unpack_from("<I", data, mip_ofs)[0]
    offsets = struct.unpack_from("<%di" % count, data, mip_ofs + 4)
    textures = []  # (name, width, height, rgba or None)
    for offset in offsets:
        name, width, height, rgba = decode_miptex(data, mip_ofs + offset)
        if rgba is None and name in wads:
            wad_data, pos = wads[name]
            _n, width, height, rgba = decode_miptex(wad_data, pos)
        textures.append((name, width, height, rgba))

    # Which models to draw and collide with.
    wanted = {0: (True, True)}  # model index -> (drawn, collides)
    for ent in entities:
        model = ent.get("model", "")
        if model.startswith("*") and ent.get("classname") in STATIC_BRUSHES:
            # Render modes 1-3 and 5 blend by renderamt: at 0 the brush is an invisible wall.
            mode = int(ent.get("rendermode", "0"))
            amount = int(ent.get("renderamt", "0"))
            drawn = not (mode in (1, 2, 3, 5) and amount == 0)
            wanted[int(model[1:])] = (drawn, ent.get("classname") not in NO_COLLISION)

    def to_godot(p):
        return (p[0] * scale, p[2] * scale, -p[1] * scale)

    atlas = Atlas(ATLAS_WIDTH)
    groups = {}  # texture index -> lists
    collision = []
    missing = set()
    for model_index, (drawn, collides) in sorted(wanted.items()):
        first_face, num_faces = models[model_index][14], models[model_index][15]
        for face_index in range(first_face, first_face + num_faces):
            plane, side, first_edge, num_edges, texinfo_index = struct.unpack_from("<HHiHH", data, face_ofs + 20 * face_index)
            styles = data[face_ofs + 20 * face_index + 12:face_ofs + 20 * face_index + 16]
            lightofs = struct.unpack_from("<i", data, face_ofs + 20 * face_index + 16)[0]
            info = texinfos[texinfo_index]
            s_vec, s_off, t_vec, t_off = info[0:3], info[3], info[4:7], info[7]
            tex_index = info[8]
            name, width, height, rgba = textures[tex_index]
            if name in TOOL_TEXTURES or name.startswith("sky"):
                continue
            if rgba is None and drawn:
                missing.add(name)
            poly = []
            for k in range(num_edges):
                e = surfedges[first_edge + k]
                poly.append(verts[edges[e][0]] if e >= 0 else verts[edges[-e][1]])
            normal = struct.unpack_from("<3f", data, planes_ofs + 20 * plane)
            if side:
                normal = tuple(-n for n in normal)
            # Lightmap extents.
            ss = [dot(v, s_vec) + s_off for v in poly]
            ts = [dot(v, t_vec) + t_off for v in poly]
            min_s, min_t = math.floor(min(ss) / LUXEL), math.floor(min(ts) / LUXEL)
            lw = math.ceil(max(ss) / LUXEL) - min_s + 1
            lh = math.ceil(max(ts) / LUXEL) - min_t + 1
            if lightofs >= 0 and styles[0] != 255:
                light = lighting[lightofs:lightofs + lw * lh * 3]
            else:
                light = b"\xff" * (lw * lh * 3)
            if len(light) < lw * lh * 3:
                light += b"\0" * (lw * lh * 3 - len(light))
            if not drawn:
                for i in range(1, len(poly) - 1):
                    if collides:
                        collision.extend(to_godot(p) for p in (poly[0], poly[i], poly[i + 1]))
                continue
            ax, ay = atlas.add(lw, lh, light)

            group = groups.setdefault(tex_index, {"pos": [], "nrm": [], "uv": [], "uv2": []})
            gn = to_godot(normal)
            for i in range(1, len(poly) - 1):
                tri = (poly[0], poly[i], poly[i + 1])
                if collides:
                    collision.extend(to_godot(p) for p in tri)
                for p in tri:
                    fs = (dot(p, s_vec) + s_off) / LUXEL - min_s
                    ft = (dot(p, t_vec) + t_off) / LUXEL - min_t
                    group["pos"].append(to_godot(p))
                    group["nrm"].append(gn)
                    group["uv"].append(((dot(p, s_vec) + s_off) / width, (dot(p, t_vec) + t_off) / height))
                    group["uv2"].append((ax + fs + 0.5, ay + ft + 0.5))  # Pixels; normalised below.

    # glTF: GoldSrc polygons wind clockwise seen from the front; glTF wants counter-clockwise.
    # The axis swap is a proper rotation, so flip the order of every triangle.
    def flip(values):
        out = []
        for i in range(0, len(values), 3):
            out += [values[i], values[i + 2], values[i + 1]]
        return out

    gltf = {"asset": {"version": "2.0", "generator": "SFB:GO import_goldsrc_bsp.py"},
            "scene": 0, "scenes": [{"nodes": [0, 1]}], "nodes": [], "meshes": [], "materials": [],
            "textures": [], "images": [], "samplers": [{"magFilter": 9728, "minFilter": 9984}],
            "accessors": [], "bufferViews": [], "buffers": []}
    blob = bytearray()

    def add_view(raw, target=None):
        while len(blob) % 4:
            blob.append(0)
        view = {"buffer": 0, "byteOffset": len(blob), "byteLength": len(raw)}
        if target:
            view["target"] = target
        blob.extend(raw)
        gltf["bufferViews"].append(view)
        return len(gltf["bufferViews"]) - 1

    def add_accessor(values, kind, ncomp):
        flat = [c for v in values for c in v]
        view = add_view(struct.pack("<%df" % len(flat), *flat), 34962)
        acc = {"bufferView": view, "componentType": 5126, "count": len(values), "type": kind}
        if kind == "VEC3" and ncomp == 3:
            acc["min"] = [min(v[i] for v in values) for i in range(3)]
            acc["max"] = [max(v[i] for v in values) for i in range(3)]
        gltf["accessors"].append(acc)
        return len(gltf["accessors"]) - 1

    atlas_w, atlas_h, atlas_rgba = atlas.image()
    with open(args.lightmap, "wb") as f:
        f.write(png_bytes(atlas_w, atlas_h, atlas_rgba))
    primitives = []
    for tex_index, group in sorted(groups.items()):
        name, width, height, rgba = textures[tex_index]
        material = {"name": name, "pbrMetallicRoughness": {"metallicFactor": 0.0, "roughnessFactor": 1.0},
                    "extensions": {"KHR_materials_unlit": {}}}
        if rgba is not None:
            image_view = add_view(png_bytes(width, height, rgba))
            gltf["images"].append({"name": name.lstrip("{"), "mimeType": "image/png", "bufferView": image_view})
            gltf["textures"].append({"source": len(gltf["images"]) - 1, "sampler": 0})
            material["pbrMetallicRoughness"]["baseColorTexture"] = {"index": len(gltf["textures"]) - 1}
        if name.startswith("{"):
            material["alphaMode"] = "MASK"
            material["alphaCutoff"] = 0.5
            material["doubleSided"] = True
        gltf["materials"].append(material)
        primitives.append({"attributes": {
            "POSITION": add_accessor(flip(group["pos"]), "VEC3", 3),
            "NORMAL": add_accessor(flip(group["nrm"]), "VEC3", 0),
            "TEXCOORD_0": add_accessor(flip(group["uv"]), "VEC2", 2),
            "TEXCOORD_1": add_accessor(flip([(u / atlas_w, v / atlas_h) for u, v in group["uv2"]]), "VEC2", 2),
        }, "material": len(gltf["materials"]) - 1})
    gltf["meshes"].append({"name": "World", "primitives": primitives})
    gltf["meshes"].append({"name": "Collision", "primitives": [
        {"attributes": {"POSITION": add_accessor(flip(collision), "VEC3", 3)}}]})
    gltf["nodes"] = [{"name": "World", "mesh": 0}, {"name": "Collision-colonly", "mesh": 1}]
    gltf["extensionsUsed"] = ["KHR_materials_unlit"]
    gltf["buffers"] = [{"byteLength": len(blob)}]

    body = json.dumps(gltf, separators=(",", ":")).encode()
    body += b" " * ((4 - len(body) % 4) % 4)
    while len(blob) % 4:
        blob.append(0)
    with open(args.out, "wb") as f:
        f.write(struct.pack("<III", 0x46546C67, 2, 12 + 8 + len(body) + 8 + len(blob)))
        f.write(struct.pack("<II", len(body), 0x4E4F534A) + body)
        f.write(struct.pack("<II", len(blob), 0x004E4942) + bytes(blob))
    tris = sum(len(g["pos"]) for g in groups.values()) // 3
    print("wrote %s: %d textures, %d triangles, %d collision triangles" % (args.out, len(groups), tris, len(collision) // 3))
    if missing:
        print("textures not found:", ", ".join(sorted(missing)))

    if args.info:
        info = {"spawns": [], "lights": [], "ladders": [], "sun": None, "bounds": None}
        for ent in entities:
            cls = ent.get("classname", "")
            if "origin" in ent:
                origin = to_godot(tuple(float(x) for x in ent["origin"].split()))
            if cls in ("info_player_deathmatch", "info_player_start"):
                yaw = float(ent.get("angles", "0 0 0").split()[1])
                info["spawns"].append({"pos": origin, "yaw_deg": yaw, "kind": cls})
            elif cls == "light_environment":
                info["sun"] = {"pitch": float(ent.get("pitch", "-90")), "yaw": float(ent.get("angles", "0 0 0").split()[1])}
            elif cls == "func_ladder":
                m = models[int(ent["model"][1:])]
                lo, hi = to_godot(m[0:3]), to_godot(m[3:6])
                info["ladders"].append({"min": [min(lo[i], hi[i]) for i in range(3)], "max": [max(lo[i], hi[i]) for i in range(3)]})
        w = models[0]
        lo, hi = to_godot(w[0:3]), to_godot(w[3:6])
        info["bounds"] = {"min": [min(lo[i], hi[i]) for i in range(3)], "max": [max(lo[i], hi[i]) for i in range(3)]}
        with open(args.info, "w") as f:
            json.dump(info, f, indent=1)


if __name__ == "__main__":
    main()
