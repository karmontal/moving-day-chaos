# صور صفحات المتجر (Steam + itch.io)

الرسومات مولّدة بـ Higgsfield (`gpt_image_2_5` بمرجع الـ key art `6ebd8ecf…` وتصميم الشخصيات `2b5f3f40…`)،
ومكبّرة بـ Higgsfield upscale. الشعار مولّد بـ Higgsfield ومقصوص الخلفية بـ Higgsfield.
كل الأحجام بتنبني من `source/` بأمر واحد:

```
python3 tools/make_store_assets.py
```

| المجلد | المحتوى |
|---|---|
| `source/` | `art_wide.jpg` (16:9)، `art_tall.jpg` (2:3)، `art_pano.jpg` (عريضة)، `logo.png` (شعار شفاف) |
| `steam/` | header 920×430، small 462×174، main 1232×706، vertical 748×896، library capsule 600×900، library header 920×430، library hero 3840×1240، library logo 1280×720، page background 1438×810 |
| `itch/` | cover 630×500، banner 960×300، background 1920×1080 |
| `screenshots/` | 8 لقطات من داخل اللعبة 1920×1080 (`tools/screenshot.gd`) |

| Higgsfield job | الملف |
|---|---|
| `2f60ce31-f2a0-406c-8264-5023e6ef094c` → upscale `49b1951e…` | art_wide |
| `2d7983e5-cec8-433d-a1cf-b68e7a14f03b` → upscale `d38af316…` | art_tall |
| `9b2579bd-89e3-4d6c-950b-12b694b1ec68` → upscale `032c2a73…` | art_pano |
| `243c1f52-c550-4e59-acf2-48d4691c8f00` → قص الخلفية `e6c559ed…` | logo |
