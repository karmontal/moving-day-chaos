"""Generates the tileable environment textures in assets/textures (run: python3 tools/gen_textures.py).

Most are near-white so the game tints them per house with the material colour: siding, brick,
roof shingles, wallpaper. Asphalt and pavers are used as they are. All tile seamlessly.
"""
import os
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

S = 256
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "textures")
rng = np.random.default_rng(7)


def save(name, arr):
    os.makedirs(OUT, exist_ok=True)
    arr = np.clip(arr, 0, 1)
    if arr.ndim == 2:
        arr = np.stack([arr] * 3, -1)
    Image.fromarray((arr * 255).astype(np.uint8)).save(os.path.join(OUT, name + ".png"))


def noise(cells, amount):
    """Smooth tileable value noise in [-amount, amount] (bilinear over a wrapped grid)."""
    grid = rng.random((cells, cells))
    t = np.arange(S) / S * cells
    i0 = np.floor(t).astype(int) % cells
    i1 = (i0 + 1) % cells
    f = t - np.floor(t)
    f = f * f * (3 - 2 * f)
    rows = grid[i0][:, i0] * (1 - f)[None, :] + grid[i0][:, i1] * f[None, :]
    rows2 = grid[i1][:, i0] * (1 - f)[None, :] + grid[i1][:, i1] * f[None, :]
    a = rows * (1 - f)[:, None] + rows2 * f[:, None]
    a = (a - a.mean()) / max(1e-6, np.ptp(a))
    return a * 2 * amount


def siding():
    """Horizontal clapboards: 8 boards, each lit at the top and shadowed under its lip."""
    y = np.arange(S)[:, None] / S * 8 % 1.0
    board = 0.98 - 0.09 * y
    board = np.where(y > 0.92, 0.7, board)           # shadow line under each board
    board = np.where(y < 0.04, 1.0, board)           # bright lip
    save("siding", np.broadcast_to(board, (S, S)) + noise(32, 0.02))


def brick():
    img = np.full((S, S), 0.98)
    rows, cols = 8, 4
    bh, bw = S // rows, S // cols
    for r in range(rows):
        shift = bw // 2 if r % 2 else 0
        for c in range(cols + 1):
            x0 = c * bw - shift
            tone = rng.uniform(0.76, 0.9)
            for x in range(x0 + 3, x0 + bw - 3):
                img[r * bh + 3: r * bh + bh - 3, x % S] = tone
    img = np.asarray(Image.fromarray((img * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(0.8)), float) / 255
    save("brick", img + noise(32, 0.025))


def shingles():
    """Rounded roof tiles in staggered rows (cartoon scallops)."""
    im = Image.new("L", (S, S), 150)
    d = ImageDraw.Draw(im)
    rows, cols = 8, 8
    th, tw = S // rows, S // cols
    for r in range(rows + 1):
        shift = tw // 2 if r % 2 else 0
        for c in range(-1, cols + 1):
            x0 = c * tw + shift
            y0 = r * th - th // 2
            tone = int(rng.uniform(215, 250))
            for ox in (0, -S, S):
                for oy in (0, -S, S):
                    d.rounded_rectangle([x0 + 2 + ox, y0 + oy, x0 + tw - 2 + ox, y0 + th + th // 2 - 2 + oy],
                                        radius=tw // 2, fill=tone, outline=170, width=2)
    save("shingles", np.asarray(im.filter(ImageFilter.GaussianBlur(0.6)), float) / 255)


def wallpaper_stripes():
    x = np.arange(S)[None, :] / S * 8 % 1.0
    v = np.where(x < 0.5, 1.0, 0.92)
    v = np.where((x > 0.24) & (x < 0.26), 0.86, v)
    save("wallpaper_stripes", np.broadcast_to(v, (S, S)) + noise(16, 0.01))


def wallpaper_dots():
    im = Image.new("L", (S, S), 255)
    d = ImageDraw.Draw(im)
    step = S // 8
    for r in range(9):
        for c in range(-1, 9):
            cx = c * step + (step // 2 if r % 2 else 0)
            cy = r * step
            for ox in (0, -S, S):
                for oy in (0, -S):
                    d.ellipse([cx - 6 + ox, cy - 6 + oy, cx + 6 + ox, cy + 6 + oy], fill=222)
    save("wallpaper_dots", np.asarray(im, float) / 255)


def asphalt():
    base = 0.42 + noise(16, 0.03) + noise(64, 0.02)
    specks = rng.random((S, S))
    base = np.where(specks > 0.985, base + 0.12, base)
    base = np.where(specks < 0.01, base - 0.08, base)
    save("asphalt", np.stack([base, base, base * 1.06], -1))


def pavers():
    v = np.full((S, S), 0.88)
    step = S // 4
    idx = np.arange(S)
    for r in range(4):
        for c in range(4):
            v[r * step:(r + 1) * step, c * step:(c + 1) * step] += rng.uniform(-0.03, 0.03)
    v[:, idx % step < 3] = 0.72
    v[idx % step < 3, :] = 0.72
    v = v + noise(32, 0.015)
    save("pavers", np.stack([v, v * 0.98, v * 0.95], -1))


if __name__ == "__main__":
    siding()
    brick()
    shingles()
    wallpaper_stripes()
    wallpaper_dots()
    asphalt()
    pavers()
    print("textures written to", os.path.abspath(OUT))
