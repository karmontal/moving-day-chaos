"""Composes the silly background music loops (run: python3 tools/gen_music.py; needs numpy + ffmpeg).

A tiny swing sequencer: oom-pah tuba bass, honky piano chords on the off-beats, a kazoo or
xylophone tune, brushed drums, woodblock and the occasional slide whistle. Loops are seamless
(the tail of every note wraps around to the start). Output: assets/audio/music/*.ogg
"""
import os, subprocess, wave
import numpy as np

RATE = 32000
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "audio", "music")
rng = np.random.default_rng(3)

NOTE = {"C": 0, "C#": 1, "D": 2, "D#": 3, "E": 4, "F": 5, "F#": 6, "G": 7, "G#": 8, "A": 9, "A#": 10, "B": 11}


def freq(name, octave):
    return 440.0 * 2 ** ((NOTE[name] + 12 * (octave + 1) - 69) / 12)


def env(n, attack=0.005, decay=0.2, sustain=0.0, release=0.05):
    t = np.arange(n) / RATE
    a = np.clip(t / attack, 0, 1)
    d = sustain + (1 - sustain) * np.exp(-t / max(decay, 1e-4))
    r = np.clip((n / RATE - t) / release, 0, 1)
    return a * d * r


def tuba(f, dur):
    n = int(dur * RATE)
    t = np.arange(n) / RATE
    wobble = 1 + 0.004 * np.sin(2 * np.pi * 5 * t)
    ph = 2 * np.pi * f * t * wobble
    s = sum(np.sin(ph * k) / k ** 1.4 for k in range(1, 8))
    return s * env(n, 0.02, 0.35, 0.35, 0.06) * 0.55


def piano(fs, dur):
    n = int(dur * RATE)
    t = np.arange(n) / RATE
    s = np.zeros(n)
    for f in fs:
        s += np.sin(2 * np.pi * f * t) + 0.4 * np.sin(4 * np.pi * f * t) + 0.15 * np.sin(6 * np.pi * f * t * 1.002)
    return s * env(n, 0.003, 0.12, 0.05, 0.04) * 0.16


def kazoo(f, dur):
    n = int(dur * RATE)
    t = np.arange(n) / RATE
    vib = 1 + 0.012 * np.sin(2 * np.pi * 6.5 * t) * np.clip(t / 0.15, 0, 1)
    ph = 2 * np.pi * f * np.cumsum(vib) / RATE
    buzz = np.sign(np.sin(ph)) * 0.6 + 0.4 * np.sin(3 * ph)
    # nasal formant: crude two-pole resonance around 1.1 kHz
    out = np.zeros(n)
    y1 = y2 = 0.0
    w = 2 * np.pi * 1100 / RATE
    r = 0.93
    a1, a2 = 2 * r * np.cos(w), -r * r
    for i in range(n):
        y = buzz[i] + a1 * y1 + a2 * y2
        out[i] = y
        y2, y1 = y1, y
    out /= np.max(np.abs(out)) + 1e-9
    return out * env(n, 0.02, 0.6, 0.7, 0.05) * 0.22


def xylo(f, dur):
    n = int(max(dur, 0.35) * RATE)
    t = np.arange(n) / RATE
    s = np.sin(2 * np.pi * f * t) + 0.35 * np.sin(2 * np.pi * f * 4.0 * t) * np.exp(-t * 30)
    return s * np.exp(-t * 9) * env(n, 0.002, 10, 1, 0.02) * 0.32


def kick():
    n = int(0.25 * RATE)
    t = np.arange(n) / RATE
    f = 120 * np.exp(-t * 18) + 45
    return np.sin(2 * np.pi * np.cumsum(f) / RATE) * np.exp(-t * 14) * 0.7


def snare():
    n = int(0.18 * RATE)
    t = np.arange(n) / RATE
    noise = rng.uniform(-1, 1, n)
    noise = noise - np.concatenate(([0], noise[:-1])) * 0.6
    return (noise * 0.5 + 0.3 * np.sin(2 * np.pi * 190 * t)) * np.exp(-t * 22) * 0.35


def hat():
    n = int(0.05 * RATE)
    t = np.arange(n) / RATE
    noise = rng.uniform(-1, 1, n)
    noise = noise - np.concatenate(([0], noise[:-1]))
    return noise * np.exp(-t * 80) * 0.1


def woodblock():
    n = int(0.08 * RATE)
    t = np.arange(n) / RATE
    return np.sin(2 * np.pi * 1200 * t) * np.exp(-t * 60) * 0.25


def slide_whistle(dur, up=True):
    n = int(dur * RATE)
    t = np.arange(n) / RATE
    f = np.linspace(500, 1500, n) if up else np.linspace(1500, 450, n)
    f = f * (1 + 0.01 * np.sin(2 * np.pi * 7 * t))
    return np.sin(2 * np.pi * np.cumsum(f) / RATE) * env(n, 0.03, 10, 1, 0.08) * 0.18


CHORDS = {  # root, chord tones
    "C": ("C", ["C", "E", "G"]), "Am": ("A", ["A", "C", "E"]), "F": ("F", ["F", "A", "C"]),
    "G": ("G", ["G", "B", "D"]), "Dm": ("D", ["D", "F", "A"]), "E7": ("E", ["E", "G#", "D"]),
    "A7": ("A", ["A", "C#", "G"]), "D7": ("D", ["D", "F#", "C"]), "G7": ("G", ["G", "B", "F"]),
}


def render(name, bpm, progression, melody, lead, swing=0.62, whistle=True, drums_busy=False):
    beat = 60.0 / bpm
    bar = beat * 4
    total = int(len(progression) * bar * RATE)
    mix = np.zeros(total)

    def put(sig, at):
        i = int(at * RATE) % total
        end = i + len(sig)
        if end <= total:
            mix[i:end] += sig
        else:  # wrap around: seamless loop
            k = total - i
            mix[i:] += sig[:k]
            mix[:end - total] += sig[k:]

    def eighth(b, k):  # swung eighth-note position in beats
        return b + (swing if k else 0.0)

    for bi, ch in enumerate(progression):
        root, tones = CHORDS[ch]
        t0 = bi * bar
        fifth = tones[2] if ch not in ("E7", "A7", "D7", "G7") else tones[1]
        # oom-pah: bass on 1 and 3, chord stabs on 2 and 4
        put(tuba(freq(root, 2), beat * 0.9), t0)
        put(tuba(freq(fifth, 2) / (2 if NOTE[fifth] > 7 else 1), beat * 0.9), t0 + 2 * beat)
        for b in (1, 3):
            put(piano([freq(n, 4) for n in tones], beat * 0.5), t0 + b * beat)
        # drums
        put(kick(), t0)
        put(kick(), t0 + 2 * beat)
        put(snare(), t0 + beat)
        put(snare(), t0 + 3 * beat)
        for b in range(4):
            for k in (0, 1):
                put(hat(), t0 + eighth(b, k) * beat)
        if drums_busy:
            put(kick(), t0 + eighth(3, 1) * beat)
        if bi % 2 == 1:
            put(woodblock(), t0 + eighth(3, 1) * beat)
            put(woodblock(), t0 + 3.5 * beat + 0.12)

    # melody: list of (bar, beat, note, octave, length_in_beats); beats may be x.5 (swung)
    for bar_i, b, n, octv, length in melody:
        whole = int(b)
        pos = eighth(whole, 1) if b - whole >= 0.5 else b
        f = freq(n, octv)
        sig = kazoo(f, length * beat * 0.95) if lead == "kazoo" else xylo(f, length * beat)
        put(sig, bar_i * bar + pos * beat)

    if whistle:
        put(slide_whistle(beat * 1.5, up=True), (len(progression) - 1) * bar + 2.3 * beat)

    mix /= np.max(np.abs(mix)) + 1e-9
    mix *= 0.85
    os.makedirs(OUT, exist_ok=True)
    wav = os.path.join(OUT, name + ".wav")
    with wave.open(wav, "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes((mix * 32767).astype("<i2").tobytes())
    ogg = os.path.join(OUT, name + ".ogg")
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav, "-c:a", "libvorbis", "-q:a", "4", ogg], check=True)
    os.remove(wav)
    print(f"{ogg}: {len(progression) * bar:.1f}s, {os.path.getsize(ogg) // 1024} KB")


def phrase(start_bar, notes):
    """notes: list of (beat_in_phrase, note, octave, length) where beats run across bars."""
    out = []
    for beat, n, o, l in notes:
        out.append((start_bar + int(beat // 4), beat % 4, n, o, l))
    return out


# A goofy, sneaky tune (think "pink sofa going down the stairs").
A = [(0, "E", 5, 0.5), (0.5, "G", 5, 0.5), (1, "A", 5, 1), (2.5, "G", 5, 0.5), (3, "E", 5, 1),
     (4, "D", 5, 0.5), (4.5, "E", 5, 0.5), (5, "C", 5, 1.5), (7, "A", 4, 1),
     (8, "C", 5, 0.5), (8.5, "D", 5, 0.5), (9, "E", 5, 0.5), (9.5, "G", 5, 0.5), (10, "A", 5, 1), (11, "C", 6, 1),
     (12, "B", 5, 0.5), (12.5, "A", 5, 0.5), (13, "G", 5, 2.5)]
B = [(0, "F", 5, 1), (1, "A", 5, 0.5), (1.5, "F", 5, 0.5), (2, "C", 5, 1.5),
     (4, "G", 5, 0.5), (4.5, "F", 5, 0.5), (5, "E", 5, 0.5), (5.5, "D", 5, 0.5), (6, "C", 5, 1.5),
     (8, "D", 5, 0.5), (8.5, "E", 5, 0.5), (9, "F", 5, 1), (10, "A", 5, 0.5), (10.5, "G#", 5, 0.5), (11, "A", 5, 1),
     (12, "B", 5, 1), (13, "D", 6, 0.5), (13.5, "B", 5, 0.5), (14, "G", 5, 1.5)]

job_prog = ["C", "Am", "Dm", "G7"] * 2 + ["F", "C", "D7", "G7"] + ["C", "A7", "Dm", "G7"]
job_mel = phrase(0, A) + phrase(4, A) + phrase(8, B) + phrase(12, A)
render("job", 126, job_prog, job_mel, "kazoo")

menu_prog = ["C", "Am", "F", "G7"] * 2
render("menu", 100, menu_prog, phrase(0, A) + phrase(4, B), "xylo", whistle=False)

hurry_prog = ["C", "A7", "Dm", "G7"] * 2
render("hurry", 168, hurry_prog, phrase(0, A) + phrase(4, A), "kazoo", drums_busy=True)
