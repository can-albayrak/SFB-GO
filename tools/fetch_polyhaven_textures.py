"""Downloads the map textures from Poly Haven (all CC0) and shrinks them for the PS2 look.

    python tools/fetch_polyhaven_textures.py [ids...]

For every id: the 1k diffuse jpg (api.polyhaven.com), resized to SIZE px (Lanczos), saved as
assets/textures/env/<id>.png. Maps use them with nearest filtering and triplanar UVs. Needs
Pillow. Add an id to TEXTURES and re-run to bring in another one.
"""

import io
import json
import os
import sys
import urllib.request

from PIL import Image

ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), ".."))
OUT = os.path.join(ROOT, "assets", "textures", "env")
SIZE = 256
TEXTURES = [
    "snow_02", "snow_floor", "asphalt_snow", "cobblestone_floor_02", "concrete_wall_001", "brick_wall_02",
    "distressed_painted_planks", "brown_planks_03", "container_side", "corrugated_iron", "grey_roof_tiles",
    "bark_brown_02", "rough_pine_door", "factory_wall", "painted_brick",
]
HEADERS = {"User-Agent": "sfb-go-asset-fetch"}


def fetch(url: str) -> bytes:
    return urllib.request.urlopen(urllib.request.Request(url, headers=HEADERS)).read()


def main(ids: list) -> None:
    os.makedirs(OUT, exist_ok=True)
    for asset_id in ids:
        files = json.loads(fetch(f"https://api.polyhaven.com/files/{asset_id}"))
        url = files["Diffuse"]["1k"]["jpg"]["url"]
        image = Image.open(io.BytesIO(fetch(url))).convert("RGB").resize((SIZE, SIZE), Image.LANCZOS)
        image.save(os.path.join(OUT, asset_id + ".png"))
        print(f"{asset_id}: {SIZE} px")


if __name__ == "__main__":
    main(sys.argv[1:] or TEXTURES)
