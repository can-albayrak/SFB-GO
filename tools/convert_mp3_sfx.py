"""Turns Can's mp3 sound clips (2026-10-07, Downloads) into game clips in assets/audio: mono
(3D sounds need it), 44.1 kHz 16-bit, cut to the part we use with a short fade-out. Decoding
needs `pip install miniaudio` (no ffmpeg on this PC).

    python tools/convert_mp3_sfx.py "C:/Users/Administrator/Downloads"

Cuts (seconds in the source; picked from its loudness envelope):
- 9mm Para Pistol Shot -> shot_deagle (Desert Eagle)
- 50 cal MG -> shot_lmg_1..4 (LMG): four single, well separated shots of the long recording
- Shoot And Reload -> shot_bolt (Scout: the shot, then the bolt worked)
- Pistol Cock -> reload_click (every magazine reload starts with it)
- Small Explosion -> explosion_small (Grenade Launcher round)
- Bullet Fly Buy -> whiz (another player's bullet passing close)
- Pistol Cock (first click) -> dry_fire (trigger on an empty gun); (second click) -> weapon_draw
"""

import array
import os
import struct
import sys
import wave

import miniaudio

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "audio")
RATE = 44100
FADE = 0.08  # Seconds of fade-out at every cut end.

# output name -> (source file, start, end) in seconds
CUTS = {
    "shot_deagle": ("9mm Para Pistol Shot.mp3", 0.0, 1.0),
    "shot_lmg_1": ("50 cal MG.mp3", 1.92, 2.42),
    "shot_lmg_2": ("50 cal MG.mp3", 4.96, 5.46),
    "shot_lmg_3": ("50 cal MG.mp3", 6.76, 7.26),
    "shot_lmg_4": ("50 cal MG.mp3", 10.31, 10.81),
    "shot_bolt": ("Shoot And Reload.mp3", 0.0, 1.57),
    "reload_click": ("Pistol Cock.mp3", 0.1, 0.6),
    "explosion_small": ("Small Explosion.mp3", 0.0, 1.23),
    "whiz": ("Bullet Fly Buy.mp3", 0.08, 0.6),
    "dry_fire": ("Pistol Cock.mp3", 0.16, 0.3),
    "weapon_draw": ("Pistol Cock.mp3", 0.33, 0.62),
}


def load(path: str) -> array.array:
    decoded = miniaudio.decode_file(path, output_format=miniaudio.SampleFormat.FLOAT32, nchannels=1, sample_rate=RATE)
    return decoded.samples


def cut(samples: array.array, start: float, end: float) -> list:
    part = list(samples[int(start * RATE):int(end * RATE)])
    fade = int(FADE * RATE)
    for i in range(max(0, len(part) - fade), len(part)):
        part[i] *= (len(part) - i) / fade
    return part


def write(name: str, samples: list) -> None:
    peak = max(1e-6, max(abs(s) for s in samples))
    gain = 0.89 / peak
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1.0, min(1.0, s * gain)) * 32767)) for s in samples))


if __name__ == "__main__":
    folder = sys.argv[1]
    cache = {}
    for name, (source, start, end) in CUTS.items():
        if source not in cache:
            cache[source] = load(os.path.join(folder, source))
        clip = cut(cache[source], start, end)
        write(name, clip)
        print(f"{name}: {len(clip) / RATE:.2f} s from {source}")
