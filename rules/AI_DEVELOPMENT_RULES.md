# AI DEVELOPMENT RULES

> For: Claude · Kimi · OpenCode · any AI working on this project.
> Read this before touching any file. No exceptions.
> Last Updated: 2026-08-23 | Version: 0.1.0

---

## Before Making Any Change

**Required reading (in order):**

1. `core/TRUTH.md` — understand what this game is
2. `core/PROJECT_STATE.md` — understand current status and what's in progress
3. The relevant system documentation in `docs/` — understand the system you're touching
4. Existing code in the file you'll modify — understand what's already there

**Do not skip this.** Making changes without reading these files will cause conflicts with existing work.

---

## When Writing Code

### Architecture rules
- Do not create a second version of an existing system. If `PortSystem` exists, extend it — don't create `PortManager2`.
- Do not create an alternative architecture without explicit owner approval. The approved architecture is in `docs/ARCHITECTURE.md`.
- Do not move game logic into UI files. UI reads state and sends actions. It does not calculate prices, XP, or damage.
- Do not hardcode game data (prices, speeds, costs, names) in `.gd` files. Put it in `data/*.json`.
- Use existing `GameState` sub-states. Do not create parallel state objects.

### Offline-first rules
- Do not add any network calls, API calls, or server dependencies without explicit owner decision.
- Do not add Firebase, Supabase, PlayFab, or any backend SDK.
- All save/load must go through `SaveSystem`. Do not write directly to files elsewhere.

### Data rules
- Static game data (ship stats, resource prices, upgrade costs) lives in `data/` JSON files only.
- Runtime state lives in `GameState` only.
- Do not duplicate data between JSON and code.

### Sensor rules
- Android accelerometer access is only in `systems/input/sensor_input.gd`.
- `ShipPhysics` must not import or reference any platform-specific API.

### Communication rules
- Systems may read from `GameState` directly.
- Systems may call each other directly when the dependency is local and obvious (e.g. `ShipControl` → `ShipPhysics`).
- Use `EventBus` signals for cross-system notifications where direct coupling would create circular dependencies.
- Never call UI methods from game systems.

---

## When You Complete a Change

**Required steps after every meaningful change:**

1. Verify the project compiles without errors.
2. Check for obvious runtime errors on the changed code path.
3. Update `core/PROJECT_STATE.md`:
   - Move completed items to `Completed`
   - Note any new issues in `Known Issues`
   - Update `Last Updated` timestamp
4. If you changed a data schema, increment the version in that file's header and in `core/VERSION.json`.

---

## Conflict Resolution Rule

**If a user request conflicts with an existing rule in `core/TRUTH.md`, `docs/GAME_RULES.md`, or `docs/ARCHITECTURE.md`:**

Do not silently choose one or the other. Explicitly state the conflict:

```
CONFLICT DETECTED:
- User request: [what was asked]
- Existing rule: [which file, which rule]
- Options: [A] implement as requested (overrides rule), [B] implement within existing rule, [C] discuss
Please clarify before I proceed.
```

Never silently violate an established rule. Never silently ignore a user request. Surface the conflict.

---

## Scope Rules

Do not add features or systems that are not in the current phase (`core/PROJECT_STATE.md → Current Phase`).

If you see an opportunity to improve something outside your current task scope, note it in `Known Issues` or `TBD` — do not implement it unilaterally.

One system per PR / commit. Do not mix `PortSystem` changes with `EconomyEngine` changes in the same commit.

---

## What "Done" Means

A task is done when:
- [ ] Code compiles
- [ ] The feature works as described in `DEVELOPMENT_PHASES.md` for the current phase
- [ ] No existing tests are broken
- [ ] `PROJECT_STATE.md` is updated
- [ ] No hardcoded game data left in `.gd` files

---

## Things That Require Owner Decision Before Implementing

- Any new monetization mechanic
- Any backend/server integration
- Any change to `GAME_RULES.md → NON-NEGOTIABLE RULES`
- Any change to the core architecture pattern
- Any new TBD item being resolved with a specific value
- Adding multiplayer of any kind
