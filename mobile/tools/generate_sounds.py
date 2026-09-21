"""Generates the two short UI sounds used when a task / a whole day is completed."""
import math
import os
import struct
import wave

OUT = r"C:\Users\Muhammadumar\OneDrive\Desktop\App\mobile\assets\sounds"
os.makedirs(OUT, exist_ok=True)
RATE = 44100


def tone(freq, dur, vol=0.5, attack=0.006, decay=6.0, harmonics=((1, 1.0), (2, 0.28), (3, 0.1))):
    """A soft bell-like note: sine + gentle overtones, fast attack, exponential decay."""
    n = int(RATE * dur)
    out = []
    for i in range(n):
        t = i / RATE
        env = min(1.0, t / attack) * math.exp(-decay * t)
        s = sum(a * math.sin(2 * math.pi * freq * h * t) for h, a in harmonics)
        out.append(vol * env * s / 1.4)
    return out


def mix(tracks, total):
    buf = [0.0] * int(RATE * total)
    for start, samples in tracks:
        off = int(RATE * start)
        for i, v in enumerate(samples):
            if off + i < len(buf):
                buf[off + i] += v
    return buf


def save(name, samples):
    peak = max(1e-9, max(abs(x) for x in samples))
    scale = min(1.0, 0.85 / peak)
    with wave.open(os.path.join(OUT, name), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, x * scale)) * 32767)) for x in samples))


# Task done: a quick two-note "pop-ding" (E5 -> B5)
save("task_done.wav", mix([(0.0, tone(659.25, 0.28, 0.5, decay=9)), (0.07, tone(987.77, 0.42, 0.55, decay=7))], 0.5))

# Day complete: rising arpeggio C5 E5 G5 C6 with a final shimmer
notes = [523.25, 659.25, 783.99, 1046.5]
tracks = [(i * 0.09, tone(f, 0.6, 0.5, decay=5)) for i, f in enumerate(notes)]
tracks.append((0.4, tone(1567.98, 0.7, 0.25, decay=4)))
save("day_complete.wav", mix(tracks, 1.2))
print("sounds written to", OUT)
