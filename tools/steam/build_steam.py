"""Builds the Steam version of SFB:GO (App ID 480, Spacewar) with the GodotSteam export templates.

    py tools/steam/build_steam.py --godot "C:\\path\\to\\Godot_v4.7.2-stable_win64_console.exe"
    python3 tools/steam/build_steam.py --godot godot --platform linux

What it does:
1. Downloads the GodotSteam templates for Godot 4.7.2 (one ~460 MB archive, once) into
   private_assets/godotsteam/ and keeps only this platform's files.
2. Adds (or refreshes) a "<Platform> Steam" preset in export_presets.cfg. That file stays local
   (git-ignored); other presets in it are left alone.
3. Imports the project and exports it to builds/SFB-GO_steam_<platform>/ with the Steam library
   (steam_api64.dll / libsteam_api.so) and steam_appid.txt (480) next to the game.
4. Zips that folder to builds/SFB-GO_steam_<platform>.zip for friends.

Everyone runs Steam (signed in) and then the game. The plain Godot editor has no Steam: the
menu says so, ENet (IP) play still works there.
"""

import argparse
import os
import re
import shutil
import subprocess
import sys
import tarfile
import urllib.request
import zipfile

ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", ".."))
TEMPLATES_URL = ("https://github.com/GodotSteam/GodotSteam/releases/download/v4.22.1/"
                 "godotsteam-g472-s165-gs4221-templates.tar.xz")
TEMPLATES_DIR = os.path.join(ROOT, "private_assets", "godotsteam")
APP_ID = 480
GAME = "SFB-GO"

PLATFORMS = {
    "windows": {
        "godot_platform": "Windows Desktop",
        "preset": "Windows Steam",
        "release": "win64/godotsteam.472.template.win64.exe",
        "debug": "win64/godotsteam.472.debug.template.win64.exe",
        "library": "win64/steam_api64.dll",
        "binary": GAME + ".exe",
        "options": {
            "binary_format/architecture": '"x86_64"',
            "binary_format/embed_pck": "false",
            "application/modify_resources": "false",  # No rcedit needed.
            "codesign/enable": "false",
            "texture_format/s3tc_bptc": "true",
            "texture_format/etc2_astc": "false",
        },
    },
    "linux": {
        "godot_platform": "Linux",
        "preset": "Linux Steam",
        "release": "linux64/godotsteam.472.template.x86_64",
        "debug": "linux64/godotsteam.472.debug.template.x86_64",
        "library": "linux64/libsteam_api.so",
        "binary": GAME + ".x86_64",
        "options": {
            "binary_format/architecture": '"x86_64"',
            "binary_format/embed_pck": "false",
            "texture_format/s3tc_bptc": "true",
            "texture_format/etc2_astc": "false",
        },
    },
}
# Not shipped: headless tests (tools/ and private_assets/ have .gdignore already).
EXCLUDE_FILTER = "tests/*"


def fetch_templates(cfg: dict) -> None:
    wanted = [cfg["release"], cfg["debug"], cfg["library"]]
    if all(os.path.exists(os.path.join(TEMPLATES_DIR, w)) for w in wanted):
        return
    os.makedirs(TEMPLATES_DIR, exist_ok=True)
    archive = os.path.join(TEMPLATES_DIR, "templates.tar.xz")
    if not os.path.exists(archive):
        print(f"[steam] Downloading GodotSteam templates (~460 MB)\n        {TEMPLATES_URL}")
        partial = archive + ".part"
        urllib.request.urlretrieve(TEMPLATES_URL, partial)
        os.replace(partial, archive)
    print("[steam] Extracting " + ", ".join(wanted))
    with tarfile.open(archive, "r:xz") as tar:
        for member in wanted:
            tar.extract(member, TEMPLATES_DIR)
    os.remove(archive)  # Only this platform's files are kept.


def read_presets(path: str) -> list:
    """export_presets.cfg -> [(name, preset_lines, options_lines)] in file order."""
    if not os.path.exists(path):
        return []
    sections = {}
    current = None
    for line in open(path, encoding="utf-8").read().split("\n"):
        m = re.match(r"\[(preset\.\d+(?:\.options)?)\]$", line)
        if m:
            current = m.group(1)
            sections[current] = []
        elif current is not None:
            sections[current].append(line)
    presets = []
    index = 0
    while f"preset.{index}" in sections:
        body = sections[f"preset.{index}"]
        name = next((l.split("=", 1)[1].strip().strip('"') for l in body if l.startswith("name=")), "")
        presets.append((name, body, sections.get(f"preset.{index}.options", [])))
        index += 1
    return presets


def write_presets(path: str, presets: list) -> None:
    out = []
    for i, (_name, body, options) in enumerate(presets):
        out.append(f"[preset.{i}]")
        out.extend(l for l in body if l != "")
        out.append("")
        out.append(f"[preset.{i}.options]")
        out.extend(l for l in options if l != "")
        out.append("")
    with open(path, "w", encoding="utf-8", newline="\n") as fh:
        fh.write("\n".join(out))


def set_preset(cfg: dict, export_path: str) -> None:
    path = os.path.join(ROOT, "export_presets.cfg")
    presets = [p for p in read_presets(path) if p[0] != cfg["preset"]]
    template = lambda key: os.path.join(TEMPLATES_DIR, cfg[key]).replace("\\", "/")
    body = [
        f'name="{cfg["preset"]}"',
        f'platform="{cfg["godot_platform"]}"',
        "runnable=false",
        'export_filter="all_resources"',
        'include_filter=""',
        f'exclude_filter="{EXCLUDE_FILTER}"',
        f'export_path="{export_path}"',
    ]
    options = [
        f'custom_template/debug="{template("debug")}"',
        f'custom_template/release="{template("release")}"',
    ] + [f"{k}={v}" for k, v in cfg["options"].items()]
    presets.append((cfg["preset"], body, options))
    write_presets(path, presets)


def run(godot: str, *args: str) -> None:
    cmd = [godot, "--headless", "--path", ROOT, *args]
    print("[steam] " + " ".join(cmd))
    result = subprocess.run(cmd)
    if result.returncode != 0:
        sys.exit(f"[steam] Godot failed ({result.returncode})")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--godot", default=os.environ.get("GODOT", "godot"), help="Godot 4.7.2 editor executable")
    parser.add_argument("--platform", choices=sorted(PLATFORMS), default="windows")
    parser.add_argument("--debug", action="store_true", help="debug template (console output, slower)")
    args = parser.parse_args()
    cfg = PLATFORMS[args.platform]

    fetch_templates(cfg)
    out_dir = os.path.join(ROOT, "builds", f"{GAME}_steam_{args.platform}")
    if os.path.isdir(out_dir):
        shutil.rmtree(out_dir)
    os.makedirs(out_dir)
    binary = os.path.join(out_dir, cfg["binary"])
    set_preset(cfg, os.path.relpath(binary, ROOT).replace("\\", "/"))

    run(args.godot, "--import")
    run(args.godot, "--export-debug" if args.debug else "--export-release", cfg["preset"], binary)
    if not os.path.exists(binary):
        sys.exit("[steam] Export produced no game file")
    shutil.copy2(os.path.join(TEMPLATES_DIR, cfg["library"]), out_dir)
    with open(os.path.join(out_dir, "steam_appid.txt"), "w", encoding="ascii") as fh:
        fh.write(f"{APP_ID}\n")
    if args.platform == "linux":
        os.chmod(binary, 0o755)

    zip_path = out_dir + ".zip"
    with zipfile.ZipFile(zip_path, "w", zipfile.ZIP_DEFLATED) as zf:
        for name in sorted(os.listdir(out_dir)):
            zf.write(os.path.join(out_dir, name), os.path.join(os.path.basename(out_dir), name))
    print(f"[steam] Done: {zip_path} ({os.path.getsize(zip_path) // (1024 * 1024)} MB)")


if __name__ == "__main__":
    main()
