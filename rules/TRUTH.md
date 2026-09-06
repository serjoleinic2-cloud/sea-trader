# TRUTH

> Read this before any task. Short by design — keep it short.
> Last Updated: 2026-09-05 | Version: 0.2.0

---

## What This Is

**Sea Trader** — offline-first mobile game. Top-down 2D. Player manually controls a cargo ship on a procedurally generated sea, trades between ports, builds a company, expands a fleet.

**Core loop:** Explore — Discover — Trade — Expand. Manual voyage is primary. Known Routes enable automation and fleet.

---

## Non-Negotiable Principles

1. **Offline-first.** No internet required. No backend. Ever (unless explicitly decided by owner).
2. **Player manually controls their ship.** Core fantasy is hands-on navigation, not idle management.
3. **Tilt controls are the primary input.** Phone as physical controller.
4. **Deterministic world.** Same seed = same world, always. Never random at runtime.
5. **Data-driven.** Game balance lives in `data/*.json`. Not in code.
6. **Single source of truth.** All runtime state in `GameState`. One place, always.
7. **No punishment for closing the app.** Save preserves voyage state. Ship does not sink on exit.
8. **Known Routes only for automation.** First passage is always manual. Fleet operates on known routes only.
9. **World Seed is permanent.** A saved World Seed always produces the same world. A new seed is generated only on new game.
10. **World ≠ Player Knowledge.** The world exists independently of what the player has discovered. Discovery state is tracked separately from world generation.
11. **First manual passage creates a Known Route.** No route can be automated until the player has sailed it manually at least once.

---

## Technology

- Engine: **Godot 4.x**
- Language: **GDScript**
- Platform: **Android** (iOS secondary)
- Backend: **None**
- Save: **Local filesystem, versioned JSON**

---

## Architecture Constraints

- `SensorInput` is the only file that touches Android accelerometer API.
- `ShipPhysics` has no platform dependencies.
- UI contains no game logic.
- `SaveSystem` is the only entry point for file I/O.
- Static data (JSON) is read-only at runtime.
- `WorldGenerator` must never be called with a new random seed on load — only with the persisted seed from `WorldState`.
- Player discovery state (`discovered_port_ids`, `KnownRoutesState`) is saved separately from world generation data and must survive re-generation.

---

## AI Rule

Read `rules/AI_DEVELOPMENT_RULES.md` before writing code.
If a request conflicts with this file — surface the conflict, do not silently resolve it.

---

*Full design: `rules/GAME_BIBLE.md` — Architecture: `rules/ARCHITECTURE.md` — Rules: `rules/GAME_RULES.md`*
