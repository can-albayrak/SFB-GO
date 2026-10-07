"""Generates the procedural sound effects in assets/audio (rifle, light, rail, hit, hit_head, kill).
Run: python tools/gen_sfx.py [name ...]  (names: only those files, e.g. dice dice_good)"""
import math
import os
import random
import struct
import sys
import wave

RATE = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "audio")


def write(name, samples):
    if len(sys.argv) > 1 and name not in sys.argv[1:]:
        return
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
    # Railgun: falling zap over a hiss.
    n = int(0.7 * RATE)
    zap, phase = [], 0.0
    for i in range(n):
        t = i / RATE
        phase += 2.0 * math.pi * (1800.0 * math.exp(-t * 6.0) + 120.0) / RATE
        zap.append((math.sin(phase) + 0.4 * math.sin(phase * 2.01)) * math.exp(-t / 0.18))
    hiss = [a * b * 0.5 for a, b in zip(lowpass(noise(0.7), 5000), env(n, 0.001, 0.12))]
    write("shot_rail", mix(zap, hiss, thump(0.7, 200, 50, 0.15, 0.6)))
    # Shotgun, sniper/heavy, launcher, explosion, footsteps and landing come from the recorded
    # "FREE FPS SFX Pack" now (tools/convert_sfx_pack.sh).
    # Hit marker tick and kill ding.
    write("hit", [math.sin(2 * math.pi * 1400 * i / RATE) * math.exp(-i / (0.03 * RATE)) for i in range(int(0.1 * RATE))])
    # Headshot ding: a bright, metallic ping.
    write("hit_head", [(math.sin(2 * math.pi * 2600 * i / RATE) + 0.6 * math.sin(2 * math.pi * 3900 * i / RATE)) * math.exp(-i / (0.045 * RATE))
        + 0.5 * math.sin(2 * math.pi * 1300 * i / RATE) * math.exp(-i / (0.09 * RATE)) for i in range(int(0.22 * RATE))])
    write("kill", [(math.sin(2 * math.pi * 1046 * i / RATE) + 0.5 * math.sin(2 * math.pi * 1568 * i / RATE)) * math.exp(-i / (0.18 * RATE)) for i in range(int(0.5 * RATE))])
    # Knife swing and draw are recorded clips now (docs/ASSETS.md).
    # Silenced shot: a short muffled "pfft" (no boom), a mechanical click on top.
    n = noise(0.18)
    puff = [a * b for a, b in zip(lowpass(n, 900), env(len(n), 0.001, 0.035))]
    click = [a * b * 0.4 for a, b in zip(noise(0.18), env(len(n), 0.0005, 0.006))]
    write("shot_suppressed", mix([p * 2.0 for p in puff], click, thump(0.18, 180, 90, 0.03, 0.4)))
    # Sonar: a clear ping with a falling echo.
    write("sonar", [(math.sin(2 * math.pi * 1250 * i / RATE) * math.exp(-i / (0.25 * RATE))
        + 0.4 * math.sin(2 * math.pi * 1250 * i / RATE) * math.exp(-max(0, i - int(0.22 * RATE)) / (0.2 * RATE)) * (1 if i > 0.22 * RATE else 0))
        for i in range(int(0.9 * RATE))])
    # Dart: a short breathy blow.
    n = int(0.22 * RATE)
    write("dart", [a * math.sin(math.pi * i / n) ** 2 for i, a in enumerate(lowpass(noise(0.22), 2500))])
    # Teleport: rising shimmer.
    n = int(0.45 * RATE)
    tone, phase = [], 0.0
    for i in range(n):
        t = i / RATE
        phase += 2 * math.pi * (300 + 1500 * t / 0.45) / RATE
        tone.append(math.sin(phase) * math.sin(math.pi * i / n) * (0.6 + 0.4 * math.sin(2 * math.pi * 30 * t)))
    write("teleport", mix(tone, [a * 0.3 * math.sin(math.pi * i / n) for i, a in enumerate(lowpass(noise(0.45), 4000))]))
    # Cloak: falling airy whoosh.
    n = int(0.5 * RATE)
    write("cloak", [a * math.sin(math.pi * i / n) * (1.0 - i / n) for i, a in enumerate(lowpass(noise(0.5), 1800))])
    # Dice: rattle of clacks that slow down (Gambler's roll).
    rattle = [0.0] * int(0.7 * RATE)
    t = 0.0
    gap = 0.035
    while t < 0.62:
        start = int(t * RATE)
        clack = [a * math.exp(-i / (0.004 * RATE)) for i, a in enumerate(lowpass(noise(0.03), 5000))]
        for i, a in enumerate(clack):
            if start + i < len(rattle):
                rattle[start + i] += a * (1.0 - t)
        t += gap
        gap *= 1.25
    write("dice", rattle)
    # Dice results: two rising notes (good), two falling (bad).
    def notes(freqs):
        out = []
        for f in freqs:
            n = int(0.14 * RATE)
            out += [math.sin(2 * math.pi * f * i / RATE) * math.sin(math.pi * i / n) for i in range(n)]
        return out
    write("dice_good", notes([660, 990]))
    write("dice_bad", notes([330, 220]))


if __name__ == "__main__":
    main()
