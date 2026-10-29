# Moving Day Chaos — notes for Claude

- **v0.1.0 is playable and on itch.io; v0.2.0 (full visual redesign: environment, props, characters, movement) is in
  progress** — see `docs/RELEASE_0.2.0.md` and `docs/ROADMAP.md`. Online play works over LAN and the internet (noray);
  Steam lobbies are not done yet. Movers no longer wobble (removed 2026-10-14 at the user's request).
- Code map: `scripts/mover/` (Mover body + Hand physics + PlayerRig camera/input, MoverInput is plain data
  for future networking), `scripts/physics/grabbable.gd` (furniture + damage), `scripts/mission/`
  (LevelBuilder, TruckZone, Mission scoring), `scripts/ui/`. All tuning numbers live in `data/*.json`.
- Run `godot --headless --path . --import` after adding a new `class_name`, then the tests
  (`res://tests/test_runner.tscn`). Physics tests run in real time (~1.5 min).
- Design: `docs/GDD.md` (Arabic). Technical plan: `docs/TECH_DESIGN.md`. Art: `docs/ART_DIRECTION.md`.
- Planned stack: Godot 4.7, Jolt physics, GodotSteam (SteamMultiplayerPeer), host-authoritative physics.
- Carry over from the user's other Godot projects (Gumball Factory, Kitchen Survivors): data in `data/*.json`,
  EN/AR translations, static `default_bus_layout.tres`, headless tests + GitHub Actions, screenshot tool.
- Concept art comes from Higgsfield. For v0.1 art, `concept/01_key_art.png` is the scene/style reference and
  `concept/06_characters_revised.png` the character one. v0.2.0 replaces the style: once the user picks one from
  `concept/v0.2/styles/`, its image becomes the reference. Never use the first lineup (Mario-like) as a character reference.
- Street layout: the truck parks on a driveway and `Scenery.layout(truck)` puts the street past its nose
  (traffic never meets the truck; a test checks every mission). Environment textures come from
  `python3 tools/gen_textures.py` (near-white, tinted by `EnvMaterials`); fading walls need their own material.
