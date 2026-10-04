#!/usr/bin/env python3
"""Builds every Steam / itch.io store image from the Higgsfield art in marketing/store/source.

art_wide.jpg (16:9 key art), art_tall.jpg (2:3 poster), art_pano.jpg (ultra-wide), logo.png
(transparent title). Run from the repo root: python3 tools/make_store_assets.py
"""
from PIL import Image, ImageFilter, ImageEnhance

SRC = "marketing/store/source/"
OUT = "marketing/store/"

wide = Image.open(SRC + "art_wide.jpg").convert("RGB")
tall = Image.open(SRC + "art_tall.jpg").convert("RGB")
pano = Image.open(SRC + "art_pano.jpg").convert("RGB")
logo = Image.open(SRC + "logo.png").convert("RGBA")
logo = logo.crop(logo.getbbox())


def cover(img, w, h, fx=0.5, fy=0.5):
    """Scale to fill w x h, then crop around the focus point (fx, fy as 0..1 of the spare room)."""
    s = max(w / img.width, h / img.height)
    r = img.resize((round(img.width * s), round(img.height * s)), Image.LANCZOS)
    x = round((r.width - w) * fx)
    y = round((r.height - h) * fy)
    return r.crop((x, y, x + w, y + h))


def stamp(base, width_frac, cx=0.5, top=0.04):
    """Logo with a soft dark shadow, width_frac of the image wide, centred at cx, top margin as a fraction."""
    base = base.convert("RGBA")
    lw = round(base.width * width_frac)
    lg = logo.resize((lw, round(logo.height * lw / logo.width)), Image.LANCZOS)
    x = round(base.width * cx - lw / 2)
    y = round(base.height * top)
    shadow = Image.new("RGBA", lg.size, (40, 25, 15, 0))
    shadow.putalpha(lg.getchannel("A").point(lambda a: a * 0.55))
    blur = max(2, lw // 60)
    pad = blur * 3
    sh = Image.new("RGBA", (lg.width + pad * 2, lg.height + pad * 2), (0, 0, 0, 0))
    sh.paste(shadow, (pad, pad))
    sh = sh.filter(ImageFilter.GaussianBlur(blur))
    base.alpha_composite(sh, (x - pad + blur, y - pad + blur * 2))
    base.alpha_composite(lg, (x, y))
    return base.convert("RGB")


def save(img, path):
    img.save(OUT + path, optimize=True)
    print(path, img.size)


# --- Steam store capsules (logo required, nothing else written on them).
save(stamp(cover(wide, 920, 430, 0.5, 0.45), 0.45, 0.47, 0.02), "steam/header_capsule_920x430.png")
save(stamp(cover(wide, 920, 430, 0.5, 0.45), 0.45, 0.47, 0.02), "steam/library_header_920x430.png")
small = cover(wide, 462, 174, 0.5, 0.3)
small = ImageEnhance.Brightness(small.filter(ImageFilter.GaussianBlur(1.5))).enhance(0.85)
save(stamp(small, 0.62, 0.5, 0.06), "steam/small_capsule_462x174.png")
save(stamp(cover(wide, 1232, 706, 0.5, 0.5), 0.42, 0.47, 0.02), "steam/main_capsule_1232x706.png")
save(stamp(cover(tall, 748, 896, 0.5, 0.0), 0.8, 0.5, 0.025), "steam/vertical_capsule_748x896.png")
save(stamp(cover(tall, 600, 900, 0.5, 0.0), 0.82, 0.5, 0.025), "steam/library_capsule_600x900.png")
# Library hero: art only (Steam puts the logo on top of it).
save(cover(pano, 3840, 1240, 0.5, 0.45), "steam/library_hero_3840x1240.png")
lib_logo = Image.new("RGBA", (1280, 720), (0, 0, 0, 0))
lg = logo.copy()
lg.thumbnail((1240, 680), Image.LANCZOS)
lib_logo.alpha_composite(lg, ((1280 - lg.width) // 2, (720 - lg.height) // 2))
lib_logo.save(OUT + "steam/library_logo_1280x720.png", optimize=True)
print("steam/library_logo_1280x720.png", lib_logo.size)
bg = ImageEnhance.Brightness(cover(wide, 1438, 810).filter(ImageFilter.GaussianBlur(6))).enhance(0.6)
save(bg, "steam/page_background_1438x810.png")

# --- itch.io.
save(stamp(cover(wide, 630, 500, 0.45, 0.4), 0.7, 0.5, 0.03), "itch/cover_630x500.png")
save(stamp(cover(pano, 960, 300, 0.5, 0.0), 0.3, 0.5, 0.03), "itch/banner_960x300.png")
save(ImageEnhance.Brightness(cover(wide, 1920, 1080).filter(ImageFilter.GaussianBlur(4))).enhance(0.9), "itch/background_1920x1080.png")
