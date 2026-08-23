# PROJECT STATE

> Update this file after every meaningful iteration.
> Last Updated: 2026-08-23

---

## Version
`0.1.0`

## Current Phase
`Architecture / Documentation`

No gameplay implemented yet. Foundation documents being established.

---

## Completed

- [x] Architecture analysis and design
- [x] Technology stack decision (Godot 4.x / GDScript)
- [x] `docs/GAME_BIBLE.md` — game concept document
- [x] `docs/GAME_RULES.md` — non-negotiable rules
- [x] `docs/ARCHITECTURE.md` — system architecture
- [x] `docs/SYSTEM_MAP.md` — system connection map
- [x] `docs/DATA_SCHEMA.md` — data models
- [x] `docs/DEVELOPMENT_PHASES.md` — build plan
- [x] `docs/AI_DEVELOPMENT_RULES.md` — AI development rules
- [x] `core/TRUTH.md` — source of truth
- [x] `core/PROJECT_STATE.md` — this file
- [x] `core/VERSION.json` — version tracking

---

## In Progress

- [ ] Phase 01: Project Foundation (Godot project, autoloads, folder structure)

---

## Next

1. Create Godot 4.x project
2. Implement `GameState` autoload with all state classes
3. Implement `EventBus` autoload with signal definitions
4. Implement `SaveSystem` autoload (skeleton)
5. Create `data/` folder structure with placeholder JSONs
6. Set up GUT test framework

---

## Known Issues

- None at architecture stage

---

## Architecture Decisions

| Decision | Rationale |
|----------|-----------|
| Godot 4.x over Unity | Lighter, free, native Android sensor API, better for 2D offline |
| GDScript primary | Simple syntax, good for AI-assisted development |
| GameState as autoload | Single source of truth, avoids scattered state |
| EventBus for decoupling | Prevents circular dependencies between systems |
| Direct calls allowed | EventBus not mandatory where coupling is obvious and local |
| JSON for game data | Designer-editable, no recompile needed, AI-readable |
| Versioned saves from v1 | Migration path available from day one |

---

## TBD (Pending Owner Decision)

- Fuel mechanic (exists as resource vs abstracted cost)
- Exact damage formulas
- Contract reward formula
- Maximum offline progress cap
- Port fee specifics
- Full resource/goods catalog
- Pirate encounter mechanics (combat? avoidance only?)
- Storm mechanics detail
- Employee bonus values
- Starter Pack contents
- Premium vs No Ads (same product or separate?)
- Custom company logo mechanic
- Maximum fleet size

---

## Last Updated
2026-08-23 — Initial documentation created. Gameplay: 0%. Architecture: complete.
