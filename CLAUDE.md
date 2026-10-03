# Moving Day Chaos — notes for Claude

- **Phase 1 (physics prototype) in progress** — see `docs/ROADMAP.md`. Online play (Phase 2) not started.
- Code map: `scripts/mover/` (Mover body + Hand physics + PlayerRig camera/input, MoverInput is plain data
  for future networking), `scripts/physics/grabbable.gd` (furniture + damage), `scripts/mission/`
  (LevelBuilder, TruckZone, Mission scoring), `scripts/ui/`. All tuning numbers live in `data/*.json`.
- Run `godot --headless --path . --import` after adding a new `class_name`, then the tests
  (`res://tests/test_runner.tscn`). Physics tests run in real time (~1.5 min).
- Design: `docs/GDD.md` (Arabic). Technical plan: `docs/TECH_DESIGN.md`. Art: `docs/ART_DIRECTION.md`.
- Planned stack: Godot 4.7, Jolt physics, GodotSteam (SteamMultiplayerPeer), host-authoritative physics.
- Carry over from the user's other Godot projects (Gumball Factory, Kitchen Survivors): data in `data/*.json`,
  EN/AR translations, static `default_bus_layout.tres`, headless tests + GitHub Actions, screenshot tool.
- Concept art comes from Higgsfield; reuse `concept/01_key_art.png` as the scene/style reference and
  `concept/06_characters_revised.png` for characters. Never use the first lineup (Mario-like) as a character reference.
