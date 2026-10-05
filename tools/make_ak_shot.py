"""Makes the AK-47 (Assault Rifle) gunshots assets/audio/shot_ak_1..3.wav from the sniper shots of
Can's "FREE FPS SFX Pack" (no ffmpeg needed, standard library only): mono, played 12 % faster
(a shorter, higher crack than the sniper), cut to 0.55 s with a fade, a short low punch added
under the attack so it lands "tok".

    python tools/make_ak_shot.py "PATH/TO/FREE FPS SFX Pack.zip"
"""

import io
import math
import os
import struct
import sys
import wave
import zipfile

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "audio")
RATE = 44100
SPEED = 1.12  # Faster playback: higher pitch, shorter tail.
LENGTH = 0.55  # Seconds kept.
FADE = 0.25  # Seconds of fade-out at the end.
PUNCH_FREQ = 72.0  # Hz of the low punch.
PUNCH_DECAY = 0.045  # Seconds.
PUNCH_AMP = 0.45  # Relative to the clip's peak.
SOURCES = ["Sniper_Shot-001.wav", "Sniper_Shot-002.wav", "Sniper_Shot-003.wav"]


def read_mono(data: bytes) -> list:
    w = wave.open(io.BytesIO(data))
    channels, width, frames = w.getnchannels(), w.getsampwidth(), w.readframes(w.getnframes())
    assert w.getframerate() == RATE, "expected 44.1 kHz"
    full = float(1 << (8 * width - 1))
    out = []
    step = channels * width
    for i in range(0, len(frames) - step + 1, step):
        total = 0.0
        for c in range(channels):
            raw = frames[i + c * width:i + (c + 1) * width]
            if width == 1:
                value = raw[0] - 128
            else:
                value = int.from_bytes(raw, "little", signed=True)
            total += value / full
        out.append(total / channels)
    return out


def trim_start(samples: list, threshold: float = 0.003) -> list:
    for i, s in enumerate(samples):
        if abs(s) > threshold:
            return samples[i:]
    return samples


def speed_up(samples: list, factor: float) -> list:
    out, pos = [], 0.0
    while pos < len(samples) - 1:
        i = int(pos)
        frac = pos - i
        out.append(samples[i] * (1.0 - frac) + samples[i + 1] * frac)
        pos += factor
    return out


def shape(samples: list) -> list:
    n = min(len(samples), int(LENGTH * RATE))
    samples = samples[:n]
    fade_from = n - int(FADE * RATE)
    peak = max(1e-6, max(abs(s) for s in samples))
    out = []
    phase = 0.0
    for i, s in enumerate(samples):
        t = i / RATE
        phase += 2.0 * math.pi * (PUNCH_FREQ * (1.0 + 2.0 * math.exp(-t * 40.0))) / RATE
        s += math.sin(phase) * math.exp(-t / PUNCH_DECAY) * PUNCH_AMP * peak
        if i >= fade_from:
            s *= 1.0 - (i - fade_from) / max(1, n - fade_from)
        out.append(s)
    return out


def write(name: str, samples: list) -> None:
    peak = max(1e-6, max(abs(s) for s in samples))
    gain = 0.89 / peak
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1.0, min(1.0, s * gain)) * 32767)) for s in samples))


if __name__ == "__main__":
    pack = zipfile.ZipFile(sys.argv[1])
    for index, source in enumerate(SOURCES, 1):
        clip = shape(speed_up(trim_start(read_mono(pack.read(source))), SPEED))
        write(f"shot_ak_{index}", clip)
        print(f"shot_ak_{index}: {len(clip) / RATE:.2f} s from {source}")
