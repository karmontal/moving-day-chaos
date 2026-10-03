# Technical Design

Pre-production plan for the implementation (no code yet).

## Stack
- **Engine:** Godot 4.7 (Forward+ for PC; Compatibility fallback for Steam Deck low-power mode), GDScript.
- **Physics:** Jolt (Godot's built-in Jolt integration) for stable stacking and joints.
- **Online:** Godot high-level multiplayer over **GodotSteam** `SteamMultiplayerPeer` (lobbies, invites, relay/NAT
  traversal through Steam Datagram Relay). ENet peer for LAN/dev testing.
- **Voice:** Steam Voice (proximity attenuation in-game); text pings as fallback.
- **Platform:** Steam (Windows first, Steam Deck verified target), Remote Play Together supported.

## Networking model
- **Host-authoritative physics.** The host simulates every `RigidBody3D` (furniture, debris). Clients send inputs and
  grab requests; the host broadcasts snapshots.
- **Furniture sync:** `MultiplayerSynchronizer` at 20–30 Hz with position/rotation/velocity; clients interpolate
  (100 ms buffer) and extrapolate briefly. Sleeping bodies stop sending.
- **Player characters:** client-predicted movement, host reconciles; hands (IK targets) synced at 30 Hz.
- **Grabs:** client sends `request_grab(body_id, local_point, hand)` RPC → host validates distance and creates a
  `Generic6DOFJoint3D`/pin joint between the hand body and the furniture → result replicated.
- **Bandwidth budget:** ≤ 64 kbps per client with 4 players and ~40 active bodies (quantized transforms, delta + sleep).
- **Late join / reconnect:** full snapshot on join; mission state (timer, items delivered, damage) replicated by the host.

## Core systems
| System | Responsibility |
|---|---|
| `Mover` (character) | Capsule body + physical hands (RigidBody3D) driven by spring forces toward IK targets ("active ragdoll lite"); stumble state on heavy hits |
| `Grabbable` | Component on furniture: mass, fragility, value, room tag, grab surfaces |
| `CarryCoordinator` | Sums lift force of attached hands vs. mass; applies balancing torque; drops on overload |
| `DamageModel` | Impact impulse → damage for fragile items; break into pre-fractured debris scene |
| `TruckBay` | Voxel occupancy grid of the cargo area, strap anchors, drive-shake simulation |
| `RoomZones` | Area3D per room in the destination house; validates placement |
| `MissionDirector` | Timer, checklist, random events, scoring (time, breakage, room accuracy) |
| `Economy` / `Save` | Money, unlocks, cosmetics; versioned JSON in `user://` + Steam Cloud |
| `PlatformServices` | Steam lobby/invite/achievements/voice abstraction, runs without Steam in dev |

## Data-driven content
All tunables in JSON (`data/`): furniture (mass, value, fragility, room), missions (layout scene, item list, time,
events), tools, economy. Furniture meshes are scenes under `furniture/` with a `Grabbable` node.

## Project layout (planned)
```
scenes/            main menu, lobby, mission, results
scripts/autoload/  Settings, Localization, AudioManager, PlatformServices, Net, Data, Save
scripts/mover/     character, hands, camera
scripts/physics/   grabbable, carry coordinator, damage, joints
scripts/mission/   director, truck bay, room zones, events
data/              furniture.json, missions.json, tools.json, economy.json, translations.json (EN/AR)
furniture/         one scene per item
tests/             headless tests
```

## Testing plan
- **Headless unit tests:** scoring, economy, damage thresholds, truck voxel packing, room validation, save migration.
- **Physics soak test:** 40 bodies stacked/carried for 5 minutes headless — no explosions, no NaN, no tunneling.
- **Network tests:** two headless Godot instances over ENet (host + client) in CI: grab → carry → deliver must replicate
  within tolerance; packet loss/latency simulation (100 ms, 5% loss).
- **Performance:** 4 movers + 40 active bodies ≥ 60 FPS on Steam Deck class hardware.
- **Lessons carried over from previous projects:** audio buses defined in `default_bus_layout.tres` (never created at
  runtime); data loaded in `_init`; textures used in `_draw` cached.


## Implementation status (Phase 2 start)

- `scripts/autoload/net.gd` (`Net`): ENet host/join on port 7777, LAN discovery by UDP broadcast on
  7778, player list `{peer_id: {name, character}}` with unique characters enforced by the host.
- `Mission` online mode: movers spawned per peer in `Net.peer_order()` (same order everywhere);
  clients make every mover/item a frozen puppet, send `MoverInput.to_dict()` each tick
  (`_send_input`, unreliable ordered) and smooth towards 30 Hz `PackedFloat32Array` snapshots
  (`_snapshot`: per mover 18 floats, per item 10). Breakage and deliveries ride in the snapshot;
  the result comes as a reliable `_net_finished`.
- Not yet: Steam transport (SteamMultiplayerPeer), joining mid-job, client-side prediction for the
  local mover (input delay = round trip; fine on LAN), host migration.
- Test: `tools/net_test.sh` runs a host and a client process over localhost (also in CI).
