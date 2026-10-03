"""Builds the intro story video for the Steam page (needs numpy, Pillow, ffmpeg).

Input:  marketing/story/clip_1..6.mp4 (Higgsfield/Kling, 5 s each, silent), assets/audio/music/job.ogg,
        assets/audio/sfx/*.wav, concept/07_key_art_revised.png, assets/fonts/Cairo.ttf
Output: marketing/story/intro_story.mp4 (1920x1080, ~33 s) with music, cartoon gibberish and SFX.
"""
import os, subprocess, wave
import numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageFilter

ROOT = os.path.join(os.path.dirname(__file__), "..")
STORY = os.path.join(ROOT, "marketing", "story")
RATE = 44100
CLIP = 5.0
END_CARD = 3.5
TOTAL = 6 * CLIP + END_CARD
rng = np.random.default_rng(7)


def read_wav(path):
    with wave.open(path) as w:
        data = np.frombuffer(w.readframes(w.getnframes()), dtype="<i2").astype(np.float32) / 32768
        sr = w.getframerate()
    if sr != RATE:
        idx = np.arange(0, len(data), sr / RATE)
        data = np.interp(idx, np.arange(len(data)), data)
    return data


def decode(path):
    out = subprocess.run(["ffmpeg", "-loglevel", "error", "-i", path, "-f", "s16le", "-ac", "1", "-ar", str(RATE), "-"],
                         capture_output=True, check=True).stdout
    return np.frombuffer(out, dtype="<i2").astype(np.float32) / 32768


def gibberish(n_syll, base_pitch, speed=1.0, excited=1.0):
    """Simlish-style babble: noisy consonant + formant-shaped buzzy vowel per syllable."""
    vowels = [(730, 1090), (270, 2290), (300, 870), (530, 1840), (570, 840), (440, 1020)]
    out = []
    for s in range(n_syll):
        f1, f2 = vowels[rng.integers(len(vowels))]
        dur = rng.uniform(0.09, 0.17) / speed
        n = int(dur * RATE)
        t = np.arange(n) / RATE
        contour = base_pitch * (1 + excited * 0.25 * np.sin(np.pi * s / max(1, n_syll - 1)) + rng.uniform(-0.08, 0.12))
        glide = contour * (1 + 0.15 * excited * (t / dur - 0.5))
        ph = 2 * np.pi * np.cumsum(glide) / RATE
        v = np.zeros(n)
        for k in range(1, 25):
            hf = glide.mean() * k
            g = np.exp(-((hf - f1) / 120) ** 2) + 0.7 * np.exp(-((hf - f2) / 180) ** 2) + 0.05
            v += g * np.sin(k * ph)
        v *= np.minimum(1, t / 0.012) * np.minimum(1, (dur - t) / 0.03)
        cons_n = int(0.02 * RATE)
        cons = rng.uniform(-1, 1, cons_n) * np.exp(-np.arange(cons_n) / (0.006 * RATE)) * 0.6
        syl = np.concatenate([cons, v / (np.max(np.abs(v)) + 1e-9)])
        out.append(syl)
        if rng.random() < 0.18:
            out.append(np.zeros(int(0.06 * RATE / speed)))
    return np.concatenate(out) * 0.5


def tone(freqs, dur, decay=0.0, vib=0.0):
    n = int(dur * RATE)
    t = np.arange(n) / RATE
    s = sum(np.sin(2 * np.pi * f * t * (1 + vib * np.sin(2 * np.pi * 6 * t))) for f in freqs)
    return s * np.exp(-t * decay) / len(freqs)


def phone_ring(dur):
    n = int(dur * RATE)
    t = np.arange(n) / RATE
    bell = np.sign(np.sin(2 * np.pi * 20 * t)) * 0.5 + 0.5  # 20 Hz hammer
    gate = (np.mod(t, 0.8) < 0.5).astype(float)
    return (np.sin(2 * np.pi * 900 * t) + 0.6 * np.sin(2 * np.pi * 1300 * t)) * bell * gate * 0.25


def siren(dur):
    n = int(dur * RATE)
    t = np.arange(n) / RATE
    f = 700 + 300 * np.sin(2 * np.pi * 1.2 * t)
    return np.sin(2 * np.pi * np.cumsum(f) / RATE) * 0.22


def horn(dur):
    return tone([392, 494, 587], dur) * np.minimum(1, np.arange(int(dur * RATE)) / 400) * 0.45


def build_audio():
    mix = np.zeros(int(TOTAL * RATE))

    def put(sig, at, gain=1.0):
        i = int(at * RATE)
        sig = sig[: max(0, len(mix) - i)]
        mix[i:i + len(sig)] += sig * gain

    music = decode(os.path.join(ROOT, "assets", "audio", "music", "job.ogg"))
    loops = np.tile(music, int(np.ceil(len(mix) / len(music))))[: len(mix)]
    duck = np.ones(len(mix)) * 0.55
    for a, b in [(10.2, 14.6), (15.2, 17.0)]:  # quieter under the dialogue
        duck[int(a * RATE):int(b * RATE)] = 0.32
    fade = np.minimum(1, np.arange(len(mix)) / (0.8 * RATE)) * np.minimum(1, (len(mix) - np.arange(len(mix))) / (1.5 * RATE))
    mix += loops * duck * fade

    sfx = {n: read_wav(os.path.join(ROOT, "assets", "audio", "sfx", n + ".wav")) for n in ["crash", "thud", "oof", "hup", "boing", "win"]}
    # 1: lazy office — a snore (low wobbly hum)
    put(tone([95, 190], 1.4, vib=0.08) * 0.35, 1.0)
    put(tone([95, 190], 1.4, vib=0.08) * 0.35, 3.0)
    # 2: phone ring, then Stretch falls off the chair
    put(phone_ring(3.2), 5.0)
    put(sfx["boing"], 7.6, 0.8)
    put(sfx["thud"], 8.4, 0.9)
    # 3: phone call — Stretch excited babble, customer panicky babble
    put(gibberish(12, 210, 1.1, 1.4), 10.3, 0.9)
    put(gibberish(8, 330, 1.4, 1.8), 12.6, 0.7)
    # 4: alarm button + siren + "MOOOVE!" + chaos
    put(sfx["thud"], 15.3, 1.0)
    put(siren(4.5), 15.4, 0.8)
    put(gibberish(4, 160, 0.6, 2.0), 15.6, 1.0)
    put(sfx["oof"], 17.2, 0.8)
    put(sfx["boing"], 18.4, 0.7)
    # 5: fire pole, Zoom smashes the vase, Bean breaks the chair
    put(tone([300, 600], 0.9, decay=1.5, vib=0.02) * 0.3, 20.2)  # pole slide
    put(sfx["crash"], 21.6, 1.0)
    put(sfx["crash"], 23.2, 0.7)
    put(sfx["thud"], 23.15, 1.0)
    put(sfx["oof"], 23.3, 1.0)
    put(gibberish(5, 300, 1.6, 1.5), 23.9, 0.6)  # Bean's dizzy mumble
    # 6: truck: horn, siren, cheering babble
    put(horn(0.5), 25.2)
    put(horn(0.4), 25.9)
    put(siren(4.5), 25.3, 0.5)
    put(gibberish(6, 250, 1.3, 2.0), 26.8, 0.6)
    put(sfx["win"], 30.3, 0.8)

    mix /= max(1.0, np.max(np.abs(mix)) / 0.95)
    path = os.path.join(STORY, "intro_audio.wav")
    with wave.open(path, "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes((mix * 32767).astype("<i2").tobytes())
    return path


def end_card():
    art = Image.open(os.path.join(ROOT, "concept", "07_key_art_revised.png")).convert("RGB").resize((1920, 1080))
    art = art.filter(ImageFilter.GaussianBlur(6))
    shade = Image.new("RGB", art.size, (30, 18, 12))
    card = Image.blend(art, shade, 0.45)
    d = ImageDraw.Draw(card)
    font = os.path.join(ROOT, "assets", "fonts", "Cairo.ttf")
    big = ImageFont.truetype(font, 150)
    mid = ImageFont.truetype(font, 64)
    for text, f, y, fill in [("Moving Day Chaos", big, 330, (255, 244, 224)),
                             ("Co-op furniture-moving chaos for 1–4 players", mid, 560, (217, 242, 58)),
                             ("Wishlist on Steam", mid, 700, (255, 244, 224))]:
        w = d.textlength(text, font=f)
        d.text(((1920 - w) / 2, y), text, font=f, fill=fill, stroke_width=8, stroke_fill=(58, 42, 32))
    path = os.path.join(STORY, "end_card.png")
    card.save(path)
    return path


def main():
    audio = build_audio()
    card = end_card()
    inputs = []
    for i in range(1, 7):
        inputs += ["-i", os.path.join(STORY, f"clip_{i}.mp4")]
    inputs += ["-loop", "1", "-t", str(END_CARD), "-i", card, "-i", audio]
    parts = "".join(f"[{i}:v]scale=1920:1080:force_original_aspect_ratio=decrease,pad=1920:1080:(ow-iw)/2:(oh-ih)/2,"
                    f"trim=duration={CLIP},setpts=PTS-STARTPTS,fps=30,format=yuv420p[v{i}];" for i in range(6))
    parts += f"[6:v]scale=1920:1080,fps=30,format=yuv420p,fade=t=in:st=0:d=0.4[v6];"
    parts += "".join(f"[v{i}]" for i in range(7)) + "concat=n=7:v=1:a=0[v]"
    out = os.path.join(STORY, "intro_story.mp4")
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", *inputs, "-filter_complex", parts, "-map", "[v]", "-map", "7:a",
                    "-c:v", "libx264", "-preset", "medium", "-crf", "20", "-c:a", "aac", "-b:a", "192k", "-shortest", out], check=True)
    os.remove(audio)
    print(out, os.path.getsize(out) // 1024, "KB")


if __name__ == "__main__":
    main()
