"""Generates the placeholder SFX in assets/audio/sfx (run: python3 tools/gen_sfx.py)."""
import math, random, struct, wave, os

RATE = 44100
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "audio", "sfx")


def write(name, samples):
    os.makedirs(OUT, exist_ok=True)
    peak = max(1e-9, max(abs(s) for s in samples))
    with wave.open(os.path.join(OUT, name + ".wav"), "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", int(s / peak * 0.85 * 32767)) for s in samples))


def tone(freqs, dur, decay, attack=0.002, noise=0.0, sweep=0.0):
    out = []
    for i in range(int(RATE * dur)):
        t = i / RATE
        env = min(1.0, t / attack) * math.exp(-t * decay)
        s = sum(a * math.sin(2 * math.pi * f * (1 + sweep * t) * t) for f, a in freqs)
        if noise:
            s += noise * (random.random() * 2 - 1)
        out.append(s * env)
    return out


def noise_burst(dur, decay, lowpass=0.5):
    out, prev = [], 0.0
    for i in range(int(RATE * dur)):
        t = i / RATE
        prev = prev * lowpass + (random.random() * 2 - 1) * (1 - lowpass)
        out.append(prev * math.exp(-t * decay))
    return out


def concat(*parts):
    return [s for p in parts for s in p]


def mix(*parts):
    n = max(len(p) for p in parts)
    return [sum(p[i] for p in parts if i < len(p)) for i in range(n)]


random.seed(7)
# Rubbery grab "boop" and a softer release.
write("grab", tone([(420, 1.0), (840, 0.3)], 0.12, 30, sweep=1.5))
write("release", tone([(520, 1.0), (260, 0.4)], 0.1, 35, sweep=-1.2))
# Furniture thud: low sine plus a muffled noise burst.
write("thud", mix(tone([(70, 1.0), (110, 0.5)], 0.3, 14), [s * 0.6 for s in noise_burst(0.2, 25, 0.85)]))
# Crash: bright glassy noise with ringing partials.
write("crash", mix(noise_burst(0.7, 6, 0.2), tone([(2300, 0.35), (3100, 0.25), (4200, 0.2)], 0.7, 7, noise=0.1)))
write("jump", tone([(300, 1.0)], 0.18, 14, sweep=3.0))
# Delivered: cheerful two-note "ding-dong".
write("delivered", concat(tone([(880, 1.0), (1760, 0.25)], 0.12, 10), tone([(1175, 1.0), (2350, 0.25)], 0.3, 8)))
write("click", tone([(1200, 1.0)], 0.05, 70))
write("tick", tone([(1500, 1.0)], 0.06, 50))
write("error", tone([(180, 1.0), (190, 0.8)], 0.25, 9))
write("win", concat(*[tone([(f, 1.0), (f * 2, 0.3)], 0.16, 9) for f in (523, 659, 784)], tone([(1047, 1.0), (1568, 0.4)], 0.6, 4)))
write("lose", concat(*[tone([(f, 1.0), (f * 1.5, 0.2)], 0.25, 6) for f in (392, 349, 311)], tone([(262, 1.0)], 0.6, 3)))


def voice(f0_start, f0_end, dur, formants, decay=4.0):
    """Cartoon gibberish: a pitch-gliding buzz shaped by vowel formants (list of (freq, gain))."""
    out, phase = [], 0.0
    n = int(RATE * dur)
    for i in range(n):
        t = i / RATE
        f0 = f0_start + (f0_end - f0_start) * (i / n)
        phase += 2 * math.pi * f0 / RATE
        s = 0.0
        for k in range(1, 30):
            hf = f0 * k
            g = sum(a * math.exp(-((hf - fc) / 140.0) ** 2) for fc, a in formants)
            s += g * math.sin(phase * k) / k ** 0.3
        env = min(1.0, t / 0.015) * math.exp(-t * decay) * min(1.0, (dur - t) / 0.03)
        out.append(s * env)
    return out


write("hup", voice(260, 420, 0.18, [(700, 1.0), (1200, 0.6)], 6))       # "hup!"
write("oof", voice(300, 150, 0.32, [(450, 1.0), (850, 0.5)], 3))        # "oof"
write("boing", tone([(160, 1.0), (320, 0.3)], 0.35, 7, sweep=2.5))       # rubbery landing
print("done")
