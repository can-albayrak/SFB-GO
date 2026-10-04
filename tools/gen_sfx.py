"""Generates the placeholder sound effects in assets/audio (procedural, no samples).
Run: python tools/gen_sfx.py"""
import math
import os
import random
import struct
import wave

RATE = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "audio")


def write(name, samples):
    peak = max(1e-6, max(abs(s) for s in samples))
    gain = 0.89 / peak
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1.0, min(1.0, s * gain)) * 32767)) for s in samples))


def lowpass(samples, cutoff):
    rc = 1.0 / (2.0 * math.pi * cutoff)
    a = (1.0 / RATE) / (rc + 1.0 / RATE)
    out, y = [], 0.0
    for s in samples:
        y += a * (s - y)
        out.append(y)
    return out


def noise(seconds):
    return [random.uniform(-1.0, 1.0) for _ in range(int(seconds * RATE))]


def env(n, attack, decay):
    return [min(1.0, i / max(1, attack * RATE)) * math.exp(-i / (decay * RATE)) for i in range(n)]


def mix(*tracks):
    n = max(len(t) for t in tracks)
    return [sum(t[i] if i < len(t) else 0.0 for t in tracks) for i in range(n)]


def thump(seconds, f0, f1, decay, amp=1.0):
    n = int(seconds * RATE)
    out, phase = [], 0.0
    for i in range(n):
        t = i / RATE
        f = f1 + (f0 - f1) * math.exp(-t * 30.0)
        phase += 2.0 * math.pi * f / RATE
        out.append(math.sin(phase) * math.exp(-t / decay) * amp)
    return out


def gunshot(seconds, cutoff, decay, boom_freq, boom_amp):
    n = noise(seconds)
    crack = [a * b for a, b in zip(n, env(len(n), 0.001, decay * 0.25))]
    body = [a * b for a, b in zip(lowpass(n, cutoff), env(len(n), 0.002, decay))]
    return mix(crack, [s * 1.6 for s in body], thump(seconds, boom_freq * 3.0, boom_freq, decay * 1.2, boom_amp))


def main():
    random.seed(7)
    os.makedirs(OUT, exist_ok=True)
    write("shot_light", gunshot(0.25, 2600, 0.05, 110, 0.5))
    write("shot_rifle", gunshot(0.35, 1800, 0.07, 80, 0.8))
    write("shot_heavy", gunshot(0.5, 1200, 0.11, 60, 1.0))
    write("shot_shotgun", gunshot(0.6, 900, 0.14, 55, 1.2))
    # Railgun: falling zap over a hiss.
    n = int(0.7 * RATE)
    zap, phase = [], 0.0
    for i in range(n):
        t = i / RATE
        phase += 2.0 * math.pi * (1800.0 * math.exp(-t * 6.0) + 120.0) / RATE
        zap.append((math.sin(phase) + 0.4 * math.sin(phase * 2.01)) * math.exp(-t / 0.18))
    hiss = [a * b * 0.5 for a, b in zip(lowpass(noise(0.7), 5000), env(n, 0.001, 0.12))]
    write("shot_rail", mix(zap, hiss, thump(0.7, 200, 50, 0.15, 0.6)))
    # Launcher: thump plus a rising whoosh.
    n = int(0.7 * RATE)
    whoosh = [a * math.sin(math.pi * i / n) * 0.8 for i, a in enumerate(lowpass(noise(0.7), 700))]
    write("shot_launcher", mix(thump(0.7, 160, 45, 0.12, 1.0), whoosh, gunshot(0.3, 1500, 0.05, 70, 0.3)))
    # Explosion: long low rumble.
    n = noise(1.8)
    rumble = [a * b for a, b in zip(lowpass(lowpass(n, 400), 300), env(len(n), 0.003, 0.45))]
    crack = [a * b * 0.6 for a, b in zip(lowpass(n, 3000), env(len(n), 0.001, 0.05))]
    write("explosion", mix([s * 3.0 for s in rumble], crack, thump(1.8, 120, 30, 0.35, 1.4)))
    # Footsteps: short soft scuffs, three variants.
    for k in range(3):
        n = noise(0.12)
        step = [a * b for a, b in zip(lowpass(n, 700 + 250 * k), env(len(n), 0.004, 0.025))]
        write("step_%d" % (k + 1), mix([s * 2.0 for s in step], thump(0.12, 140, 70 + 10 * k, 0.03, 0.5)))
    n = noise(0.25)
    write("land", mix([a * b * 2.0 for a, b in zip(lowpass(n, 500), env(len(n), 0.003, 0.06))], thump(0.25, 120, 50, 0.07, 0.9)))
    # Hit marker tick and kill ding.
    write("hit", [math.sin(2 * math.pi * 1400 * i / RATE) * math.exp(-i / (0.03 * RATE)) for i in range(int(0.1 * RATE))])
    write("kill", [(math.sin(2 * math.pi * 1046 * i / RATE) + 0.5 * math.sin(2 * math.pi * 1568 * i / RATE)) * math.exp(-i / (0.18 * RATE)) for i in range(int(0.5 * RATE))])
    # Melee swing: band-passed whoosh.
    n = int(0.25 * RATE)
    write("swing", [a * math.sin(math.pi * i / n) for i, a in enumerate(lowpass(noise(0.25), 1500))])


if __name__ == "__main__":
    main()
