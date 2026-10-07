"""Makes the AK-47 (Assault Rifle) gunshots assets/audio/shot_ak_1..3.wav from Can's "FREE FPS SFX
Pack" (no ffmpeg needed, standard library only): the body of a shotgun shot with the first crack of
a sniper shot on top, mono, played 22 % faster (higher, tighter, less boom than either), cut to
0.42 s with a fade. Second try (2026-10-07): the first one (sniper only + a synthetic low sine)
sounded wrong to Can.

    python tools/make_ak_shot.py "PATH/TO/FREE FPS SFX Pack.zip"
"""

import io
import os
import struct
import sys
import wave
import zipfile

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "audio")
RATE = 44100
SPEED = 1.22  # Faster playback: higher pitch, shorter tail.
LENGTH = 0.42  # Seconds kept.
FADE = 0.2  # Seconds of fade-out at the end.
CRACK_TIME = 0.05  # Seconds of the sniper's attack laid on top.
CRACK_GAIN = 0.7  # Relative to the body's peak.
SOURCES = [("Shotgun_Shot-001.wav", "Sniper_Shot-001.wav"), ("Shotgun_Shot-002.wav", "Sniper_Shot-002.wav"),
           ("Shotgun_Shot-003.wav", "Sniper_Shot-003.wav")]


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


def layer(body: list, crack: list) -> list:
    """Body with the crack's first CRACK_TIME seconds on top (faded out), both from their attack."""
    body_peak = max(1e-6, max(abs(x) for x in body))
    crack_peak = max(1e-6, max(abs(x) for x in crack))
    n = int(CRACK_TIME * RATE)
    out = list(body)
    for i in range(min(n, len(crack), len(out))):
        out[i] += crack[i] / crack_peak * body_peak * CRACK_GAIN * (1.0 - i / n)
    return out


def shape(samples: list) -> list:
    n = min(len(samples), int(LENGTH * RATE))
    samples = samples[:n]
    fade_from = n - int(FADE * RATE)
    return [s * (1.0 - (i - fade_from) / max(1, n - fade_from)) if i >= fade_from else s for i, s in enumerate(samples)]


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
    for index, (body, crack) in enumerate(SOURCES, 1):
        mixed = layer(trim_start(read_mono(pack.read(body))), trim_start(read_mono(pack.read(crack))))
        clip = shape(speed_up(mixed, SPEED))
        write(f"shot_ak_{index}", clip)
        print(f"shot_ak_{index}: {len(clip) / RATE:.2f} s from {body} + {crack}")
