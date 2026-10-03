# Moving Day Chaos — notes for Claude

- **Pre-production only.** Do not start implementing gameplay until the user asks.
- Design: `docs/GDD.md` (Arabic). Technical plan: `docs/TECH_DESIGN.md`. Art: `docs/ART_DIRECTION.md`.
- Planned stack: Godot 4.7, Jolt physics, GodotSteam (SteamMultiplayerPeer), host-authoritative physics.
- Carry over from the user's other Godot projects (Gumball Factory, Kitchen Survivors): data in `data/*.json`,
  EN/AR translations, static `default_bus_layout.tres`, headless tests + GitHub Actions, screenshot tool.
- Concept art comes from Higgsfield; reuse `concept/01_key_art.png` as the scene/style reference and
  `concept/06_characters_revised.png` for characters. Never use the first lineup (Mario-like) as a character reference.
