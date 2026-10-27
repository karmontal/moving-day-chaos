#!/usr/bin/env python3
"""Generate the v0.2 GLB models on Tripo from the concept image links.

Reads concept/v0.2/README.md, sends each image URL to Tripo (movers use multiview
front + side), polls the tasks and saves assets/models/v0.2/<id>.glb.
Needs TRIPO_API_KEY. Skips models that already exist, so it can be re-run.
Task ids are kept in assets/models/v0.2/tasks.json, so a re-run resumes them
instead of paying for a new generation (e.g. after a failed download).
Usage: python3 tools/tripo_gen.py [name ...]   (no names = everything)
"""
import json
import os
import re
import sys
import time
import urllib.request

API = "https://api.tripo3d.ai/v2/openapi"
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "models", "v0.2")
README = os.path.join(ROOT, "concept", "v0.2", "README.md")


def call(method, path, body=None):
    req = urllib.request.Request(API + path, method=method,
                                 data=json.dumps(body).encode() if body else None)
    req.add_header("Authorization", "Bearer " + os.environ["TRIPO_API_KEY"])
    req.add_header("Content-Type", "application/json")
    with urllib.request.urlopen(req, timeout=60) as r:
        res = json.load(r)
    if res.get("code") != 0:
        raise RuntimeError(res)
    return res["data"]


def slug(label):
    label = re.sub(r"\(.*?\)", "", label).replace("+", " ")
    return re.sub(r"[^a-z0-9]+", "_", label.lower()).strip("_")


def jobs():
    text = open(README, encoding="utf-8").read()
    chars, assets = text.split("## Assets")[0], text.split("## Assets")[1].split("## Scenes")[0]
    out = {}
    rows = [r for r in chars.splitlines() if "[front]" in r]
    for i, row in enumerate(rows):
        front, side = re.findall(r"\((https://[^)]+)\)", row)
        out["mover_%d" % i] = {"type": "multiview_to_model",
                               "files": [{"type": "png", "url": front}, {"type": "png", "url": side}, {}, {}]}
    for row in assets.splitlines():
        m = re.match(r"\|\s*([^|]+?)\s*\|\s*\[open\]\((https://[^)]+)\)", row)
        if m:
            out[slug(m.group(1))] = {"type": "image_to_model", "file": {"type": "png", "url": m.group(2)}}
    return out


def main():
    os.makedirs(OUT, exist_ok=True)
    todo = jobs()
    if sys.argv[1:]:
        todo = {k: v for k, v in todo.items() if k in sys.argv[1:]}
    todo = {k: v for k, v in todo.items() if not os.path.exists(os.path.join(OUT, k + ".glb"))}
    known_path = os.path.join(OUT, "tasks.json")
    known = json.load(open(known_path)) if os.path.exists(known_path) else {}
    tasks = {}
    for name, body in todo.items():
        if name in known:
            tasks[name] = known[name]
            print("resuming", name, tasks[name], flush=True)
            continue
        body = dict(body, texture=True, pbr=True)
        tasks[name] = known[name] = call("POST", "/task", body)["task_id"]
        json.dump(known, open(known_path, "w"), indent=1, sort_keys=True)
        print("submitted", name, tasks[name], flush=True)
    failed = []
    while tasks:
        time.sleep(10)
        for name, tid in list(tasks.items()):
            data = call("GET", "/task/" + tid)
            if data["status"] in ("queued", "running"):
                continue
            del tasks[name]
            out = data.get("output") or {}
            url = out.get("pbr_model") or out.get("model")
            if data["status"] != "success" or not url:
                failed.append(name)
                print("FAILED", name, data["status"], flush=True)
                continue
            urllib.request.urlretrieve(url, os.path.join(OUT, name + ".glb"))
            print("saved", name, flush=True)
    if failed:
        sys.exit("failed: " + " ".join(failed))


if __name__ == "__main__":
    main()
