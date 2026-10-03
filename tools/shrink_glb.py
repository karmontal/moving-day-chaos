"""Shrinks the embedded textures of a .glb (generated models ship 4K JPEGs; phones need ~1K).
Usage: python3 tools/shrink_glb.py assets/models/mover_0.glb [max_size]"""
import io, json, struct, sys
from PIL import Image


def shrink(path, max_size=1024):
    data = open(path, "rb").read()
    json_len = struct.unpack("<I", data[12:16])[0]
    gltf = json.loads(data[20:20 + json_len])
    bin_start = 20 + json_len + 8
    bin_len = struct.unpack("<I", data[20 + json_len:24 + json_len])[0]
    blob = data[bin_start:bin_start + bin_len]

    views = gltf["bufferViews"]
    image_views = {img["bufferView"]: img for img in gltf.get("images", []) if "bufferView" in img}
    chunks = []
    for i, view in enumerate(views):
        raw = blob[view.get("byteOffset", 0):view.get("byteOffset", 0) + view["byteLength"]]
        if i in image_views:
            im = Image.open(io.BytesIO(raw)).convert("RGB")
            im.thumbnail((max_size, max_size), Image.LANCZOS)
            out = io.BytesIO()
            im.save(out, "JPEG", quality=88)
            raw = out.getvalue()
            image_views[i]["mimeType"] = "image/jpeg"
        chunks.append(raw)
    new_blob = b""
    for view, raw in zip(views, chunks):
        new_blob += b"\0" * (-len(new_blob) % 4)
        view["byteOffset"] = len(new_blob)
        view["byteLength"] = len(raw)
        new_blob += raw
    new_blob += b"\0" * (-len(new_blob) % 4)
    gltf["buffers"][0]["byteLength"] = len(new_blob)
    js = json.dumps(gltf, separators=(",", ":")).encode()
    js += b" " * (-len(js) % 4)
    total = 12 + 8 + len(js) + 8 + len(new_blob)
    with open(path, "wb") as f:
        f.write(struct.pack("<III", 0x46546C67, 2, total))
        f.write(struct.pack("<I4s", len(js), b"JSON") + js)
        f.write(struct.pack("<I4s", len(new_blob), b"BIN\0") + new_blob)
    print(f"{path}: {len(data) // 1024} KB -> {total // 1024} KB")


if __name__ == "__main__":
    shrink(sys.argv[1], int(sys.argv[2]) if len(sys.argv) > 2 else 1024)
